(function () {
  var KEY = "cami_legal_lang";

  function pickLang() {
    var q = new URLSearchParams(location.search).get("lang");
    if (q === "zh" || q === "en") return q;
    try {
      var saved = localStorage.getItem(KEY);
      if (saved === "zh" || saved === "en") return saved;
    } catch (_) {}
    var nav = (navigator.language || "zh").toLowerCase();
    return nav.startsWith("zh") ? "zh" : "en";
  }

  function apply(lang) {
    document.documentElement.lang = lang;
    document.querySelectorAll("[data-lang-btn]").forEach(function (btn) {
      btn.classList.toggle("active", btn.getAttribute("data-lang-btn") === lang);
    });
    try {
      localStorage.setItem(KEY, lang);
    } catch (_) {}
    var url = new URL(location.href);
    url.searchParams.set("lang", lang);
    history.replaceState(null, "", url);
  }

  document.addEventListener("DOMContentLoaded", function () {
    apply(pickLang());
    document.querySelectorAll("[data-lang-btn]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        apply(btn.getAttribute("data-lang-btn"));
      });
    });
  });
})();
