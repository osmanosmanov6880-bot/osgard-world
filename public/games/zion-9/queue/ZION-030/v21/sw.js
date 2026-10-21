// SHADOW PROTOCOL v21 - scoped, public-only app shell cache
const CACHE = 'shadow-zion-030-v21-20261021';
const SHELL = ['./index.html', './manifest.webmanifest', './assets/icon.svg'];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(k => k.startsWith('shadow-zion-030-') && k !== CACHE).map(k => caches.delete(k))
  )).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const scope = new URL(self.registration.scope);
  if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return;
  const relative = url.pathname.slice(scope.pathname.length);
  const isPage = relative === '' || relative === 'index.html' || relative === 'PLAY_OFFLINE.html';
  if (!isPage && relative !== 'manifest.webmanifest' && relative !== 'assets/icon.svg') return;
  const cacheKey = isPage ? new URL('./index.html', scope).href : url.href;
  event.respondWith(fetch(request).then(response => {
    if (response.ok) {
      const copy = response.clone();
      caches.open(CACHE).then(cache => cache.put(cacheKey, copy)).catch(() => {});
    }
    return response;
  }).catch(() => caches.match(cacheKey).then(cached => cached || new Response('Offline', {status: 503}))));
});
