(() => {
const products=[
{id:1,name:'Ваза Sora',category:'Дом',price:3900,oldPrice:null,tag:'Бестселлер',desc:'Матовая керамика · 24 см',img:'https://images.unsplash.com/photo-1578500494198-246f612d3b3d?auto=format&fit=crop&w=750&q=82'},
{id:2,name:'Лампа Forma',category:'Свет',price:12900,oldPrice:null,tag:'Новая коллекция',desc:'Металл и мягкий направленный свет',img:'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=750&q=82'},
{id:3,name:'Поднос Alba',category:'Дом',price:4600,oldPrice:5200,tag:'−12%',desc:'Натуральный камень · ручная отделка',img:'https://images.unsplash.com/photo-1603199506016-b9a594b593c0?auto=format&fit=crop&w=750&q=82'},
{id:4,name:'Свеча No. 04',category:'Ритуалы',price:2400,oldPrice:null,tag:'Малый тираж',desc:'Кедр, инжир и тёплый мускус',img:'https://images.unsplash.com/photo-1603006905003-be475563bc59?auto=format&fit=crop&w=750&q=82'},
{id:5,name:'Чашка Noma',category:'Ритуалы',price:1800,oldPrice:null,tag:'Ручная работа',desc:'Каменная керамика · 280 мл',img:'https://images.unsplash.com/photo-1514228742587-6b1558fcca3d?auto=format&fit=crop&w=750&q=82'},
{id:6,name:'Плед Linen',category:'Дом',price:7900,oldPrice:null,tag:'Натуральный состав',desc:'Лён и хлопок · спокойная фактура',img:'https://images.unsplash.com/photo-1600210491369-e753d80a41f3?auto=format&fit=crop&w=750&q=82'},
{id:7,name:'Светильник Moon',category:'Свет',price:15800,oldPrice:null,tag:'Выбор редакции',desc:'Рассеянный свет · тонкий силуэт',img:'https://images.unsplash.com/photo-1507473885765-e6ed057f782c?auto=format&fit=crop&w=750&q=82'},
{id:8,name:'Диффузор Still',category:'Ритуалы',price:3200,oldPrice:null,tag:'Для дома',desc:'Белый чай, шалфей и древесные ноты',img:'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?auto=format&fit=crop&w=750&q=82'}
];
const $=id=>document.getElementById(id);
const currency=n=>new Intl.NumberFormat('ru-RU',{style:'currency',currency:'RUB',maximumFractionDigits:0}).format(n);
const safeParse=(key,fallback)=>{try{return JSON.parse(localStorage.getItem(key)||'null')??fallback}catch{return fallback}};
let cart=safeParse('essentia-demo-cart-v1',{});if(!cart||typeof cart!=='object'||Array.isArray(cart))cart={};
Object.keys(cart).forEach(k=>{if(!products.some(p=>p.id===Number(k))||!Number.isInteger(cart[k])||cart[k]<1)delete cart[k]});
let favorites=new Set(safeParse('essentia-demo-favorites-v1',[]).filter(id=>products.some(p=>p.id===id)));
let category='Все',favoritesOnly=false,discountRate=0,toastTimer;
const persist=()=>{try{localStorage.setItem('essentia-demo-cart-v1',JSON.stringify(cart));localStorage.setItem('essentia-demo-favorites-v1',JSON.stringify([...favorites]))}catch{}};
const count=()=>Object.values(cart).reduce((a,b)=>a+b,0);
const subtotal=()=>products.reduce((sum,p)=>sum+p.price*(cart[p.id]||0),0);
const discount=()=>Math.round(subtotal()*discountRate);
const shipping=()=>subtotal()===0||subtotal()>=8000||$('deliveryChoice')?.value==='pickup'?0:590;
const total=()=>Math.max(0,subtotal()-discount())+shipping();
const toast=message=>{const el=$('toast');el.textContent=message;el.classList.add('is-visible');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('is-visible'),2100)};
function renderProducts(){
 const query=$('productSearch').value.trim().toLocaleLowerCase('ru');
 const sort=$('sortProducts').value;
 let list=products.filter(p=>(category==='Все'||p.category===category)&&(!favoritesOnly||favorites.has(p.id))&&(!query||[p.name,p.category,p.desc].join(' ').toLocaleLowerCase('ru').includes(query)));
 if(sort==='price-asc')list.sort((a,b)=>a.price-b.price);if(sort==='price-desc')list.sort((a,b)=>b.price-a.price);
 $('productGrid').innerHTML=list.length?list.map(p=>'<article class="product-card"><div class="product-image"><img loading="lazy" src="'+p.img+'" alt="'+p.name.replace(/"/g,'&quot;')+'" onerror="this.style.opacity=0"><span class="product-tag">'+p.tag+'</span><button class="favorite-button '+(favorites.has(p.id)?'is-favorite':'')+'" data-favorite="'+p.id+'" aria-label="'+(favorites.has(p.id)?'Убрать из избранного':'В избранное')+'">'+(favorites.has(p.id)?'♥':'♡')+'</button><button class="add-button" data-add="'+p.id+'"><span>Добавить в корзину</span><b>＋</b></button></div><div class="product-meta"><span class="product-category">'+p.category+'</span><h3 class="product-name">'+p.name+'</h3><p class="product-desc">'+p.desc+'</p><div class="product-price-row"><span class="product-price">'+currency(p.price)+'</span>'+(p.oldPrice?'<span class="product-old-price">'+currency(p.oldPrice)+'</span>':'')+'</div></div></article>').join(''):'<div class="empty-results"><p>Ничего не найдено.</p><button class="outline-button" id="resetFilters">Сбросить фильтры ↗</button></div>';
 const reset=$('resetFilters');if(reset)reset.addEventListener('click',()=>{$('productSearch').value='';category='Все';favoritesOnly=false;updateChips();renderProducts()});
 $('favoriteCount').textContent=favorites.size;
}
function updateChips(){document.querySelectorAll('[data-category]').forEach(b=>b.classList.toggle('is-active',b.dataset.category===category));$('favoritesToggle').classList.toggle('is-favorite',favoritesOnly);$('favoritesToggle').setAttribute('aria-pressed',String(favoritesOnly))}
function renderCart(){
 $('cartCount').textContent=count();$('drawerCount').textContent='('+count()+')';
 $('cartItems').innerHTML=products.filter(p=>cart[p.id]).map(p=>'<div class="cart-row"><img src="'+p.img+'" alt="" onerror="this.style.opacity=0"><div><h3>'+p.name+'</h3><p>'+currency(p.price)+' за предмет</p><div class="qty-control"><button data-qty="'+p.id+'" data-delta="-1" aria-label="Уменьшить количество">−</button><span>'+cart[p.id]+'</span><button data-qty="'+p.id+'" data-delta="1" aria-label="Увеличить количество">＋</button></div></div><div class="cart-line-price">'+currency(p.price*cart[p.id])+'<button class="remove-item" data-remove="'+p.id+'">Удалить</button></div></div>').join('');
 const empty=count()===0;$('emptyCart').hidden=!empty;$('cartBottom').hidden=empty;
 const sub=subtotal(),remain=Math.max(0,8000-sub);$('shippingMessage').textContent=sub>=8000?'Бесплатная доставка доступна':'До бесплатной доставки';$('shippingRemaining').textContent=sub>=8000?'Включена':currency(remain);$('shippingProgress').style.width=Math.min(100,sub/8000*100)+'%';
 $('subtotal').textContent=currency(sub);$('discount').textContent=discount()?('−'+currency(discount())):currency(0);$('shippingCost').textContent=shipping()===0?'Бесплатно':currency(shipping());$('grandTotal').textContent=currency(total());$('checkoutOpen').disabled=empty;
 $('checkoutTotal').textContent=currency(total());persist();
}
function openCart(){$('drawerBackdrop').hidden=false;$('cartDrawer').classList.add('is-open');$('cartDrawer').setAttribute('aria-hidden','false');document.body.classList.add('modal-open');$('cartClose').focus()}
function closeCart(){$('cartDrawer').classList.remove('is-open');$('cartDrawer').setAttribute('aria-hidden','true');$('drawerBackdrop').hidden=true;document.body.classList.remove('modal-open')}
function openCheckout(){if(count()===0)return;closeCart();$('checkoutBackdrop').hidden=false;$('orderSuccess').hidden=true;$('checkoutForm').hidden=false;$('checkoutTotal').textContent=currency(total());document.body.classList.add('modal-open');$('checkoutForm').querySelector('input').focus()}
function closeCheckout(){$('checkoutBackdrop').hidden=true;document.body.classList.remove('modal-open')}
document.addEventListener('click',e=>{
 const add=e.target.closest('[data-add]');if(add){const id=Number(add.dataset.add);cart[id]=(cart[id]||0)+1;renderCart();toast('Добавлено в вашу коллекцию');return}
 const fav=e.target.closest('[data-favorite]');if(fav){const id=Number(fav.dataset.favorite);favorites.has(id)?favorites.delete(id):favorites.add(id);updateChips();renderProducts();persist();return}
 const qty=e.target.closest('[data-qty]');if(qty){const id=Number(qty.dataset.qty);cart[id]=Math.max(0,(cart[id]||0)+Number(qty.dataset.delta));if(!cart[id])delete cart[id];renderCart();return}
 const remove=e.target.closest('[data-remove]');if(remove){delete cart[Number(remove.dataset.remove)];renderCart();return}
 const chip=e.target.closest('[data-category]');if(chip){category=chip.dataset.category;favoritesOnly=false;updateChips();renderProducts()}
});
$('productSearch').addEventListener('input',renderProducts);$('sortProducts').addEventListener('change',renderProducts);
$('favoritesToggle').addEventListener('click',()=>{favoritesOnly=!favoritesOnly;category='Все';updateChips();renderProducts();$('catalog').scrollIntoView({behavior:'smooth'})});
$('cartOpen').addEventListener('click',openCart);$('cartClose').addEventListener('click',closeCart);$('drawerBackdrop').addEventListener('click',closeCart);
$('continueShopping').addEventListener('click',closeCart);$('checkoutOpen').addEventListener('click',openCheckout);
$('checkoutClose').addEventListener('click',closeCheckout);$('checkoutBackdrop').addEventListener('click',e=>{if(e.target===$('checkoutBackdrop'))closeCheckout()});
$('applyPromo').addEventListener('click',()=>{const code=$('promoCode').value.trim().toUpperCase();discountRate=code==='ESSENTIA10'?.10:0;$('promoFeedback').textContent=discountRate?'Код принят: скидка 10%':'Код не найден. Для демо используйте ESSENTIA10.';$('promoFeedback').style.color=discountRate?'var(--gold)':'#a66d56';renderCart()});
$('deliveryChoice').addEventListener('change',()=>{$('addressLabel').hidden=$('deliveryChoice').value==='pickup';$('checkoutTotal').textContent=currency(total());renderCart()});
$('checkoutForm').addEventListener('submit',e=>{e.preventDefault();$('checkoutError').textContent='';if(!$('checkoutForm').reportValidity())return;if($('deliveryChoice').value==='courier'&&!$('checkoutForm').elements.address.value.trim()){$('checkoutError').textContent='Укажите демонстрационный адрес доставки.';return}
$('checkoutForm').hidden=true;$('orderSuccess').hidden=false;$('successText').textContent='Демонстрационный итог: '+currency(total())+'. Данные не отправлены и не сохранены; оплата не выполнялась.';});
$('finishDemo').addEventListener('click',()=>{closeCheckout();toast('Демо-сценарий завершён');});
document.addEventListener('keydown',e=>{if(e.key==='Escape'){closeCart();closeCheckout()}});
renderProducts();updateChips();renderCart();
})();