// Minimal service worker for PWA installability.
// A fetch handler is required for Chrome to show the install prompt.
self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(clients.claim());
});

self.addEventListener("fetch", (event) => {
  // Only handle same-origin requests; let external CDN requests pass through to the browser.
  if (new URL(event.request.url).origin === self.location.origin) {
    event.respondWith(fetch(event.request));
  }
});
