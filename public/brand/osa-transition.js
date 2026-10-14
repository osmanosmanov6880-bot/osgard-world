(() => {
  'use strict';
  const key = 'osgard.osa5.transition.v1';
  const normalize = path => path.replace(/\/+$/, '') || '/';
  const profile = pathname => {
    const path = normalize(pathname);
    if (path === '/') return 'intelligence';
    if (path === '/portal' || ['/worlds','/catalog','/chronicle','/masters','/club','/aurum','/timecoin','/development','/mobility','/create','/business','/week','/next','/archive','/profile','/community','/stream'].includes(path)) return 'ecosystem';
    if (path === '/academy') return 'academy';
    if (path === '/osa-cinema') return 'cinema';
    if (path === '/skillcred' || path.startsWith('/skillcred/')) return 'credentials';
    if (path === '/games' || path.startsWith('/games/') || path === '/entertainment') return 'games';
    if (path.startsWith('/play/') || path === '/games/time' || path === '/miniapp') return 'immersive';
    return null;
  };
  const safeRead = () => { try { return sessionStorage.getItem(key); } catch { return null; } };
  const safeWrite = value => { try { sessionStorage.setItem(key, value); } catch { /* optional */ } };
  const currentProfile = profile(location.pathname);
  if (currentProfile) document.documentElement.dataset.osaProfile = currentProfile;
  document.addEventListener('click', event => {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const source = event.target instanceof Element ? event.target.closest('a[href]') : null;
    if (!source || source.hasAttribute('download') || (source.target && source.target.toLowerCase() !== '_self') || source.relList.contains('external')) return;
    let destination;
    try { destination = new URL(source.href, location.href); } catch { return; }
    if (destination.origin !== location.origin || !['https:', 'http:'].includes(destination.protocol)) return;
    if (normalize(destination.pathname) === normalize(location.pathname)) return;
    const from = profile(location.pathname), to = profile(destination.pathname);
    if (!from || !to || from === to) return;
    safeWrite(JSON.stringify({ to: normalize(destination.pathname), at: Date.now() }));
  }, true);
  let pending = null;
  try { pending = JSON.parse(safeRead() || 'null'); } catch { pending = null; }
  try { sessionStorage.removeItem(key); } catch { /* optional */ }
  if (!pending || normalize(location.pathname) !== pending.to || Date.now() - pending.at > 5000) return;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  let mounted = false;
  let observer = null;
  const mount = () => {
    if (mounted || !document.body) return;
    const appRoot = document.getElementById('root');
    if (appRoot && !appRoot.childElementCount) return;
    mounted = true;
    const overlay = document.createElement('div');
    overlay.className = 'osa5-transition-overlay';
    overlay.setAttribute('aria-hidden', 'true');
    overlay.innerHTML = '<img src="/brand/osa-5-mark.svg" alt=""><span class="osa5-transition-word">OSA <small>5.0</small></span>';
    document.body.appendChild(overlay);
    requestAnimationFrame(() => requestAnimationFrame(() => overlay.classList.add('is-leaving')));
    window.setTimeout(() => overlay.remove(), reduced ? 100 : 460);
    if (observer) observer.disconnect();
  };
  const root = document.getElementById('root');
  if (root) { observer = new MutationObserver(mount); observer.observe(root, { childList: true, subtree: true }); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mount, { once: true });
  else mount();
  window.setTimeout(mount, 1400);
})();