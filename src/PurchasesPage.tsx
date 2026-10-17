import { useEffect, useRef, useState } from 'react';
import { coreLoginLink } from './accountAccess';
import { CoreError, coreRequest, formatMoney, setCoreToken } from './coreClient';
import type { CoreUser } from './coreClient';
import { commerceMutation, commerceStatus } from './commerceClient';
import type { CommerceConfiguration, CommerceOrder } from './commerceClient';
import './coreWorkspace.css';

export default function PurchasesPage() {
  const [user, setUser] = useState<CoreUser | null>(null), [config, setConfig] = useState<CommerceConfiguration | null>(null);
  const [orders, setOrders] = useState<CommerceOrder[]>([]), [phase, setPhase] = useState<'loading' | 'ready' | 'login' | 'error'>('loading');
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [message, setMessage] = useState('');
  const lock = useRef(false), alert = useRef<HTMLParagraphElement>(null), sequence = useRef(0);
  const returned = new URLSearchParams(location.search).get('checkout');
  function failure(error: unknown) {
    if (error instanceof CoreError && error.status === 401) {
      setCoreToken(''); setUser(null); setOrders([]); setConfig(null); setPhase('login');
    } else { setError(error instanceof Error ? error.message : 'Не удалось загрузить покупки.'); setPhase('error'); }
  }
  async function load() {
    const stamp = ++sequence.current;
    const [account, purchases] = await Promise.all([
      coreRequest<{ user: CoreUser }>('auth/me'),
      coreRequest<{ orders: CommerceOrder[]; configuration: CommerceConfiguration }>('commerce/purchases'),
    ]);
    if (stamp !== sequence.current) return;
    setUser(account.user); setOrders(purchases.orders); setConfig(purchases.configuration); setPhase('ready');
  }
  useEffect(() => {
    let active = true; void load().catch(e => { if (active) failure(e); });
    const resume = (event: PageTransitionEvent) => { if (event.persisted) location.reload(); };
    window.addEventListener('pageshow', resume);
    return () => { active = false; sequence.current++; window.removeEventListener('pageshow', resume); };
  }, []);
  useEffect(() => { if (error) alert.current?.focus(); }, [error]);
  async function run(work: () => Promise<void>) {
    if (lock.current) return;
    lock.current = true; setBusy(true); setError(''); setMessage('');
    try { await work(); } catch (e) { failure(e); } finally { lock.current = false; setBusy(false); }
  }
  async function checkout(order: CommerceOrder) {
    const result = await commerceMutation<{ url: string | null; pending?: boolean; closed?: boolean; status?: string }>('commerce/orders/' + order.id + '/checkout');
    if (!result.url) {
      await load(); setMessage(result.closed ? 'Оплата уже завершена или закрыта. Проверьте статус заказа.' : 'Оплата обрабатывается. Дождитесь подтверждения и обновите покупки.'); return;
    }
    const url = new URL(result.url);
    if (url.origin !== 'https://checkout.stripe.com') throw new Error('Сервер не вернул допустимую страницу Stripe. Обновите покупки.');
    location.assign(url.href);
  }
  async function download(order: CommerceOrder) {
    const file = await coreRequest<{ orderId: string; html: string; sha256: string }>('commerce/purchases/' + order.id + '/file');
    const url = URL.createObjectURL(new Blob([file.html], { type: 'text/html;charset=utf-8' }));
    const link = document.createElement('a'); link.href = url; link.download = 'osgard-purchase-' + file.orderId + '.html'; link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    setMessage('Файл передан браузеру для скачивания. Сервер проверил его SHA-256: ' + file.sha256);
  }
  return <main className="brand-container core-workspace">
    <section className="core-intro"><p className="brand-eyebrow">OSGARD BUSINESS / МОИ ПОКУПКИ</p><h1>Ваш результат.<br /><em>Ваш доступ.</em></h1>
      <p className="brand-lead">Здесь находятся заказы, подготовленные для вашего аккаунта, подтверждённые оплаты и сохранённые файлы.</p>
      <p><a href="/workspace?tab=business">Рабочее пространство</a> · <a href="/account">Аккаунт</a></p>
    </section>
    <p ref={alert} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p>
    <p role="status" className="core-status">{busy || phase === 'loading' ? 'Проверяем заказы…' : message}</p>
    {returned === 'returned' && <p className="core-alert">Вы вернулись со страницы оплаты. Возврат на сайт не подтверждает платёж. Доступ откроется только после подтверждения Stripe; при необходимости обновите покупки.</p>}
    {returned === 'cancelled' && <p className="core-alert">Оплата была закрыта в браузере. Это не отменяет заказ и не подтверждает списание. Актуальный статус указан ниже.</p>}
    {phase === 'login' ? <section className="core-panel"><h2>Войдите в аккаунт покупателя</h2><p>Заказ и файл доступны только тому аккаунту, для которого оператор подготовил предложение.</p><a className="brand-button primary" href={coreLoginLink('/purchases')}>Войти и открыть покупки</a></section> : <button className="brand-button" disabled={busy || phase === 'loading'} onClick={() => void run(load)}>Обновить покупки</button>}
    {user && config && <>
      <p><strong>{user.username}</strong> · {config.mode === 'test' ? 'Тестовый режим — реальные платежи здесь не подтверждаются.' : 'Режим реальных платежей.'}</p>
      {!config.enabled && <p className="core-alert">Приём новых платежей выключен. Ранее выданный доступ сохраняется, если платёж не возвращён полностью.</p>}
      {phase === 'ready' && !orders.length && <section className="core-panel"><h2>Покупок пока нет</h2><p>Когда оператор подготовит заказ на ваш логин, он появится здесь. Список обновляется кнопкой выше.</p></section>}
      {orders.map(order => <article key={order.id} className="core-panel">
        <p className="brand-eyebrow">ЗАКАЗ {order.id.slice(0, 8)} · {commerceStatus[order.status] || order.status}</p>
        <h2>{order.title}</h2><p>{order.scope}</p><p><strong>{formatMoney(order.amountMinor, order.currency)}</strong> · {order.kind === 'learning_program' ? 'Разовая версия программы и личная практика' : 'Разовая покупка сохранённого HTML'}</p>
        <p>Подтверждено оплатой: {formatMoney(order.paidMinor, order.currency)}. Возвращено: {formatMoney(order.refundedMinor, order.currency)}.</p>
        {['prepared', 'checkout_pending', 'checkout_open'].includes(order.status) && <><button className="brand-button primary" disabled={busy || !config.enabled} onClick={() => void run(() => checkout(order))}>{order.checkoutState === 'unknown' ? 'Продолжить тот же запрос оплаты' : 'Оплатить ' + formatMoney(order.amountMinor, order.currency) + ' через Stripe'}</button><p>Данные карты вводятся на странице Stripe. После оплаты доступ появится здесь, когда сервер получит подтверждение.</p></>}
        {order.status === 'payment_processing' && <p>Ожидаем подтверждения платёжной системы. Повторно платить не нужно. Обновите покупки через некоторое время.</p>}
        {order.kind === 'learning_program' ? <><a className="brand-button primary" href={'/learning/enrollment?order=' + order.id}>{order.status === 'refunded' ? 'Открыть статус и экспорт своих работ' : order.accessGranted ? 'Открыть личную программу' : 'Проверить доступ к программе'}</a><p>Версия {order.program?.version.slice(0, 12)}. Практика становится доступна после оплаты и вашего согласия. Наставник не включён; бесплатные лекции открыты.</p></> : order.accessGranted && <><button className="brand-button primary" disabled={busy} onClick={() => void run(() => download(order))}>Скачать оплаченный HTML</button><p>Это сохранённая версия на момент заказа. Обновления проекта не подменяют купленный файл.</p></>}
        {order.status === 'refunded' && <p>{order.kind === 'learning_program' ? 'Полный возврат подтверждён. Платная практика закрыта; собственные работы сохранены для экспорта.' : 'Полный возврат подтверждён. Доступ к новому скачиванию отозван.'}</p>}
        {['expired', 'failed', 'cancelled'].includes(order.status) && <p>Этот заказ закрыт для новой оплаты. Для продолжения обратитесь к оператору, который подготовил предложение.</p>}
        <p><small>Обновлено {new Date(order.updatedAt).toLocaleString('ru-RU')}</small></p>
      </article>)}
    </>}
  </main>;
}
