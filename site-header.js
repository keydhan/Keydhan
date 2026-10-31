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

  const path = window.location.pathname.replace(/\/+$/, "") || "/";
  const links = [
    { label: "Home", href: "/#home", match: path === "/" },
    { label: "Services", href: "/#services", match: false },
    { label: "Calculator", href: "/calculator.html", match: path === "/calculator.html" },
    { label: "Financial Tools", href: "/financial-tools.html", match: path === "/financial-tools.html" },
    { label: "Knowledge Centre", href: "/knowledge/", match: path === "/knowledge" || path.startsWith("/knowledge/") },
    { label: "Free Tools", href: "/tools/", match: path === "/tools" || path.startsWith("/tools/") },
    { label: "Properties", href: "/properties.html", match: path === "/properties.html" },
    { label: "Business Services", href: "/business-services.html", match: path === "/business-services.html" },
    { label: "About Us", href: "/about.html", match: path === "/about.html" },
    { label: "Contact", href: "/contact.html", match: path === "/contact.html" }
  ];

  nav.setAttribute("aria-label", "Main navigation");
  nav.innerHTML = links.map(item =>
    '<a href="' + item.href + '"' + (item.match ? ' aria-current="page"' : "") + '>' + item.label + '</a>'
  ).join("");

  const button = header.querySelector("#menuBtn");
  if (button) {
    button.type = "button";
    button.setAttribute("aria-label", "Open navigation menu");
    button.setAttribute("aria-controls", "menu");
    if (!button.hasAttribute("aria-expanded")) button.setAttribute("aria-expanded", "false");
  }
})();