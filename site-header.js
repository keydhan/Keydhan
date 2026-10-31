/* KeyDhan™ — single source of truth for public-site navigation. */
(function () {
  "use strict";
  const header = document.querySelector("body > header");
  if (!header) return;

  let nav = header.querySelector("#menu");
  if (!nav) {
    nav = document.createElement("nav");
    nav.id = "menu";
    header.appendChild(nav);
  }

  const path = window.location.pathname.replace(/\\/+$/, "") || "/";
  const links = [
    { label: "Home", href: "/#home", match: path === "/" },
    { label: "Services", href: "/#services", match: false },
    { label: "Calculator", href: "/calculator.html", match: path === "/calculator.html" },
    { label: "Financial Tools", href: "/financial-tools.html", match: path === "/financial-tools.html" },
    { label: "Loan Planning", href: "/loan-comparison.html", match: path === "/loan-comparison.html" },
    { label: "Free Tools", href: "/tools/", match: path === "/tools" || path.startsWith("/tools/") },
    { label: "Knowledge Centre", href: "/knowledge/", match: path === "/knowledge" || path.startsWith("/knowledge/") },
    { label: "Properties", href: "/properties.html", match: path === "/properties.html" },
    { label: "Delhi NCR", href: "/delhi-ncr/", match: path === "/delhi-ncr" || path === "/delhi-ncr/" },
    { label: "Business Services", href: "/business-services.html", match: path === "/business-services.html" },
    { label: "About Us", href: "/about.html", match: path === "/about.html" },
    { label: "Contact", href: "/contact.html", match: path === "/contact.html" }
  ];

  nav.setAttribute("aria-label", "Main navigation");
  nav.innerHTML = links.map(item =>
    '<a href="' + item.href + '"' + (item.match ? ' aria-current="page"' : "") + '>' + item.label + '</a>'
  ).join("");

  const button = header.querySelector("#menuBtn");
  if (button && !header.dataset.kdMenuReady) {
    header.dataset.kdMenuReady = "true";
    button.type = "button";
    button.setAttribute("aria-controls", "menu");
    button.setAttribute("aria-expanded", "false");
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
})();