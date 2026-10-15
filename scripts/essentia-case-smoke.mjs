import assert from 'node:assert/strict'
import { readFileSync, existsSync } from 'node:fs'
const read = p => { assert.ok(existsSync(p), 'Missing ESSENTIA asset: '+p); return readFileSync(p,'utf8') }
const html=read('public/development/essentia/index.html')
const css=read('public/development/essentia/store.css')
const js=read('public/development/essentia/store.js')
const og=read('public/development/essentia/og.svg')
for(const marker of ['<title>ESSENTIA — премиальный e-commerce концепт | OSGARD Development</title>','rel="canonical" href="https://osgard.world/development/essentia/"','data-case-status="demo-only"','id="productGrid"','id="cartDrawer"','id="checkoutForm"','id="promoCode"','href="/development/"','/development/essentia/store.css','/development/essentia/store.js']) assert.ok(html.includes(marker),'ESSENTIA HTML marker missing: '+marker)
for(const marker of ['@media(max-width:640px)','.product-grid','.cart-drawer','.checkout-modal','prefers-reduced-motion']) assert.ok(css.includes(marker),'ESSENTIA CSS marker missing: '+marker)
for(const marker of ['ESSENTIA10','essentia-demo-cart-v1','essentia-demo-favorites-v1','data-add','data-favorite','data-qty','checkoutForm','не отправлены']) assert.ok(js.includes(marker),'ESSENTIA JS marker missing: '+marker)
assert.ok(!/fetch\s*\(|https?:\/\/[^'"]+\/api\//i.test(js),'Demo frontend must not submit data to a server.')
assert.ok(og.includes('<svg')&&og.includes('width="1200" height="630"')&&og.includes('ESSENTIA'),'ESSENTIA social card invalid')
assert.ok(!/<form[^>]+action=/i.test(html),'Checkout must remain a local demo form.')
console.log('PASS ESSENTIA: metadata, responsive styles, catalogue/cart/wishlist/promo/demo checkout, no live order submission.')
