import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const html = readFileSync('public/development/merakki/index.html', 'utf8');
const htmlEn = readFileSync('public/development/merakki/en/index.html', 'utf8');
const htmlAr = readFileSync('public/development/merakki/ar/index.html', 'utf8');
const css = readFileSync('src/merakki-case.css', 'utf8');
const socialCard = readFileSync('public/development/merakki/og.svg', 'utf8');
let checks = 0;
async function check(name, fn) {
  await fn();
  checks++;
  console.log('PASS ' + name);
}
const inlineMatch = html.match(/<script>([\s\S]*?)<\/script>/i);
assert.ok(inlineMatch, 'inline page script must exist');
const inlineScript = inlineMatch[1];
new vm.Script(inlineScript, { filename: 'merakki-inline.js' });
const localeMatch = inlineScript.match(/const translations=(\{[\s\S]*?\});let briefGenerated=/);
assert.ok(localeMatch, 'translation dictionary must be a JSON object');
const translations = JSON.parse(localeMatch[1]);
const structuredMatch = html.match(/<script type="application\/ld\+json" id="case-structured-data">([\s\S]*?)<\/script>/);
assert.ok(structuredMatch, 'structured data script must exist');
const structured = JSON.parse(structuredMatch[1]);

await check('canonical route and demo-only boundary', () => {
  assert.ok(html.includes('<link rel="canonical" href="https://osgard.world/development/merakki/">'));
  assert.ok(html.includes('data-case-status="demo-only"'));
  assert.ok(html.includes('Live checkout and payments are disabled') || html.includes('Реальные заказы и платежи отключены'));
});
await check('social card metadata is present for RU/EN/AR', () => {
 assert.ok(socialCard.includes('<svg') && socialCard.includes('width="1200" height="630"') && socialCard.includes('viewBox="0 0 1200 630"'));
 assert.ok(socialCard.includes('MERAKKI') && socialCard.includes('GLOBAL') && socialCard.includes('NO LIVE CHECKOUT'));
 for(const page of [html,htmlEn,htmlAr]){
  assert.ok(page.includes('property="og:image" content="https://osgard.world/development/merakki/og.svg'));
  assert.ok(page.includes('property="og:image:type" content="image/svg+xml"'));
  assert.ok(page.includes('name="twitter:card" content="summary_large_image"'));
  assert.ok(page.includes('name="twitter:image" content="https://osgard.world/development/merakki/og.svg'));
 }
});
await check('structured data includes Article and breadcrumbs', () => {
  assert.ok(structured['@graph'].some(item => item['@type'] === 'Article'));
  assert.ok(structured['@graph'].some(item => item['@type'] === 'BreadcrumbList'));
});
await check('campaign tagging keeps three distinct CTA placements', () => {
  assert.ok(html.includes('utm_content=header'));
  assert.ok(html.includes('utm_content=hero'));
  assert.ok(html.includes('utm_content=final'));
  assert.equal((html.match(/utm_campaign=merakki_global_case/g)||[]).length, 3);
});
await check('brief form is bounded, local-only and never POSTs', () => {
  assert.match(html, /<form class="brief-form" id="project-brief"[^>]*>/);
  for (const id of ['brief-type','brief-goal','brief-timeline']) assert.match(html, new RegExp('<select id="' + id + '" name="[^"]+" required>'));
  assert.match(html, /<textarea id="brief-context"[^>]*maxlength="320"/);
  assert.ok(!/<form[^>]+\baction=/i.test(html));
  assert.ok(inlineScript.includes('event.preventDefault()'));
  assert.ok(!/\b(fetch|sendBeacon)\s*\(/.test(inlineScript));
});
await check('preview and copy controls are accessible and hidden until generated', () => {
  assert.match(html, /id="brief-preview"[^>]*hidden/);
  assert.ok(html.includes('id="brief-preview-text" tabindex="0"'));
  assert.ok(html.includes('id="brief-copy" type="button"'));
  assert.ok(html.includes('id="brief-download" type="button"'));
  assert.ok(html.includes('id="brief-share" type="button"'));
  assert.ok(html.includes('id="brief-copy-status" role="status" aria-live="polite"'));
  assert.ok(css.includes('.brief-preview[hidden]{display:none!important}'));
  assert.ok(css.includes('white-space:pre-wrap'));
});
await check('RU and EN include every preview/copy translation', () => {
  for (const lang of ['ru','en']) for (const key of ['briefPreviewTitle','briefPreviewBody','briefCopy','briefCopyHint','briefCopySuccess','briefCopyFallback']) assert.equal(typeof translations[lang][key], 'string', lang + ' missing ' + key);
});
await check('clipboard only runs on explicit click and has a fallback', () => {
  assert.ok(inlineScript.includes("briefCopyButton.addEventListener('click',copyBriefMessage)"));
  assert.ok(inlineScript.includes("briefDownloadButton.addEventListener('click',downloadBriefMessage)"));
  assert.ok(inlineScript.includes("briefShareButton.addEventListener('click',shareBriefMessage)"));
  assert.ok(inlineScript.includes("URL.createObjectURL(file)"));
  assert.ok(inlineScript.includes("new Blob([message]"));
  assert.ok(inlineScript.includes("navigator.share({title:v.briefShareTitle,text:message})"));
  assert.ok(inlineScript.includes('navigator.clipboard.writeText(message)'));
  assert.ok(inlineScript.includes("document.execCommand('copy')"));
  assert.ok(inlineScript.includes('v.briefCopyFallback'));
});
await check('text stays bounded and is encoded before WhatsApp/email handoff', () => {
  assert.ok(inlineScript.includes(".trim().slice(0,320)"));
  assert.ok(inlineScript.includes("encodeURIComponent(message)"));
});

function makeHarness({ clipboard = true, valid = true, legacyCopyWorks = true, webShare = true, shareErrorName = null } = {}) {
  const copied = [], nodes = new Map(), blobs = [], objectUrls = [], revokedUrls = [], shareCalls = [];
  class BlobMock { constructor(parts, options = {}) { this.parts = parts; this.type = options.type || ''; blobs.push(this); } }
  const URLMock = {
    createObjectURL(blob) { const url = 'blob:merakki-brief-' + (objectUrls.length + 1); objectUrls.push({ url, blob }); return url; },
    revokeObjectURL(url) { revokedUrls.push(url); }
  };
  const timeoutMock = callback => { callback(); return 1; };
  const makeNode = (id, extras = {}) => {
    const n = {id,value:'',href:'',textContent:'',hidden:true,style:{},dataset:{},attrs:{},listeners:{},selectedOptions:[],reportValidity:()=>valid,
      addEventListener(type,fn){(this.listeners[type] ||= []).push(fn);},
      setAttribute(name,value){this.attrs[name]=String(value);},
      getAttribute(name){return this.attrs[name] ?? null;},
      focus(){this.focused=true;},select(){this.selected=true;},click(){this.clicked=true;},remove(){this.removed=true;},
      ...extras};
    nodes.set(id,n);return n;
  };
  const type=makeNode('brief-type');type.selectedOptions=[{textContent:'Business website'}];
  const goal=makeNode('brief-goal');goal.selectedOptions=[{textContent:'Increase online sales'}];
  const timeline=makeNode('brief-timeline');timeline.selectedOptions=[{textContent:'Within a month'}];
  const context=makeNode('brief-context');context.value='Build a multilingual storefront';context.attrs['data-i18n-placeholder']='briefContextPlaceholder';
  const copyStatus=makeNode('brief-copy-status');
  const status=makeNode('brief-status');status.attrs['data-i18n']='briefPrivacy';
  const previewText=makeNode('brief-preview-text'),preview=makeNode('brief-preview'),copyButton=makeNode('brief-copy');
  const downloadButton=makeNode('brief-download'),shareButton=makeNode('brief-share');
  const form=makeNode('project-brief',{reportValidity:()=>valid});
  for(const id of ['contact-cta','email-cta','brief-count','brief-generate','inquiry-note']) if(!nodes.has(id))makeNode(id);
  const ruButton=makeNode('lang-ru',{dataset:{lang:'ru'}}),enButton=makeNode('lang-en',{dataset:{lang:'en'}});
  const metas=new Map([
    ['meta[name="description"]',makeNode('meta-description',{content:''})],
    ['meta[property="og:title"]',makeNode('meta-og-title',{content:''})],
    ['meta[property="og:description"]',makeNode('meta-og-description',{content:''})],
    ['meta[name="twitter:title"]',makeNode('meta-twitter-title',{content:''})],
    ['meta[name="twitter:description"]',makeNode('meta-twitter-description',{content:''})],
    ['meta[property="og:locale"]',makeNode('meta-og-locale',{content:''})]
  ]);
  const doc={title:'',documentElement:{lang:'ru'},body:{appendChild(n){this.child=n;}},
    getElementById(id){return nodes.get(id)||null;},
    querySelectorAll(selector){if(selector==='[data-lang]')return [ruButton,enButton];if(selector==='[data-i18n]')return [status];if(selector==='[data-i18n-placeholder]')return [context];return [];},
    querySelector(selector){return metas.get(selector)||null;},
    createElement(tag){return makeNode('temporary-copy-'+tag);},
    execCommand(){return legacyCopyWorks;}
  };
  const navigator={};
  if(clipboard)navigator.clipboard={async writeText(text){copied.push(text);}};
  if(webShare)navigator.share=async payload=>{shareCalls.push(payload);if(shareErrorName){const error=new Error('Share action failed');error.name=shareErrorName;throw error;}};
  return {document:doc,navigator,nodes,copied,blobs,objectUrls,revokedUrls,shareCalls,Blob:BlobMock,URL:URLMock,setTimeout:timeoutMock,buttons:{ruButton,enButton},form,context,preview,previewText,status,copyStatus,copyButton,downloadButton,shareButton};
}
function runPage(h) {
  const context=vm.createContext({document:h.document,navigator:h.navigator,Blob:h.Blob,URL:h.URL,setTimeout:h.setTimeout,console});
  new vm.Script(inlineScript).runInContext(context);
  return context;
}
async function submit(h) {
  const fn=h.form.listeners.submit?.[0];assert.ok(fn,'brief submit handler must be bound');
  let prevented=false;fn({preventDefault(){prevented=true;}});return prevented;
}
await check('valid submit reveals message and does not navigate', async () => {
  const h=makeHarness();runPage(h);
  assert.equal(await submit(h),true);
  assert.equal(h.preview.hidden,false);
  assert.ok(h.previewText.textContent.includes('Business website'));
  assert.ok(h.previewText.textContent.includes('Increase online sales'));
  assert.ok(h.nodes.get('contact-cta').href.startsWith('https://wa.me/79640027222?text='));
  assert.ok(h.nodes.get('email-cta').href.startsWith('mailto:osman.osmanov0099@gmail.com?subject='));
});
await check('locale changes update contact destinations', () => {
  const h=makeHarness();runPage(h);h.buttons.enButton.listeners.click[0]();
  assert.equal(h.document.documentElement.lang,'en');
  assert.ok(h.nodes.get('contact-cta').href.includes(encodeURIComponent(translations.en.contactMessage)));
});
await check('invalid form does not reveal generated brief', async () => {
  const h=makeHarness({valid:false});runPage(h);await submit(h);assert.equal(h.preview.hidden,true);
});
await check('modern clipboard copies only after click', async () => {
  const h=makeHarness({clipboard:true});runPage(h);await submit(h);await h.copyButton.listeners.click[0]();
  assert.equal(h.copied.length,1);assert.equal(h.copied[0],h.previewText.textContent);
  assert.ok(h.copyStatus.textContent.includes(translations.ru.briefCopySuccess));
});
await check('legacy clipboard fallback and honest failure reporting', async () => {
  const h=makeHarness({clipboard:false});runPage(h);await submit(h);await h.copyButton.listeners.click[0]();
  assert.ok(h.copyStatus.textContent.includes(translations.ru.briefCopySuccess));
  const bad=makeHarness({clipboard:false,legacyCopyWorks:false});runPage(bad);await submit(bad);await bad.copyButton.listeners.click[0]();
  assert.ok(bad.copyStatus.textContent.includes(translations.ru.briefCopyFallback));assert.ok(bad.previewText.focused);
});


await check('download exports the generated brief as a local UTF-8 text file', async () => {
  const h=makeHarness();runPage(h);await submit(h);
  await h.downloadButton.listeners.click[0]();
  assert.equal(h.blobs.length,1);
  assert.equal(h.blobs[0].type,'text/plain;charset=utf-8');
  assert.ok(h.blobs[0].parts.join('').includes('Business website'));
  assert.ok(h.blobs[0].parts.join('').includes('Build a multilingual storefront'));
  const anchor=h.nodes.get('temporary-copy-a');
  assert.equal(anchor.download,'merakki-project-brief.txt');
  assert.equal(anchor.clicked,true);
  assert.equal(anchor.removed,true);
  assert.equal(h.objectUrls.length,1);
  assert.deepEqual(h.revokedUrls,[h.objectUrls[0].url]);
  assert.equal(h.copied.length,0,'download must not invoke clipboard without an explicit copy click');
});
await check('native share is explicit, localized and uses the generated brief', async () => {
  const h=makeHarness({webShare:true});runPage(h);h.buttons.enButton.listeners.click[0]();await submit(h);
  await h.shareButton.listeners.click[0]();
  assert.equal(h.shareCalls.length,1);
  assert.equal(h.shareCalls[0].title,translations.en.briefShareTitle);
  assert.ok(h.shareCalls[0].text.includes('Business website'));
  assert.ok(h.copyStatus.textContent.includes(translations.en.briefShareSuccess));
});
await check('cancelled or unavailable system share never reports an order sent', async () => {
  const cancelled=makeHarness({webShare:true,shareErrorName:'AbortError'});runPage(cancelled);await submit(cancelled);await cancelled.shareButton.listeners.click[0]();
  assert.ok(cancelled.copyStatus.textContent.includes(translations.ru.briefShareCancelled));
  const unsupported=makeHarness({webShare:false});runPage(unsupported);await submit(unsupported);await unsupported.shareButton.listeners.click[0]();
  assert.ok(unsupported.copyStatus.textContent.includes(translations.ru.briefShareUnsupported));
  assert.equal(unsupported.shareCalls.length,0);
});

await check('RU/EN/AR pages have their own canonicals and reciprocal hreflang', () => {
  const cases = [
    {locale:'ru', html, title:'MERAKKI GLOBAL — кейс OSGARD Development', url:'https://osgard.world/development/merakki/'},
    {locale:'en', html:htmlEn, title:'MERAKKI GLOBAL — OSGARD Development case', url:'https://osgard.world/development/merakki/en/'},
    {locale:'ar', html:htmlAr, title:'MERAKKI GLOBAL — دراسة حالة OSGARD Development', url:'https://osgard.world/development/merakki/ar/'}
  ];
  for (const item of cases) {
    assert.ok(item.html.includes('<title>'+item.title+'</title>'), item.locale+' title mismatch');
    assert.ok(item.html.includes('rel="canonical" href="'+item.url+'"'), item.locale+' canonical mismatch');
    for (const locale of ['ru','en','ar']) assert.ok(item.html.includes('hreflang="'+locale+'"'), item.locale+' missing hreflang '+locale);
    assert.ok(item.html.includes('id="project-brief"') && item.html.includes('id="brief-copy"') && item.html.includes('id="brief-download"') && item.html.includes('id="brief-share"'), item.locale+' lost brief controls');
    const scriptStart=item.html.indexOf('<script>');const scriptEnd=item.html.indexOf('</script>',scriptStart);const localeScript=scriptStart>=0&&scriptEnd>=0?item.html.slice(scriptStart+8,scriptEnd):'';
    assert.ok(localeScript && localeScript.includes('function downloadBriefMessage') && localeScript.includes('function shareBriefMessage'),item.locale+' is missing local export/share logic');
    const ld=item.html.match(/<script type="application\/ld\+json" id="case-structured-data">([\s\S]*?)<\/script>/);
    assert.ok(ld,item.locale+' JSON-LD missing');
    const graph=JSON.parse(ld[1])['@graph'];
    assert.ok(graph.some(node=>node['@type']==='Article' && node.inLanguage===item.locale),item.locale+' structured-data language mismatch');
  }
});
await check('Arabic case is RTL and localizes the brief before JavaScript', () => {
  assert.ok(htmlAr.includes('<html lang="ar" dir="rtl" data-case-status="demo-only">'));
  assert.ok(htmlAr.includes('واجهة متعددة اللغات'));
  assert.ok(htmlAr.includes('.brief-preview-text{text-align:right;direction:rtl}'));
});
await check('English case renders useful text without requiring JavaScript', () => {
  assert.ok(htmlEn.includes('A clear path from selection to an understandable order.'));
  assert.ok(htmlEn.includes('Open public demo'));
});
console.log('MERAKKI case smoke passed: '+checks+' assertions.');