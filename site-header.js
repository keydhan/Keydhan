/* KeyDhan™ — single source of truth for every public-page header and navigation. */
(function () {
  "use strict";
  function initKeyDhanHeader() {
    let header = document.querySelector("body > header") || document.querySelector("header");
    if (!header) {
      header = document.createElement("header");
      document.body.insertBefore(header, document.body.firstChild);
    }

    const path = window.location.pathname.replace(/\/+$/, "") || "/";
    const links = [
      { label: "Home", href: "/", match: path === "/" },
      { label: "Services", href: "/#services", match: false },
      { label: "Calculator", href: "/calculator.html", match: path === "/calculator.html" },
      { label: "Financial Tools", href: "/financial-tools.html", match: path === "/financial-tools.html" },
      { label: "Loan Planning", href: "/loan-comparison.html", match: path === "/loan-comparison.html" },
      { label: "Free Tools", href: "/tools/", match: path === "/tools" || path.startsWith("/tools/") },
      { label: "Knowledge Centre", href: "/knowledge/", match: path === "/knowledge" || path.startsWith("/knowledge/") },
      { label: "Properties", href: "/properties.html", match: path === "/properties.html" },
      { label: "Delhi NCR", href: "/delhi-ncr/", match: path === "/delhi-ncr" || path.startsWith("/delhi-ncr/") },
      { label: "Business Services", href: "/business-services.html", match: path === "/business-services.html" },
      { label: "About Us", href: "/about.html", match: path === "/about.html" },
      { label: "Contact", href: "/contact.html", match: path === "/contact.html" }
    ];

    header.innerHTML =
      '<a class="logo" id="adminLogo" href="/" aria-label="KeyDhan home"><span class="logo-key">Key</span><span>Dhan</span><sup>™</sup></a>' +
      '<button class="menu-btn" id="menuBtn" type="button" aria-label="Open navigation menu" aria-controls="menu" aria-expanded="false">☰</button>' +
      '<nav id="menu" aria-label="Main navigation">' +
      links.map(item => '<a href="' + item.href + '"' + (item.match ? ' aria-current="page"' : "") + '>' + item.label + '</a>').join("") +
      '</nav>';

    const nav = header.querySelector("#menu");
    const button = header.querySelector("#menuBtn");
    if (button.dataset.kdMenuBound === "true") return;
    button.dataset.kdMenuBound = "true";
    const isMobile = () => window.matchMedia("(max-width: 768px)").matches;
    const closeMenu = () => {
      nav.classList.remove("show");
      button.setAttribute("aria-expanded", "false");
      button.setAttribute("aria-label", "Open navigation menu");
      document.body.classList.remove("menu-open");
    };
    const openMenu = () => {
      nav.classList.add("show");
      button.setAttribute("aria-expanded", "true");
      button.setAttribute("aria-label", "Close navigation menu");
      document.body.classList.add("menu-open");
    };
    button.addEventListener("click", event => {
      event.preventDefault();
      event.stopPropagation();
      if (!isMobile()) return;
      nav.classList.contains("show") ? closeMenu() : openMenu();
    });
    nav.addEventListener("click", event => {
      if (event.target.closest("a")) closeMenu();
    });
    document.addEventListener("click", event => {
      if (nav.classList.contains("show") && !nav.contains(event.target) && !button.contains(event.target)) closeMenu();
    });
    document.addEventListener("keydown", event => {
      if (event.key === "Escape") closeMenu();
    });
    window.addEventListener("resize", () => {
      if (!isMobile()) closeMenu();
    });
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initKeyDhanHeader, { once: true });
  } else {
    initKeyDhanHeader();
  }
})();