import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import vm from 'node:vm';

const root = process.cwd();
const files = [
  'public/development/auto-style/index.html',
  'public/development/auto-style/en/index.html',
  'public/development/auto-style/ar/index.html',
  'public/development/auto-style/case.css',
  'public/development/auto-style/case.js',
  'public/development/auto-style/og.svg',
  'src/auto-style-case.css',
  'src/Development.tsx',
  'public/sitemap.xml',
  'scripts/production-route-matrix.mjs',
  '.github/workflows/deploy-frontend.yml',
  'package.json',
];
for (const file of files) assert.ok(existsSync(resolve(root, file)), 'Missing AUTO STYLE release file: ' + file);
const read = p => readFileSync(resolve(root, p), 'utf8');
const pages = [
  { lang: 'ru', path: 'public/development/auto-style/index.html', url: 'https://osgard.world/development/auto-style/', title: 'AUTO STYLE — премиальный цифровой концепт | OSGARD Development', dir: 'ltr' },
  { lang: 'en', path: 'public/development/auto-style/en/index.html', url: 'https://osgard.world/development/auto-style/en/', title: 'AUTO STYLE — Premium Digital Concept | OSGARD Development', dir: 'ltr' },
  { lang: 'ar', path: 'public/development/auto-style/ar/index.html', url: 'https://osgard.world/development/auto-style/ar/', title: 'AUTO STYLE — مفهوم رقمي فاخر | OSGARD Development', dir: 'rtl' },
];
const sitemap = read('public/sitemap.xml');
const routes = read('scripts/production-route-matrix.mjs');
const workflow = read('.github/workflows/deploy-frontend.yml');
const packageJson = JSON.parse(read('package.json'));
const card = read('src/Development.tsx');
const featureCss = read('src/auto-style-case.css');
const caseCss = read('public/development/auto-style/case.css');
const caseJs = read('public/development/auto-style/case.js');
const og = read('public/development/auto-style/og.svg');
let checks = 0;
function check(name, fn) { fn(); checks++; console.log('PASS ' + name); }

check('three localized static entrypoints have correct metadata', () => {
  for (const p of pages) {
    const html = read(p.path);
    assert.ok(html.includes('<html lang="' + p.lang + '"' + (p.dir === 'rtl' ? ' dir="rtl"' : '')), p.lang + ' language/direction');
    assert.ok(html.includes('<title>' + p.title + '</title>'), p.lang + ' title');
    assert.ok(html.includes('<link rel="canonical" href="' + p.url + '">'), p.lang + ' canonical');
    for (const other of pages) assert.ok(html.includes('hreflang="' + other.lang + '" href="' + other.url + '"'), p.lang + ' hreflang ' + other.lang);
    assert.ok(html.includes('property="og:image" content="https://osgard.world/development/auto-style/og.svg"'), p.lang + ' OG image');
    assert.ok(html.includes('name="twitter:card" content="summary_large_image"'), p.lang + ' social preview');
    assert.ok(html.includes('data-case-status="demo-only"'), p.lang + ' demo status');
    assert.ok(html.includes('id="main"') && html.includes('class="as-skip"'), p.lang + ' accessibility landmarks');
    assert.ok(html.includes('case.css') && html.includes('case.js'), p.lang + ' shared assets');
    assert.ok(html.includes('application/ld+json'), p.lang + ' structured data');
  }
});

check('case content communicates product scope and honest demo status', () => {
  const ru = read(pages[0].path);
  const en = read(pages[1].path);
  const ar = read(pages[2].path);
  for (const html of [ru, en, ar]) {
    assert.ok(html.includes('12'), 'service count should be grounded');
    assert.ok(html.includes('DEMO-ONLY'), 'visible disclosure must remain');
    assert.ok(html.includes('NOT LIVE') || html.includes('не подключены') || html.includes('لم يتم توصيل'), 'production status must not be misrepresented');
    assert.ok(html.includes('mailto:osman.osmanov0099@gmail.com'), 'contact action');
    assert.ok(html.includes('data-copy-brief'), 'local-only brief copy action');
  }
  assert.ok(ru.includes('не заявляет о завершённом внедрении'), 'RU client-result disclosure');
  assert.ok(en.includes('does not claim a completed implementation'), 'EN client-result disclosure');
  assert.ok(ar.includes('ولا تدعي تنفيذاً مكتملاً'), 'AR client-result disclosure');
});

check('no enquiry is falsely submitted or posted from the portfolio case', () => {
  for (const p of pages) {
    const html = read(p.path);
    assert.ok(!/<form\b/i.test(html), p.lang + ' no unconfigured enquiry form');
    assert.ok(!/action=["']\/api/i.test(html), p.lang + ' no hidden POST path');
  }
  assert.ok(!/\b(fetch|sendBeacon|XMLHttpRequest)\s*\(/.test(caseJs), 'case JS is a local clipboard interaction only');
  new vm.Script(caseJs, { filename: 'auto-style-case.js' });
});

check('responsive premium visual system and accessible motion preferences', () => {
  assert.ok(caseCss.includes('@media(max-width:640px)'));
  assert.ok(caseCss.includes('prefers-reduced-motion:reduce'));
  assert.ok(caseCss.includes(':focus-visible'));
  assert.ok(caseCss.includes('.as-car-svg'));
  assert.ok(featureCss.includes('.auto-style-featured-case') && featureCss.includes('prefers-reduced-motion:reduce'));
  assert.ok(card.includes("import './auto-style-case.css'"));
  assert.ok(card.includes('href="/development/auto-style/"'));
  assert.ok(card.includes('FLAGSHIP CASE / 04') && card.includes('CASE 04 / 04'));
});

check('premium social-card SVG is valid and sized for sharing', () => {
  assert.ok(og.startsWith('<svg'));
  assert.ok(og.includes('width="1200" height="630"') && og.includes('viewBox="0 0 1200 630"'));
  assert.ok(og.includes('AUTO STYLE') && og.includes('DEMO-ONLY / NOT LIVE IN PRODUCTION'));
  for (const p of pages) assert.ok(read(p.path).includes('og.svg'));
});

check('sitemap and remote route matrix include all three canonical routes', () => {
  for (const p of pages) {
    assert.ok(sitemap.includes('<loc>' + p.url + '</loc>'), p.lang + ' sitemap URL');
    const route = new URL(p.url).pathname;
    assert.ok(routes.includes("'" + route + "'"), p.lang + ' route matrix entry');
    assert.ok(routes.includes('case.css') && routes.includes('case.js'), 'asset smoke routes');
  }
});

check('SSH deployment workflow runs the new case gate', () => {
  assert.ok(workflow.includes('"public/development/auto-style/**"'), 'deploy path filter');
  assert.ok(workflow.includes('"scripts/auto-style-case-smoke.mjs"'), 'smoke script path filter');
  assert.ok(workflow.includes('npm run qa:auto-style-case'), 'pre-deploy case test step');
  assert.equal(packageJson.scripts?.['qa:auto-style-case'], 'node scripts/auto-style-case-smoke.mjs', 'package script');
  assert.ok(workflow.includes('secrets.OSGARD_DEPLOY_HOST') && workflow.includes('secrets.OSGARD_DEPLOY_KEY'), 'actual SSH delivery path remains configured in workflow');
});

console.log('AUTO STYLE CASE: ' + checks + ' contract groups passed.');
