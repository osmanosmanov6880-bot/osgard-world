import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(p, 'utf8');
const routes = [
  ['public/development/textura/index.html', 'ru', 'A QUIETER', '/development/textura/'],
  ['public/development/textura/en/index.html', 'en', 'A QUIETER', '/development/textura/en/'],
  ['public/development/textura/ar/index.html', 'ar', 'A QUIETER', '/development/textura/ar/'],
];
for (const [path, locale, headline, canonical] of routes) {
  assert.ok(existsSync(path), `missing locale route: ${path}`);
  const html = read(path);
  assert.ok(html.includes(`<html lang="${locale}"`), `${locale}: wrong html language`);
  assert.ok(html.includes(headline), `${locale}: missing hero headline`);
  assert.ok(html.includes(`href="https://osgard.world${canonical}"`), `${locale}: missing canonical`);
  assert.ok(html.includes('og:image') && html.includes('/development/textura/og.svg'), `${locale}: missing social preview`);
  assert.ok(html.includes('/development/textura/case.css'), `${locale}: missing stylesheet`);
  assert.ok(html.includes('/development/textura/case.js'), `${locale}: missing interaction script`);
  assert.ok(html.includes('demo-only'), `${locale}: missing demo status`);
  assert.ok(html.includes('no live checkout') || html.includes('не подключены') || html.includes('غير متصلين'), `${locale}: missing checkout caveat`);
  assert.ok(html.includes('data-copy-brief'), `${locale}: missing brief-copy interaction`);
}
const css = read('public/development/textura/case.css');
for (const token of ['@media(max-width:560px)', 'prefers-reduced-motion', ':focus-visible', 'tx-hero', 'tx-status']) {
  assert.ok(css.includes(token), `missing responsive/accessibility style: ${token}`);
}
const js = read('public/development/textura/case.js');
assert.ok(js.includes('data-copy-brief') && js.includes('navigator.clipboard'), 'brief-copy behaviour missing');
const og = read('public/development/textura/og.svg');
assert.ok(og.includes('width="1200"') && og.includes('height="630"'), 'social image dimensions are incorrect');
const index = read('public/development/index.html');
assert.ok(index.includes('href="/development/textura/"'), 'Development portfolio card missing TEXTURA');
const sitemap = read('public/sitemap.xml');
for (const route of ['/development/textura/', '/development/textura/en/', '/development/textura/ar/']) {
  assert.ok(sitemap.includes(`https://osgard.world${route}`), `sitemap missing ${route}`);
}
const workflow = read('.github/workflows/deploy-frontend.yml');
assert.ok(workflow.includes('public/development/textura/**'), 'deployment workflow does not watch TEXTURA case');
assert.ok(workflow.includes('qa:textura-case'), 'deployment workflow does not run TEXTURA smoke test');
console.log('TEXTURA CASE SMOKE PASS: RU/EN/AR routes, metadata, responsive styles, OG artwork, portfolio card, sitemap and deployment QA.');
