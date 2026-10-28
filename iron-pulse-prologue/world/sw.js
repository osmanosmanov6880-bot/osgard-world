/* IRON PULSE WORLD — deterministic same-origin, shell-only offline fallback.
   Large WebGL assets are NOT auto-cached; replay availability is not promised.
   No background analytics, push, notifications, remote CDN or account sync. */
const SHELL_CACHE = "iron-pulse-world-v9-shell-1";
const SHELL_FILES = [
  "./index.html","./styles.css","./app.js",
  "./assets/iron-pulse-mark.svg","./manifest.webmanifest"
];
self.addEventListener("install",(event)=>{
  event.waitUntil(caches.open(SHELL_CACHE).then(cache=>cache.addAll(SHELL_FILES)));
});
self.addEventListener("activate",(event)=>{
  event.waitUntil(caches.keys().then(keys=>
    Promise.all(keys.filter(key=>key.startsWith("iron-pulse-world-") && key!==SHELL_CACHE)
      .map(key=>caches.delete(key)))));
});
self.addEventListener("fetch",(event)=>{
  const request = event.request;
  if(request.method!=="GET") return;
  const url = new URL(request.url);
  if(url.origin !== self.location.origin) return;
  if(url.pathname.includes("/play/")) return; // no hidden ~50MB WASM cache
  const shellHit = SHELL_FILES.some(file=>url.pathname.endsWith(file.replace("./","/")));
  if(!shellHit) return;
  event.respondWith(caches.match(request).then(cached=>cached || fetch(request)));
});
