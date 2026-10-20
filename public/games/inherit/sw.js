const CACHE = 'inherit-shell-v16';
const SHELL = ['/games/inherit/index.html', '/games/inherit/manifest.webmanifest', '/games/inherit/interface.js', '/games/inherit/interface.css', '/games/inherit/account.js', '/games/inherit/account.css', '/games/inherit/cinematic.js', '/games/inherit/cinematic.css', '/games/inherit/zh.js', '/games/inherit/legacy.css', '/games/inherit/legacy-engine.js', '/games/inherit/legacy-ui.js', '/games/inherit/story.css', '/games/inherit/story-engine.js', '/games/inherit/story-ui.js', '/games/inherit/world-cycle.css', '/games/inherit/world-cycle-engine.js', '/games/inherit/return-notebook.js', '/games/inherit/world-cycle-ui.js', '/games/inherit/cosmetic-rewards.css', '/games/inherit/cosmetic-rewards.js', '/games/inherit/research.css', '/games/inherit/first-steps.css', '/games/inherit/research-core.js', '/games/inherit/research-i18n.js', '/games/inherit/research-ui.js', '/games/inherit/first-steps.js', '/games/inherit/pilot-metrics.js', '/games/inherit/pilot/index.html', '/games/inherit/pilot/landing.js', '/games/inherit/pilot/pilot.css', '/games/inherit/pilot/report.html', '/games/inherit/pilot/report.js'];
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
    // A pilot report must never fall back to the game HTML when offline.
    const fallback = path.startsWith('/games/inherit/pilot/') ?
      (path.endsWith('/report.html') ? '/games/inherit/pilot/report.html' : '/games/inherit/pilot/index.html') :
      '/games/inherit/index.html';
    event.respondWith(fetch(request).then(response => {
      if (response.ok) {
        const copy = response.clone();
        event.waitUntil(caches.open(CACHE).then(cache => cache.put(fallback, copy)));
      }
      return response;
    }).catch(() => caches.match(fallback)));
    return;
  }
  if (!/\.(?:webmanifest|mjs|js|css|woff2?)$/i.test(path)) return;
  event.respondWith(caches.match(request).then(cached => cached || fetch(request).then(response => {
    if (response.ok && new URL(request.url).pathname.startsWith('/games/inherit/')) {
      const copy = response.clone();
      caches.open(CACHE).then(cache => cache.put(request, copy));
    }
    return response;
  })));
});
