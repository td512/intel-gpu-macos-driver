// SPDX-License-Identifier: MIT
// srv: a minimal static file server for one folder on 127.0.0.1:PORT, for the WebGPU pages of regress.sh (WebGPU needs a
// secure context; http://127.0.0.1 is one). GET serves files under DIR (HTML, JS, JSON content types, no "..");
// POST /log appends the request body and a newline to DIR/log.txt, which is how the pages report their results.
//
//   srv DIR PORT
//
// The test machine has no compiler: build it on the build Mac and copy the binary into the regress bin folder:
//   clang -arch x86_64 -mmacosx-version-min=15.0 -O2 -Wall -o srv tools/regress/srv.c
//   scp srv <test machine>:b580/regress/bin/
#include <arpa/inet.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static void put(int c, const char *s) { (void)!write(c, s, strlen(s)); }

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: srv DIR PORT\n"); return 2; }
    signal(SIGPIPE, SIG_IGN);   // a page closed mid-transfer must not end the server
    const char *dir = argv[1];
    const int port = atoi(argv[2]);
    int s = socket(AF_INET, SOCK_STREAM, 0), one = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET;
    a.sin_port = htons(port);
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);   // loopback only: nothing outside the machine reaches it
    if (bind(s, (struct sockaddr *)&a, sizeof a) || listen(s, 16)) { perror("bind"); return 1; }
    for (;;) {
        int c = accept(s, NULL, NULL);
        if (c < 0) continue;
        // read the request: headers, then Content-Length bytes of body (POST /log)
        static char req[1 << 20];
        ssize_t n = 0, r;
        req[0] = 0;
        while ((r = read(c, req + n, sizeof req - 1 - n)) > 0) {
            n += r;
            req[n] = 0;
            char *h = strstr(req, "\r\n\r\n");
            if (h) {
                char *cl = strcasestr(req, "Content-Length:");
                size_t want = cl ? (size_t)atol(cl + 15) : 0;
                if ((size_t)(n - (h + 4 - req)) >= want) break;
            }
        }
        char m[8] = "", p[512] = "";
        sscanf(req, "%7s %511s", m, p);
        if (!strcmp(m, "POST") && !strncmp(p, "/log", 4)) {
            char *b = strstr(req, "\r\n\r\n"), f[1024];
            snprintf(f, sizeof f, "%s/log.txt", dir);
            FILE *o = fopen(f, "a");
            if (o && b) { fputs(b + 4, o); fputc('\n', o); }
            if (o) fclose(o);
            put(c, "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n");
            close(c);
            continue;
        }
        if (strstr(p, "..")) { close(c); continue; }
        char f[1024];
        snprintf(f, sizeof f, "%s%s", dir, strcmp(p, "/") ? p : "/index.html");
        char *q = strchr(f + strlen(dir), '?');
        if (q) *q = 0;
        FILE *in = fopen(f, "rb");
        if (!in) {
            put(c, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
            close(c);
            continue;
        }
        fseek(in, 0, SEEK_END);
        long len = ftell(in);
        fseek(in, 0, SEEK_SET);
        const char *dot = strrchr(f, '.');
        const char *ct = dot && !strcmp(dot, ".js")     ? "text/javascript"
                         : dot && !strcmp(dot, ".json") ? "application/json"
                                                        : "text/html; charset=utf-8";
        char hd[256];
        int hn = snprintf(hd, sizeof hd,
                          "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Length: %ld\r\nCache-Control: no-store\r\n"
                          "Connection: close\r\n\r\n", ct, len);
        (void)!write(c, hd, hn);
        char buf[65536];
        size_t k;
        while ((k = fread(buf, 1, sizeof buf, in)) > 0) (void)!write(c, buf, k);
        fclose(in);
        close(c);
    }
}
