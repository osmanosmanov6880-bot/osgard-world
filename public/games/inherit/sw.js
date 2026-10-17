const CACHE = 'inherit-shell-v7';
const SHELL = ['/games/inherit/index.html', '/games/inherit/manifest.webmanifest', '/games/inherit/interface.js', '/games/inherit/interface.css'];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith('inherit-shell-') && key !== CACHE).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;
  const path = new URL(request.url).pathname;
  if (!path.startsWith('/games/inherit/')) return;
  if (request.mode === 'navigate' || path.endsWith('.html') || path === '/games/inherit/') {
    event.respondWith(fetch(request).then(response => {
      if (response.ok) { const copy = response.clone(); caches.open(CACHE).then(cache => cache.put('/games/inherit/index.html', copy)); }
      return response;
    }).catch(() => caches.match('/games/inherit/index.html')));
    return;
  }
  if (!/\.(?:webmanifest|js|css|woff2?)$/i.test(path)) return;
  event.respondWith(caches.match(request).then(cached => cached || fetch(request).then(response => {
    if (response.ok && new URL(request.url).pathname.startsWith('/games/inherit/')) {
      const copy = response.clone();
      caches.open(CACHE).then(cache => cache.put(request, copy));
    }
    return response;
  })));
});
