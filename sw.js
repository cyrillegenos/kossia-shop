const CACHE_NAME = "kossia-shop-pwa-v1";
const APP_SHELL = ["/", "/track-order.html", "/manifest.json", "/icons/icon-192.svg", "/icons/icon-512.svg"];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    await cache.addAll(APP_SHELL);
    await self.skipWaiting();
  })());
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((key) => key.startsWith("kossia-shop-pwa-") && key !== CACHE_NAME).map((key) => caches.delete(key)));
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.startsWith("/admin")) return;

  if (request.mode === "navigate") {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response && response.ok && (url.pathname === "/" || url.pathname === "/index.html" || url.pathname === "/track-order.html")) {
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, response.clone());
        }
        return response;
      } catch (error) {
        return (await caches.match(request)) || (await caches.match(url.pathname === "/track-order.html" ? "/track-order.html" : "/")) || Response.error();
      }
    })());
    return;
  }

  if (["style", "script", "image", "font"].includes(request.destination) || url.pathname === "/manifest.json") {
    event.respondWith((async () => {
      try {
        const response = await fetch(request);
        if (response && response.ok) {
          const cache = await caches.open(CACHE_NAME);
          cache.put(request, response.clone());
        }
        return response;
      } catch (error) {
        return (await caches.match(request)) || Response.error();
      }
    })());
  }
});
