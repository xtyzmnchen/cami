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
    var title = document.documentElement.getAttribute(
      lang === "en" ? "data-title-en" : "data-title-zh"
    );
    if (title) document.title = title;
    var imgs = document.querySelectorAll(".brand img[data-alt-zh]");
    imgs.forEach(function (img) {
      img.alt = lang === "en" ? (img.getAttribute("data-alt-en") || "Little Crown") : (img.getAttribute("data-alt-zh") || "小皇冠");
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
