/* KeyDhan™ — central public header and premium mobile navigation. */
(function () {
  "use strict";
  function initKeyDhanHeader() {
    let header = document.querySelector("body > header") || document.querySelector("header");
    if (!header) {
      header = document.createElement("header");
      document.body.insertBefore(header, document.body.firstChild);
    }

    const path = window.location.pathname.replace(/\/+$/, "") || "/";
    // Add a reliable return link to every individual Free Tool page (including future tools using the shared header).
    if (path.startsWith("/tools/") && path !== "/tools") {
      const toolsWrap = document.querySelector(".tools-wrap");
      if (toolsWrap && !document.querySelector(".kd-tools-back")) {
        const back = document.createElement("a");
        back.className = "kd-tools-back";
        back.href = "/tools/";
        back.setAttribute("aria-label", "Back to Free Tools");
        back.innerHTML = '<span aria-hidden="true">←</span><span>Back to Free Tools</span>';
        toolsWrap.insertBefore(back, toolsWrap.firstChild);
        if (!document.getElementById("kd-tools-back-style")) {
          const backStyle = document.createElement("style");
          backStyle.id = "kd-tools-back-style";
          backStyle.textContent = '.kd-tools-back{display:inline-flex;align-items:center;gap:9px;min-height:42px;margin:0 0 18px;padding:10px 16px;border:1px solid rgba(212,175,55,.38);border-radius:999px;background:linear-gradient(135deg,rgba(16,34,56,.96),rgba(6,15,28,.98));color:#f0d36b;text-decoration:none;font-size:13px;font-weight:750;box-shadow:0 8px 22px rgba(0,0,0,.18);transition:transform .18s,border-color .18s,background .18s}.kd-tools-back span:first-child{font-size:19px;line-height:1}.kd-tools-back:hover,.kd-tools-back:focus-visible{transform:translateX(-2px);border-color:#e5c75a;background:linear-gradient(135deg,#142943,#0a1729);outline:none}.kd-tools-back:focus-visible{box-shadow:0 0 0 3px rgba(212,175,55,.2)}';
          document.head.appendChild(backStyle);
        }
      }
    }

    const groups = [
      { title: "Explore", links: [
        { label: "Home", href: "/", icon: "⌂", match: path === "/" },
        { label: "Properties", href: "/properties.html", icon: "⌂", match: path === "/properties.html" },
        { label: "Loan Services", href: "/loan-services/", icon: "₹", match: path.startsWith("/loan-services") },
        { label: "Delhi NCR", href: "/delhi-ncr/", icon: "⌖", match: path === "/delhi-ncr" || path.startsWith("/delhi-ncr/") }
      ]},
      { title: "Financial Solutions", links: [
        { label: "Calculator", href: "/calculator.html", icon: "▦", match: path === "/calculator.html" },
        { label: "Financial Tools", href: "/financial-tools.html", icon: "◇", match: path === "/financial-tools.html" },
        { label: "Loan Planning", href: "/loan-comparison.html", icon: "↗", match: path === "/loan-comparison.html" }
      ]},
      { title: "Resources", links: [
        { label: "Free Tools", href: "/tools/", icon: "⚒", match: path === "/tools" || path.startsWith("/tools/") },
        { label: "Knowledge Centre", href: "/knowledge/", icon: "▤", match: path === "/knowledge" || path.startsWith("/knowledge/") },
        { label: "Business Services", href: "/business-services.html", icon: "▣", match: path === "/business-services.html" },
        { label: "About Us", href: "/about.html", icon: "ⓘ", match: path === "/about.html" },
        { label: "Contact", href: "/contact.html", icon: "✆", match: path === "/contact.html" }
      ]}
    ];

    const menuMarkup = groups.map(group =>
      '<section class="kd-nav-group"><h2>' + group.title + '</h2>' +
      group.links.map(item => '<a href="' + item.href + '"' + (item.match ? ' aria-current="page"' : "") + '><span class="kd-nav-icon" aria-hidden="true">' + item.icon + '</span><span>' + item.label + '</span><span class="kd-nav-arrow" aria-hidden="true">›</span></a>').join("") +
      '</section>'
    ).join("");


    const desktopMarkup =
      '<nav class="kd-desktop-nav" aria-label="Desktop navigation">' +
      '<a href="/" class="kd-desktop-link' + (path === "/" ? " is-active" : "") + '">Home</a>' +
      '<a href="/properties.html" class="kd-desktop-link' + (path === "/properties.html" ? " is-active" : "") + '">Properties</a>' +
      '<a href="/loan-services/" class="kd-desktop-link' + (path.startsWith("/loan-services") ? " is-active" : "") + '">Loan Services</a>' +
      '<a href="/delhi-ncr/" class="kd-desktop-link' + (path.startsWith("/delhi-ncr") ? " is-active" : "") + '">Delhi NCR</a>' +
      '<div class="kd-desktop-dropdown"><button type="button" class="kd-desktop-trigger' + (["/calculator.html","/financial-tools.html","/loan-comparison.html"].includes(path) ? " is-active" : "") + '" aria-haspopup="true" aria-expanded="false">Financial Solutions <span class="kd-chevron" aria-hidden="true"></span></button><div class="kd-desktop-panel">' +
      '<a href="/calculator.html">EMI Calculator</a><a href="/financial-tools.html">Financial Tools</a><a href="/loan-comparison.html">Loan Planning</a></div></div>' +
      '<a href="/tools/" class="kd-desktop-link' + (path.startsWith("/tools") ? " is-active" : "") + '">Free Tools</a>' +
      '<div class="kd-desktop-dropdown"><button type="button" class="kd-desktop-trigger' + (path.startsWith("/knowledge") || path === "/business-services.html" || path === "/about.html" ? " is-active" : "") + '" aria-haspopup="true" aria-expanded="false">More <span class="kd-chevron" aria-hidden="true"></span></button><div class="kd-desktop-panel">' +
      '<a href="/knowledge/">Knowledge Centre</a><a href="/business-services.html">Business Services</a><a href="/about.html">About Us</a></div></div>' +
      '<a href="/contact.html" class="kd-desktop-contact">Contact Us</a>' +
      '</nav>';

    header.innerHTML =
      '<a class="logo" id="adminLogo" href="/" aria-label="KeyDhan home" style="color:#fff!important;text-decoration:none!important;border:0!important;background:none!important"><span class="logo-key" style="color:#fff!important;text-decoration:none!important">Key</span><span style="color:var(--gold)!important;text-decoration:none!important">Dhan</span><sup style="color:var(--gold)!important;text-decoration:none!important">™</sup></a>' +
      desktopMarkup +
      '<button class="menu-btn" id="menuBtn" type="button" aria-label="Open navigation menu" aria-controls="menu" aria-expanded="false">☰</button>' +
      '<nav id="menu" aria-label="Main navigation"><div class="kd-menu-heading"><span>KEYDHAN NAVIGATION</span><small>Explore your next move</small></div>' + menuMarkup +
      '<div class="kd-menu-footer">The Key to Your Home. The Power of Finance.</div></nav>';

    let backdrop = document.querySelector(".kd-menu-backdrop");
    if (!backdrop) {
      backdrop = document.createElement("div");
      backdrop.className = "kd-menu-backdrop";
      backdrop.setAttribute("aria-hidden", "true");
      header.insertAdjacentElement("afterend", backdrop);
    }

    if (!document.getElementById("kd-premium-menu-style")) {
      const style = document.createElement("style");
      style.id = "kd-premium-menu-style";
      style.textContent = `

        @media (min-width:769px) {
          header {
            display:flex !important; flex-wrap:nowrap !important; align-items:center !important;
            justify-content:space-between !important; gap:clamp(18px,2.4vw,38px) !important;
            padding:15px clamp(24px,4.2vw,68px) !important; min-height:86px !important;
            box-sizing:border-box !important; width:100%;
          }
          header > .logo {
            display:inline-flex !important; align-items:baseline; flex:0 0 auto !important;
            visibility:visible !important; white-space:nowrap !important;
            font-size:clamp(27px,2.25vw,34px) !important; line-height:1 !important;
          }
          header .kd-desktop-nav {
            display:flex !important; flex:1 1 auto !important; min-width:0 !important;
            align-items:center !important; justify-content:flex-end !important;
            gap:clamp(10px,1.35vw,21px) !important; white-space:nowrap !important;
          }
          header .kd-desktop-nav .kd-desktop-link,
          header .kd-desktop-nav .kd-desktop-trigger {
            display:inline-flex !important; align-items:center !important; gap:7px !important;
            padding:13px 0 !important; border:0 !important; background:transparent !important;
            color:#e8edf5 !important; font-family:inherit !important;
            font-size:clamp(12px,.96vw,14px) !important; font-weight:650 !important;
            line-height:1.25 !important; text-decoration:none !important; cursor:pointer !important;
            transition:color .2s ease !important;
          }
          header .kd-desktop-nav .kd-desktop-link:hover,
          header .kd-desktop-nav .kd-desktop-link:focus-visible,
          header .kd-desktop-nav .kd-desktop-trigger:hover,
          header .kd-desktop-nav .kd-desktop-trigger:focus-visible,
          header .kd-desktop-nav .is-active { color:#e4c65b !important; outline:none !important; }
          header .kd-desktop-nav .is-active { position:relative; }
          header .kd-desktop-nav .is-active:after {
            content:""; position:absolute; left:0; right:0; bottom:5px; height:2px;
            border-radius:2px; background:#d8b94e;
          }
          header .kd-desktop-nav .kd-chevron {
            display:inline-block; width:7px; height:7px; margin-top:-4px;
            border-right:1.5px solid #d8b94e; border-bottom:1.5px solid #d8b94e;
            transform:rotate(45deg); transition:transform .2s ease;
          }
          header .kd-desktop-dropdown { position:relative; display:flex; align-items:center; }
          header .kd-desktop-panel {
            position:absolute; top:calc(100% + 8px); left:-18px; min-width:220px;
            padding:8px; border:1px solid rgba(218,184,67,.28); border-radius:15px;
            background:linear-gradient(155deg,#102039,#050d1b);
            box-shadow:0 20px 48px rgba(0,0,0,.48),inset 0 1px rgba(255,255,255,.04);
            opacity:0; visibility:hidden; pointer-events:none; transform:translateY(7px);
            transition:opacity .18s,transform .18s,visibility .18s; z-index:1010;
          }
          header .kd-desktop-dropdown:hover .kd-desktop-panel,
          header .kd-desktop-dropdown:focus-within .kd-desktop-panel,
          header .kd-desktop-dropdown.is-open .kd-desktop-panel {
            opacity:1; visibility:visible; pointer-events:auto; transform:translateY(0);
          }
          header .kd-desktop-dropdown:hover .kd-chevron,
          header .kd-desktop-dropdown:focus-within .kd-chevron,
          header .kd-desktop-dropdown.is-open .kd-chevron { transform:rotate(225deg); }
          header .kd-desktop-panel a {
            display:flex !important; align-items:center; padding:11px 13px !important;
            border-radius:9px; color:#edf2f8 !important; font-size:13px !important;
            font-weight:600 !important; line-height:1.3 !important; text-decoration:none !important;
            transition:background .18s,color .18s;
          }
          header .kd-desktop-panel a:hover,
          header .kd-desktop-panel a:focus-visible {
            color:#f1d46b !important; background:rgba(218,184,67,.10); outline:none;
          }
          header .kd-desktop-contact {
            display:inline-flex !important; align-items:center; justify-content:center;
            flex:0 0 auto; padding:11px 17px !important; border:1px solid rgba(218,184,67,.55) !important;
            border-radius:999px !important; color:#081321 !important;
            background:linear-gradient(135deg,#f2d978,#c9a83e) !important;
            font-size:13px !important; font-weight:750 !important; text-decoration:none !important;
            box-shadow:0 5px 16px rgba(218,184,67,.16); transition:transform .2s,box-shadow .2s;
          }
          header .kd-desktop-contact:hover { transform:translateY(-1px); box-shadow:0 8px 22px rgba(218,184,67,.24); }
          header .menu-btn, header #menu { display:none !important; }
        }
        @media (min-width:769px) and (max-width:1120px) {
          header { gap:14px !important; padding-inline:20px !important; }
          header > .logo { font-size:26px !important; }
          header .kd-desktop-nav { gap:10px !important; }
          header .kd-desktop-nav .kd-desktop-link,
          header .kd-desktop-nav .kd-desktop-trigger { font-size:11.5px !important; }
          header .kd-desktop-contact { padding:10px 12px !important; font-size:11.5px !important; }
        }
        @media (max-width:768px) { header .kd-desktop-nav { display:none !important; } }
        header #menu .kd-menu-heading, header #menu .kd-nav-group h2, header #menu .kd-menu-footer { display:none; }
        @media (max-width:768px) {
          header #menu {
            position:fixed !important; top:calc(env(safe-area-inset-top,0px) + 88px) !important;
            right:16px !important; left:auto !important; width:min(86vw,340px) !important;
            max-height:74dvh !important; overflow-y:auto !important; overscroll-behavior:contain !important;
            display:block !important; padding:17px 14px 13px !important; gap:0 !important;
            border:1px solid rgba(218,184,67,.34) !important; border-radius:23px !important;
            background:linear-gradient(155deg,rgba(12,27,47,.97),rgba(4,11,23,.985)) !important;
            box-shadow:0 24px 70px rgba(0,0,0,.62),inset 0 1px rgba(255,255,255,.045) !important;
            backdrop-filter:blur(22px); -webkit-backdrop-filter:blur(22px);
            opacity:0 !important; visibility:hidden !important; pointer-events:none !important;
            transform:translateX(18px) scale(.985) !important; transform-origin:top right;
            transition:opacity .22s,transform .22s,visibility .22s !important; z-index:1002 !important;
          }
          header #menu.show { opacity:1 !important; visibility:visible !important; pointer-events:auto !important; transform:translateX(0) scale(1) !important; }
          header #menu .kd-menu-heading { display:flex; flex-direction:column; gap:4px; padding:2px 10px 14px; border-bottom:1px solid rgba(255,255,255,.08); margin-bottom:8px; }
          header #menu .kd-menu-heading span { color:#e4c65b; font-size:10px; font-weight:850; letter-spacing:.17em; }
          header #menu .kd-menu-heading small { color:#98a8bd; font-size:12px; }
          header #menu .kd-nav-group { padding:5px 0 7px; border-bottom:1px solid rgba(255,255,255,.065); }
          header #menu .kd-nav-group:last-of-type { border-bottom:0; }
          header #menu .kd-nav-group h2 { display:block; margin:4px 10px 5px; color:#d8b94e; font-size:9px; line-height:1.4; font-weight:850; letter-spacing:.15em; text-transform:uppercase; }
          header #menu a { display:flex !important; align-items:center; gap:11px; min-height:40px !important; padding:8px 10px !important; margin:2px 0; border-radius:12px !important; color:#f5f7fb !important; font-size:14px !important; font-weight:650 !important; line-height:1.25 !important; text-decoration:none !important; }
          header #menu a:before { display:none !important; content:none !important; }
          header #menu .kd-nav-icon { display:inline-flex; align-items:center; justify-content:center; flex:0 0 25px; width:25px; height:25px; border:1px solid rgba(218,184,67,.2); border-radius:8px; background:rgba(218,184,67,.07); color:#e4c65b; font-size:15px; }
          header #menu .kd-nav-arrow { margin-left:auto; color:#71829a; font-size:22px; line-height:1; }
          header #menu a[aria-current="page"] { color:#f3d56a !important; background:linear-gradient(90deg,rgba(218,184,67,.16),rgba(218,184,67,.045)) !important; }
          header #menu a[aria-current="page"] .kd-nav-icon { background:rgba(218,184,67,.16); border-color:rgba(218,184,67,.42); }
          header #menu .kd-menu-footer { display:block; padding:12px 8px 2px; color:#8291a7; font-size:10px; line-height:1.5; text-align:center; }
          .kd-menu-backdrop { position:fixed; inset:0; z-index:998; background:rgba(0,5,14,.66); backdrop-filter:blur(4px); -webkit-backdrop-filter:blur(4px); opacity:0; visibility:hidden; pointer-events:none; transition:opacity .22s,visibility .22s; }
          .kd-menu-backdrop.show { opacity:1; visibility:visible; pointer-events:auto; }
          header .menu-btn { position:relative; z-index:1003; }
          body.menu-open { overflow:hidden; }
        }
        @media (min-width:769px) { .kd-menu-backdrop { display:none !important; } }
      `;
      (document.head || document.documentElement).appendChild(style);
    }

    // Desktop dropdowns (Financial Solutions and More): click to toggle, outside click/Escape to close.
    const desktopDropdowns = Array.from(header.querySelectorAll(".kd-desktop-dropdown"));
    desktopDropdowns.forEach(dropdown => {
      const trigger = dropdown.querySelector(".kd-desktop-trigger");
      if (!trigger || trigger.dataset.kdDropdownBound === "true") return;
      trigger.dataset.kdDropdownBound = "true";
      trigger.setAttribute("aria-expanded", "false");
      trigger.addEventListener("click", event => {
        event.preventDefault();
        const opening = !dropdown.classList.contains("is-open");
        desktopDropdowns.forEach(item => {
          item.classList.remove("is-open");
          const itemTrigger = item.querySelector(".kd-desktop-trigger");
          if (itemTrigger) itemTrigger.setAttribute("aria-expanded", "false");
        });
        if (opening) {
          dropdown.classList.add("is-open");
          trigger.setAttribute("aria-expanded", "true");
        }
      });
    });
    document.addEventListener("click", event => {
      if (event.target.closest(".kd-desktop-dropdown")) return;
      desktopDropdowns.forEach(item => {
        item.classList.remove("is-open");
        const itemTrigger = item.querySelector(".kd-desktop-trigger");
        if (itemTrigger) itemTrigger.setAttribute("aria-expanded", "false");
      });
    });
    document.addEventListener("keydown", event => {
      if (event.key !== "Escape") return;
      desktopDropdowns.forEach(item => {
        item.classList.remove("is-open");
        const itemTrigger = item.querySelector(".kd-desktop-trigger");
        if (itemTrigger) itemTrigger.setAttribute("aria-expanded", "false");
      });
    });

    const nav = header.querySelector("#menu");
    const button = header.querySelector("#menuBtn");
    if (button.dataset.kdMenuBound === "true") return;
    button.dataset.kdMenuBound = "true";
    const isMobile = () => window.matchMedia("(max-width:768px)").matches;
    const closeMenu = () => {
      nav.classList.remove("show");
      backdrop.classList.remove("show");
      button.setAttribute("aria-expanded","false");
      button.setAttribute("aria-label","Open navigation menu");
      document.body.classList.remove("menu-open");
    };
    const openMenu = () => {
      nav.classList.add("show");
      backdrop.classList.add("show");
      button.setAttribute("aria-expanded","true");
      button.setAttribute("aria-label","Close navigation menu");
      document.body.classList.add("menu-open");
    };
    button.addEventListener("click", event => {
      event.preventDefault(); event.stopPropagation();
      if (!isMobile()) return;
      nav.classList.contains("show") ? closeMenu() : openMenu();
    });
    backdrop.addEventListener("click",closeMenu);
    nav.addEventListener("click",event => { if (event.target.closest("a")) closeMenu(); });
    document.addEventListener("keydown",event => { if (event.key === "Escape") closeMenu(); });
    window.addEventListener("resize",() => { if (!isMobile()) closeMenu(); });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded",initKeyDhanHeader,{once:true});
  else initKeyDhanHeader();
})();