/* KeyDhan PWA service worker — conservative caching; never cache admin/API or form submissions. */
"use strict";

const CACHE_PREFIX = "keydhan-pwa-";
const STATIC_CACHE = CACHE_PREFIX + "static-v1";
const PAGE_CACHE = CACHE_PREFIX + "pages-v1";
const OFFLINE_URL = "/offline.html";
const STATIC_ASSETS = [
  "/favicon.svg",
  "/assets/keydhan-app-icon.svg",
  "/manifest.json",
  OFFLINE_URL
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then((cache) => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys
        .filter((key) => key.startsWith(CACHE_PREFIX) && ![STATIC_CACHE, PAGE_CACHE].includes(key))
        .map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

function isSensitivePath(pathname) {
  return pathname.startsWith("/admin") ||
    pathname.startsWith("/api/") ||
    pathname.startsWith("/worker") ||
    pathname.startsWith("/cdn-cgi/");
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin || isSensitivePath(url.pathname)) return;

  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request).then((response) => {
        if (response && response.ok && response.type === "basic") {
          const copy = response.clone();
          caches.open(PAGE_CACHE).then((cache) => cache.put(request, copy));
        }
        return response;
      }).catch(async () => {
        return (await caches.match(request)) ||
          (await caches.match(OFFLINE_URL)) ||
          new Response("You are offline. Please reconnect and try again.", {
            status: 503,
            headers: { "Content-Type": "text/plain; charset=utf-8" }
          });
      })
    );
    return;
  }

  if (url.pathname.startsWith("/assets/") ||
      /\.(css|js|svg|png|webp|jpg|jpeg|woff2?)$/i.test(url.pathname)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const network = fetch(request).then((response) => {
          if (response && response.ok && response.type === "basic" &&
              !response.headers.has("Set-Cookie")) {
            const copy = response.clone();
            caches.open(STATIC_CACHE).then((cache) => cache.put(request, copy));
          }
          return response;
        });
        return cached || network;
      })
    );
  }
});
