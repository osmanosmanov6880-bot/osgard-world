import {test,expect} from '@playwright/test';

const url='http://127.0.0.1:8173/osa-cinema-studio/';

test('desktop V53 preproduction workflow is interactive and persistent',async({page})=>{
  await page.goto(url,{waitUntil:'domcontentloaded'});
  await expect(page.locator('.metric')).toHaveCount(4);
  await expect(page.locator('.metric').nth(0)).toContainText('13');
  await expect(page.locator('.metric').nth(1)).toContainText('78');
  await page.locator('[data-nav="shots"]').first().click();
  await expect(page.locator('.data-table tbody tr')).toHaveCount(78);
  await page.locator('[data-shot="S01-P01"]').first().click();
  await page.locator('#shotForm input[name="owner"]').fill('CI Director');
  await page.locator('#shotForm select[name="status"]').selectOption('ready');
  await page.locator('#shotForm button[type="submit"]').click();
  await expect(page.locator('.data-table tbody tr').first()).toContainText('CI Director');
  await page.reload();
  await page.locator('[data-nav="shots"]').first().click();
  await expect(page.locator('.data-table tbody tr').first()).toContainText('CI Director');
  await page.locator('[data-nav="timeline"]').first().click();
  await expect(page.locator('.timeline-track button')).toHaveCount(13);
  await page.locator('[data-nav="budget"]').first().click();
  await expect(page.locator('#budgetBig')).toContainText('49');
  await page.locator('#languageEn').click();
  await expect(page.locator('#topTitle')).toContainText('Budget');
  await page.screenshot({path:'test-results/osa-studio-v53-desktop.png',fullPage:true});
});

test.use({viewport:{width:390,height:844}});

test('mobile at 390px, images and review all work without overflow',async({page})=>{
  await page.goto(url,{waitUntil:'domcontentloaded'});
  await expect(page.locator('.metric')).toHaveCount(4);
  const tooWide=await page.evaluate(()=>document.documentElement.scrollWidth>window.innerWidth+1);
  expect(tooWide).toBe(false);
  await page.locator('[data-nav="library"]').first().click();
  await expect(page.locator('.ref-card')).toHaveCount(13);
  const loaded=await page.locator('.ref-card img').evaluateAll(images=>images.filter(i=>i.complete&&i.naturalWidth>0).length);
  expect(loaded).toBe(13);
  await page.locator('[data-nav="reviews"]').first().click();
  await page.locator('[data-act="new-review"]').click();
  await page.locator('#reviewForm textarea[name="text"]').fill('Check final 99.6% continuity');
  await page.locator('#reviewForm button[type="submit"]').click();
  await expect(page.locator('.review-item')).toHaveCount(1);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth+1)).toBe(true);
  await page.screenshot({path:'test-results/osa-studio-v53-mobile.png',fullPage:true});
});

test('missing narrative MP4 never masquerades as a published playable film',async({request})=>{
  const r=await request.get(url+'media-not-uploaded/zero-window-concept-ru.mp4');
  expect(r.status()).toBe(404);
  expect(r.headers()['content-type']||'').not.toContain('video/mp4');
});
