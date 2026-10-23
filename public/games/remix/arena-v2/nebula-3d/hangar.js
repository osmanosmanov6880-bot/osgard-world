/* NEBULA secure account / checkout view: all money and inventory state is authoritative on the server. */
'use strict';
const API = '/api/core/';
const AUTH_KEY = 'nebula_core_session_v1';
const elements = Object.fromEntries([
  'mode','session-state','auth-form','username','password','login',
  'register','logout','signed-in','refresh','owned','products','status'
].map(id => [id, document.getElementById(id)]));
let token = sessionStorage.getItem(AUTH_KEY) || '';
let currentUser = null;
let inventory = { items: {}, orders: [] };
let catalog = null;
let busy = false;
let activeKey = new Map();
const money = new Intl.NumberFormat('en-GB', {style:'currency',currency:'GBP'});
const setText = (node, value) => { node.textContent = String(value); };
function message(value, error = false) {
  setText(elements.status, value);
  elements.status.classList.toggle('error', error);
}
function newElement(tag, cls = '', text = '') {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  node.textContent = text;
  return node;
}
async function request(path, {method = 'GET', body, auth = false, key} = {}) {
  const headers = {'Accept':'application/json'};
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (auth && token) headers.Authorization = 'Bearer ' + token;
  if (key) headers['Idempotency-Key'] = key;
  const resp = await fetch(API + path, {
    method, headers, cache:'no-store', credentials:'omit',
    body:body === undefined ? undefined : JSON.stringify(body)
  });
  const data = await resp.json().catch(() => ({}));
  if (!resp.ok) {
    const error = new Error(data.message || ('Сервер ответил ' + resp.status));
    error.httpStatus = resp.status;
    error.code = data.error || 'server_error';
    throw error;
  }
  return data;
}
function showAccount() {
  elements['auth-form'].hidden = !!currentUser;
  elements['signed-in'].hidden = !currentUser;
  elements.logout.hidden = !currentUser;
  setText(elements['signed-in'], currentUser
    ? ('ПИЛОТ: ' + currentUser.username.toUpperCase() + ' · ПРИВЯЗКА ПОКУПОК АКТИВНА')
    : '');
  setText(elements['session-state'], currentUser
    ? 'Подключён аккаунт · покупки закрепляются за ним'
    : 'Войди, чтобы привязать покупки к аккаунту');
  renderProducts();
}
function showOwned() {
  elements.owned.replaceChildren();
  if (!currentUser) {
    elements.owned.append(newElement('p','quiet','Авторизуйся для проверки купленных предметов.'));
    return;
  }
  const ownedList = Object.entries(inventory.items || {}).filter(([,n]) => Number(n)>0);
  if (!ownedList.length) {
    elements.owned.append(newElement('p','quiet','Пока нет подтверждённых покупок.'));
  } else {
    for (const [sku, qty] of ownedList) {
      const product = catalog?.items?.find(item => item.sku === sku);
      const row = newElement('div','owned-item');
      row.append(newElement('span','',product?.name || sku));
      row.append(newElement('strong','', 'ПОДТВЕРЖДЕНО · ×' + qty));
      elements.owned.append(row);
    }
  }
  const orders = (inventory.orders || []).slice(0, 5);
  if (orders.length) {
    const small = newElement('div','recent-orders');
    small.append(newElement('div','eyebrow','ПОСЛЕДНИЕ ЗАКАЗЫ'));
    for (const order of orders) {
      const item = catalog?.items?.find(p => p.sku===order.sku);
      small.append(newElement('p','quiet',(item?.name || order.sku) + ' · ' + order.state));
    }
    elements.owned.append(small);
  }
}
function renderProducts() {
  elements.products.replaceChildren();
  const products = catalog?.items || [];
  if (!products.length) {
    elements.products.append(newElement('p','quiet','Каталог временно недоступен.'));
    return;
  }
  for (const item of products) {
    const row = newElement('article','product');
    const caption = newElement('div','product-copy');
    caption.append(newElement('div','eyebrow',item.kind.toUpperCase()));
    caption.append(newElement('h3','',item.name));
    caption.append(newElement('p','quiet',item.repeatable
      ? 'Пополнение запаса · ' + item.quantity + ' шт.'
      : 'Постоянная лицензия для одного аккаунта'));
    row.append(caption);
    const purchase = newElement('div','product-action');
    purchase.append(newElement('strong','price',money.format(item.amountMinor/100)));
    const button = newElement('button','buy',!catalog.enabled
      ? 'КАССА НЕ АКТИВНА'
      : !currentUser
      ? 'ТРЕБУЕТСЯ ВХОД'
      : !item.repeatable && Number(inventory.items?.[item.sku] || 0) > 0
      ? 'УЖЕ КУПЛЕНО' : 'ОПЛАТИТЬ');
    button.type = 'button';
    button.disabled = !catalog.enabled || !currentUser || busy ||
      (!item.repeatable && Number(inventory.items?.[item.sku] || 0) > 0);
    button.addEventListener('click', () => buy(item));
    purchase.append(button);
    row.append(purchase);
    elements.products.append(row);
  }
}
async function authenticate(kind) {
  if (busy) return;
  const username = elements.username.value.trim().toLowerCase();
  const password = elements.password.value;
  if (!/^[a-z0-9_.-]{3,64}$/.test(username) || password.length < 12) {
    message('Логин: от 3 символов. Пароль: не менее 12 символов.', true);
    return;
  }
  busy = true;
  try {
    const result = await request('auth/' + kind, {method:'POST',body:{username,password}});
    token = result.token;
    sessionStorage.setItem(AUTH_KEY, token);
    elements.password.value = '';
    currentUser = result.user;
    await refresh();
    message('Аккаунт пилота подключён. Теперь заказы будут закрепляться за ним.');
  } catch (err) {
    message(err.message,true);
  } finally {
    busy = false;
    showAccount();
  }
}
async function checkAccount() {
  if (!token) return;
  try {
    const response = await request('auth/me',{auth:true});
    currentUser = response.user;
  } catch {
    token = '';
    sessionStorage.removeItem(AUTH_KEY);
    currentUser = null;
    inventory = {items:{},orders:[]};
  }
}
async function refresh() {
  await checkAccount();
  if (currentUser) {
    inventory = await request('nebula/inventory',{auth:true});
  } else inventory={items:{},orders:[]};
  showAccount();
  showOwned();
}
async function buy(item) {
  if (busy || !currentUser || !catalog?.enabled) return;
  const key = activeKey.get(item.sku) || (crypto.randomUUID().replaceAll('-', '') + 'n');
  activeKey.set(item.sku,key);
  busy = true;
  renderProducts();
  try {
    const result = await request('nebula/checkout',{
      method:'POST', auth:true, key, body:{sku:item.sku}
    });
    if (result.url) {
      const location = new URL(result.url);
      if (location.protocol !== 'https:' || location.hostname !== 'checkout.stripe.com') {
        throw new Error('Недостоверный URL оплаты — переход заблокирован.');
      }
      message('Переходим на защищённую платёжную страницу Stripe…');
      window.location.assign(location.href);
    } else {
      message('Состояние заказа: ' + result.state +
              '. Проверь покупки через «Обновить».');
      activeKey.delete(item.sku);
    }
  } catch (err) {
    // Preserve idempotency on ambiguous network errors; never charge twice by accident.
    if (err.code !== 'nebula_checkout_unknown' && err.code !== 'nebula_checkout_busy') {
      activeKey.delete(item.sku);
    }
    message(err.message, true);
  } finally {
    busy=false;
    renderProducts();
  }
}
elements['auth-form'].addEventListener('submit',event=>{
  event.preventDefault(); authenticate('login');
});
elements.register.addEventListener('click',()=>authenticate('register'));
elements.logout.addEventListener('click',()=>{
  token='';sessionStorage.removeItem(AUTH_KEY);currentUser=null;
  inventory={items:{},orders:[]};
  showAccount();showOwned();message('Вы вышли из аккаунта.');
});
elements.refresh.addEventListener('click',()=>{
  refresh().then(()=>message('Права владения обновлены по данным сервера.'))
           .catch(error=>message(error.message,true));
});
(async function boot() {
  try {
    catalog = await request('nebula/catalog');
    elements.mode.className = 'pill ' + (catalog.enabled
      ? (catalog.mode === 'live' ? 'active' : 'testing') : 'inactive');
    setText(elements.mode, catalog.enabled
      ? (catalog.mode==='live' ? 'STRIPE LIVE' : 'STRIPE TEST')
      : 'ОПЛАТА ЕЩЁ НЕ АКТИВИРОВАНА');
    await refresh();
    const returned = new URLSearchParams(location.search).get('checkout');
    if (returned === 'returned') {
      message('Возврат из Stripe. Проверяем подтверждение на сервере. ' +
              'Если платёж обрабатывается, обнови статус позднее.');
    } else if (returned === 'cancelled') {
      message('Покупка отменена — никаких предметов не начислено.');
    } else message(catalog.enabled
      ? 'Касса готова. После оплаты предмет появится в аккаунте только по подтверждению Stripe.'
      : 'Касса ещё не подключена к проверенному аккаунту MAGA. Реальные списания выключены.');
  } catch (error) {
    message('Не удалось подключить магазин: ' + error.message,true);
  }
})();
