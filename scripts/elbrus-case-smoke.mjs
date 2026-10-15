import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const paths = [
  "public/entertainment/index.html",
  "public/entertainment/elbrus/index.html",
  "public/entertainment/elbrus/og.svg",
  "public/sitemap.xml",
  ".github/workflows/deploy-frontend.yml",
  "package.json"
];
for (const path of paths) assert.ok(existsSync(resolve(root, path)), "Missing ELBRUS publication file: " + path);
const read = p => readFileSync(resolve(root, p), "utf8");
const hub = read("public/entertainment/index.html");
const page = read("public/entertainment/elbrus/index.html");
const sitemap = read("public/sitemap.xml");
const workflow = read(".github/workflows/deploy-frontend.yml");
const pkg = JSON.parse(read("package.json"));

assert.ok(hub.includes('href="/entertainment/elbrus/"'), "Entertainment hub must link to the ELBRUS case");
assert.ok(hub.includes("case-shelf") && hub.includes("SELECTED DIGITAL EXPERIENCE"), "Entertainment hub must expose the selected digital experiences shelf");
assert.equal((hub.match(/class="case-shelf"/g) || []).length, 1, "Entertainment hub must contain exactly one ELBRUS case shelf");
assert.equal((hub.match(/Selected digital experience — ELBRUS case/g) || []).length, 1, "ELBRUS shelf CSS must not be duplicated");
assert.equal(hub.split('href="/entertainment/elbrus/"').length - 1, 1, "ELBRUS case card must occur once");
assert.ok(page.includes("<title>ELBRUS — Hospitality Experience | OSGARD WORLD</title>"), "ELBRUS case title missing");
assert.ok(page.includes('rel="canonical" href="https://osgard.world/entertainment/elbrus/"'), "Canonical URL missing");
assert.ok(page.includes('data-lang="en"') && page.includes('data-lang="ru"'), "RU/EN language control missing");
assert.ok(page.includes('id="interactive-preview"') && page.includes('data-filter="khinkal"'), "Interactive menu preview missing");
assert.ok(page.includes("does not place orders") && page.includes("не отправляет заказы"), "Demo-only boundaries must be explicit in both languages");
assert.ok(!page.includes("/api/orders") && !page.includes("/api/reservations") && !page.includes("fetch("), "Public case preview must not claim or attempt live order integration");
assert.ok(sitemap.includes("<loc>https://osgard.world/entertainment/elbrus/</loc>"), "ELBRUS case URL missing from sitemap");
assert.ok(sitemap.includes("<loc>https://osgard.world/entertainment/</loc>"), "Entertainment hub missing from sitemap");
assert.ok(workflow.includes('"public/entertainment/**"'), "SSH deployment workflow must trigger for Entertainment case changes");
assert.ok(workflow.includes("npm run qa:elbrus-case"), "SSH workflow must run ELBRUS case smoke before build/deploy");
assert.equal(pkg.scripts?.["qa:elbrus-case"], "node scripts/elbrus-case-smoke.mjs", "package.json must register the case smoke test");
const scripts = [...page.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
assert.equal(scripts.length, 1, "Case preview should keep a single auditable script");
new Function(scripts[0]);
assert.ok(page.includes("@media(max-width:600px)") && page.includes("prefers-reduced-motion:reduce"), "Responsive and reduced-motion support missing");
assert.ok(page.includes('aria-live="polite"') && page.includes('aria-pressed="true"'), "Accessible interactive states missing");
console.log("ELBRUS_CASE_SMOKE_PASS: hub link, case SEO, RU/EN, local demo interactions, demo disclosure, sitemap and SSH workflow verified.");
