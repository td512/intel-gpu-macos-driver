// intel-gpu-macos-driver site: language, the nav's background, scroll-in, and the latest release's files. MIT.
(function () {
  "use strict";
  var root = document.documentElement;
  root.classList.add("js");   // the scroll-in hides sections only when this script runs

  // ---- language: ?lang=, then the visitor's choice, then the browser's language ----
  function setLang(lang, remember) {
    root.setAttribute("data-lang", lang);
    root.setAttribute("lang", lang);
    document.querySelectorAll(".lang button").forEach(function (b) {
      b.setAttribute("aria-pressed", String(b.dataset.lang === lang));
    });
    if (remember) { try { localStorage.setItem("lang", lang); } catch (e) { /* private mode */ } }
  }
  var asked = new URLSearchParams(location.search).get("lang");
  var saved = null;
  try { saved = localStorage.getItem("lang"); } catch (e) { /* private mode */ }
  var browser = (navigator.language || "en").toLowerCase().indexOf("tr") === 0 ? "tr" : "en";
  setLang(asked === "tr" || asked === "en" ? asked : saved || browser, false);
  document.querySelectorAll(".lang button").forEach(function (b) {
    b.addEventListener("click", function () { setLang(b.dataset.lang, true); });
  });

  // ---- the small-screen menu closes after a choice ----
  document.querySelectorAll(".menu nav a").forEach(function (a) {
    a.addEventListener("click", function () { var d = a.closest("details"); if (d) d.open = false; });
  });

  // ---- the nav gets its background once the page scrolls ----
  var nav = document.querySelector(".nav");
  function onScroll() { nav.style.setProperty("--nav-fill", Math.min(1, window.scrollY / 120)); }
  window.addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // ---- scroll-in ----
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } });
    }, { rootMargin: "0px 0px -8% 0px" });
    document.querySelectorAll(".reveal").forEach(function (el) { io.observe(el); });
  } else {
    document.querySelectorAll(".reveal").forEach(function (el) { el.classList.add("in"); });
  }

  // ---- the latest release: version, file links and sizes (the page keeps its built-in ones if GitHub does not answer) ----
  function mb(bytes) { return bytes >= 1e6 ? (bytes / 1e6).toFixed(bytes >= 1e8 ? 0 : 1) + " MB" : Math.max(1, Math.round(bytes / 1e3)) + " KB"; }
  fetch("https://api.github.com/repos/yusufklncc/intel-gpu-macos-driver/releases/latest", { headers: { Accept: "application/vnd.github+json" } })
    .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
    .then(function (rel) {
      var version = String(rel.tag_name || "").replace(/^v/, "");
      if (!version) return;
      document.querySelectorAll("[data-version]").forEach(function (el) { el.textContent = version; });
      document.querySelectorAll("[data-asset]").forEach(function (el) {
        var suffix = el.getAttribute("data-asset");   // a part of the file name
        var asset = (rel.assets || []).filter(function (a) { return a.name.indexOf(suffix) !== -1; })[0];
        if (!asset) return;
        el.setAttribute("href", asset.browser_download_url);
        var name = el.querySelector(".name"); if (name) name.textContent = asset.name;
        var size = el.querySelector(".size"); if (size) size.textContent = mb(asset.size);
      });
    })
    .catch(function () { /* offline or rate-limited: the links to the release page stay */ });
})();
