// SPDX-License-Identifier: MIT
// IntelXeGL: what the zink-gl LaunchAgents run at login, so that macOS's "can run in the background" notice and the
// Login Items list name IntelXe's OpenGL component instead of "sh" or "launchctl" (macOS shows the executable's name).
//
//   IntelXeGL setenv NAME VALUE [FILE...]   launchctl setenv NAME VALUE, only when every FILE exists
//
// install.sh --global (JAVA_TOOL_OPTIONS) and --global-gl (DYLD_INSERT_LIBRARIES, only while libcglzink-boot and
// libcglzink are both there: an inserted library that is missing stops every application from starting) use it.
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>

extern char **environ;

int main(int argc, char **argv)
{
    if (argc < 4 || strcmp(argv[1], "setenv") != 0) {
        fprintf(stderr, "usage: IntelXeGL setenv NAME VALUE [FILE...]\n");
        return 2;
    }
    for (int i = 4; i < argc; i++) {
        struct stat st;
        if (stat(argv[i], &st) != 0 || !S_ISREG(st.st_mode)) {
            fprintf(stderr, "IntelXeGL: %s is missing; %s not set\n", argv[i], argv[2]);
            return 0;
        }
    }
    char *args[] = { "launchctl", "setenv", argv[2], argv[3], NULL };
    pid_t pid;
    int rc = posix_spawn(&pid, "/bin/launchctl", NULL, NULL, args, environ);
    if (rc != 0) {
        fprintf(stderr, "IntelXeGL: cannot run launchctl: %s\n", strerror(rc));
        return 1;
    }
    int status = 0;
    if (waitpid(pid, &status, 0) < 0) return 1;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
