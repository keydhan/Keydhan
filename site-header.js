/* KeyDhan™ — single source of truth for every public-page header and navigation. */
(function () {
  "use strict";
  function installCompactMobileMenuStyles() {
    if (document.getElementById("kd-compact-menu-styles")) return;
    const style = document.createElement("style");
    style.id = "kd-compact-menu-styles";
    style.textContent = `
      @media (max-width: 768px) {
        header #menu {
          width: min(280px, calc(100vw - 32px)) !important;
          max-height: min(62dvh, 520px) !important;
          padding: 9px !important;
          gap: 2px !important;
          border-radius: 20px !important;
        }
        header #menu a {
          min-height: 42px !important;
          padding: 10px 12px !important;
          border-radius: 11px !important;
          font-size: 14px !important;
          line-height: 1.25 !important;
        }
        header #menu a:before {
          width: 5px !important;
          height: 5px !important;
          flex-basis: 5px !important;
          margin-right: 10px !important;
        }
      }
    `;
    (document.head || document.documentElement).appendChild(style);
  }

  function initKeyDhanHeader() {
    installCompactMobileMenuStyles();
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
      '<a class="logo" id="adminLogo" href="/" aria-label="KeyDhan home" style="color:#fff!important;text-decoration:none!important;border:0!important;background:none!important"><span class="logo-key" style="color:#fff!important;text-decoration:none!important">Key</span><span style="color:var(--gold)!important;text-decoration:none!important">Dhan</span><sup style="color:var(--gold)!important;text-decoration:none!important">™</sup></a>' +
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