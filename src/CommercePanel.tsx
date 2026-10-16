import { useEffect, useRef, useState } from 'react';
import { coreRequest, formatMoney, minorUnits } from './coreClient';
import type { CoreProject } from './coreClient';
import { commerceMutation, commerceStatus } from './commerceClient';
import type { CommerceConfiguration, CommerceOrder } from './commerceClient';

type Release = { id: string; sourceVersion: number | null; latestReview: { verdict: string } | null };
type Props = {
  project: CoreProject; disabled: boolean; onDirty: (dirty: boolean) => void;
  onPrepare: (body: Record<string, unknown>) => Promise<unknown>;
};

export default function CommercePanel({ project, disabled, onDirty, onPrepare }: Props) {
  const [config, setConfig] = useState<CommerceConfiguration | null>(null);
  const [orders, setOrders] = useState<CommerceOrder[]>([]), [releases, setReleases] = useState<Release[]>([]);
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false);
  const [error, setError] = useState(''), [message, setMessage] = useState('');
  const [draftId, setDraftId] = useState(''), [releaseId, setReleaseId] = useState(''), [buyer, setBuyer] = useState('');
  const [confirmed, setConfirmed] = useState(false), [refunds, setRefunds] = useState<Record<string, string>>({});
  const lock = useRef(false), sequence = useRef(0), alert = useRef<HTMLParagraphElement>(null);
  const changed = Boolean(draftId || releaseId || buyer || confirmed || Object.values(refunds).some(Boolean));
  useEffect(() => { onDirty(changed); return () => onDirty(false); }, [changed, onDirty]);
  useEffect(() => { if (error) alert.current?.focus(); }, [error]);
  async function load() {
    const stamp = ++sequence.current;
    const configuration = await coreRequest<CommerceConfiguration>('commerce/config');
    if (stamp !== sequence.current) return;
    setConfig(configuration);
    if (configuration.canManage && project.role === 'owner') {
      const [commerce, material] = await Promise.all([
        coreRequest<{ orders: CommerceOrder[] }>('projects/' + project.id + '/commerce'),
        coreRequest<{ releases: Release[] }>('projects/' + project.id + '/releases'),
      ]);
      if (stamp !== sequence.current) return;
      setOrders(commerce.orders); setReleases(material.releases);
    } else { setOrders([]); setReleases([]); }
  }
  useEffect(() => {
    let current = true; setLoading(true);
    void load().catch(e => { if (current) setError(e.message); }).finally(() => { if (current) setLoading(false); });
    return () => { current = false; sequence.current++; };
  }, [project.id, project.version]);
  async function run(work: () => Promise<void>) {
    if (lock.current) return;
    lock.current = true; setBusy(true); setError(''); setMessage('');
    try { await work(); }
    catch (e) { setError(e instanceof Error ? e.message : 'Не удалось выполнить запрос.'); }
    finally { lock.current = false; setBusy(false); }
  }
  const usable = project.data.orders.filter(o => o.status === 'draft' && !orders.some(order => order.sourceOrderId === o.id));
  const chosen = usable.find(o => o.id === draftId);
  const accepted = releases.filter(r => r.sourceVersion && r.latestReview?.verdict === 'accepted');
  const blocked = disabled || busy || loading || !config?.enabled;
  return <section className="core-panel" aria-label="Коммерческие заказы">
    <p className="brand-eyebrow">BUSINESS / ОПЛАТА И ДОСТУП</p><h2>Проверенный файл — конкретному покупателю</h2>
    <p>Разовая покупка сохранённого HTML через Stripe. Покупатель получает именно выбранный выпуск после подтверждения оплаты. Учебные подписки и размещение сайта в это предложение не входят.</p>
    <p><a href="/purchases">Открыть мои покупки →</a></p>
    <p ref={alert} tabIndex={-1} role={error ? 'alert' : undefined} hidden={!error} className="core-alert">{error}</p>
    <p role="status">{loading ? 'Загружаем настройки и заказы…' : busy ? 'Сохраняем запрос…' : message}</p>
    {config && <p className={!config.enabled ? 'core-alert' : 'core-source'}>{!config.enabled
      ? 'Новые оплаты выключены. Торговый аккаунт и условия приёма платежей ещё должны быть настроены оператором. Ранее выданный доступ проверяется отдельно в покупках.'
      : config.mode === 'test' ? 'Тестовый режим. Суммы ниже относятся к проверке интеграции и не являются выручкой.'
        : 'Включён приём реальных платежей. Проверьте покупателя, сумму и состав файла перед созданием заказа.'}</p>}
    <button className="brand-button" disabled={busy || disabled} onClick={() => void run(load)}>Обновить заказы</button>
    {config && (!config.canManage || project.role !== 'owner') && <p>Заказы готовит настроенный оператор — владелец проекта. Ваша страница покупок доступна по ссылке выше.</p>}
    {config?.canManage && project.role === 'owner' && <>
      <form onSubmit={e => { e.preventDefault(); void run(async () => {
        if (!chosen || !confirmed) throw new Error('Выберите черновик и подтвердите условия.');
        await onPrepare({ expectedVersion: project.version, draftOrderId: chosen.id, releaseId,
          buyerUsername: buyer, confirmedAmountMinor: chosen.amountMinor, confirmedCurrency: chosen.currency, sharingAcknowledged: true });
        setDraftId(''); setReleaseId(''); setBuyer(''); setConfirmed(false); onDirty(false);
      }); }}>
        <fieldset disabled={blocked} className="core-editor"><legend>Подготовить заказ покупателю</legend>
          <label className="core-field"><span>Сохранённое предложение</span><select required value={draftId} onChange={e => { setDraftId(e.target.value); setConfirmed(false); }}>
            <option value="">Выберите черновик</option>{usable.map(o => <option key={o.id} value={o.id}>{o.title} · {formatMoney(o.amountMinor, o.currency)}</option>)}
          </select></label>
          {!usable.length && <p>Сначала сохраните предложение и создайте черновик заказа выше.</p>}
          <label className="core-field"><span>Выпуск, принятый другим участником</span><select required value={releaseId} onChange={e => { setReleaseId(e.target.value); setConfirmed(false); }}>
            <option value="">Выберите выпуск</option>{accepted.map(r => <option key={r.id} value={r.id}>{r.id.slice(0, 8)} · исходная версия {r.sourceVersion}</option>)}
          </select></label>
          {!accepted.length && <p>Нужен сохранённый HTML и положительный разбор выпуска на вкладке «Приёмка».</p>}
          <label className="core-field"><span>Логин существующего аккаунта покупателя</span><input required autoComplete="off" minLength={3} maxLength={64} value={buyer} onChange={e => { setBuyer(e.target.value); setConfirmed(false); }} /></label>
          {chosen && <div className="core-source"><strong>{chosen.title} · {formatMoney(chosen.amountMinor, chosen.currency)}</strong><p>{chosen.scope}</p>
            {!['USD', 'EUR'].includes(chosen.currency) && <p className="core-alert">Приём RUB в этом модуле не подключён. Поддерживаются USD и EUR.</p>}</div>}
          <label className="core-check"><input required type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} />Подтверждаю сумму, валюту и получателя; разрешаю передать HTML выбранного выпуска. Я проверил содержимое файла.</label>
          <button className="brand-button primary" disabled={!chosen || !releaseId || !confirmed || !['USD', 'EUR'].includes(chosen.currency)}>Подготовить заказ на указанную сумму</button>
          <p>Создание заказа не списывает деньги. Покупатель запускает оплату сам на странице «Мои покупки».</p>
        </fieldset>
      </form>
      <h3>Платежи по этому проекту</h3>
      {!loading && !orders.length && <p>Коммерческих заказов пока нет.</p>}
      {orders.length > 0 && <><dl className="core-economics">{['USD', 'EUR'].filter(currency => orders.some(o => o.currency === currency)).map(currency => {
        const list = orders.filter(o => o.currency === currency), received = list.reduce((sum, o) => sum + o.paidMinor, 0), returned = list.reduce((sum, o) => sum + o.refundedMinor, 0);
        const costs = project.data.currency === currency ? project.economics.costMinor : null;
        return <div key={currency}><dt>{config.mode === 'test' ? 'Тестовые суммы' : 'Подтверждено оплатами'} / {currency}</dt><dd>{formatMoney(received, currency)}</dd><dt>После подтверждённых возвратов</dt><dd>{formatMoney(received - returned, currency)}</dd>{costs !== null && <><dt>После возвратов и введённых расходов</dt><dd>{formatMoney(received - returned - costs, currency)}</dd></>}</div>;
      })}</dl><p>Последний расчёт учитывает только расходы, внесённые в журнал проекта в той же валюте. Комиссии Stripe автоматически не импортируются. Заполните вычисления, платёжные расходы, наставников и поддержку перед оценкой экономики.</p></>}
      {orders.map(order => {
        const unresolved = Boolean(order.refundState && order.refundState !== 'confirmed');
        const targetText = unresolved && order.refundTargetMinor ? String(order.refundTargetMinor / 100) : refunds[order.id] || '';
        return <article className="core-order" key={order.id}><h4>{order.title}</h4><p>{order.buyer} · {formatMoney(order.amountMinor, order.currency)} · {commerceStatus[order.status] || order.status}</p>
          <p>Оплачено: {formatMoney(order.paidMinor, order.currency)}. Возвращено: {formatMoney(order.refundedMinor, order.currency)}. Доступ: {order.accessGranted ? 'выдан' : 'не выдан или отозван'}.</p>
          {unresolved && <p className="core-alert">{order.refundState === 'failed' ? 'Возврат не выполнен. Оператору нужна сверка со Stripe перед новой операцией.' : order.refundState === 'unknown' ? 'Ответ о возврате потерян. Повтор отправляет прежнюю сумму с тем же серверным ключом.' : 'Возврат отправлен; ожидаем подтверждение. Обновите заказы.'}</p>}
          {order.paidMinor === order.amountMinor && order.refundedMinor < order.amountMinor && <form onSubmit={e => { e.preventDefault(); void run(async () => {
            const target = minorUnits(targetText);
            if (target <= order.refundedMinor || target > order.amountMinor) throw new Error('Укажите сумму больше уже возвращённой и не больше цены заказа.');
            if (!confirm('Вернуть покупателю ' + formatMoney(target - order.refundedMinor, order.currency) + '? Общая сумма возврата достигнет ' + formatMoney(target, order.currency) + '.')) return;
            const result = await commerceMutation<{ failed?: boolean; confirmed?: boolean }>('commerce/orders/' + order.id + '/refund', { targetRefundMinor: target });
            await load(); setRefunds(v => ({ ...v, [order.id]: '' }));
            setMessage(result.failed ? 'Возврат не выполнен. Нужна сверка со Stripe.' : result.confirmed ? 'Возврат подтверждён.' : 'Запрос возврата сохранён. Сумма и доступ изменятся после подтверждения Stripe.');
          }); }}><label className="core-field"><span>Общая сумма возврата с учётом предыдущих, {order.currency}</span><input required inputMode="decimal" disabled={blocked || unresolved} value={targetText} onChange={e => setRefunds(v => ({ ...v, [order.id]: e.target.value }))} /></label>
            <button className="brand-button" disabled={blocked || (unresolved && !['unknown', 'calling'].includes(order.refundState || ''))}>{unresolved ? 'Повторить тот же запрос возврата' : 'Проверить и запросить возврат'}</button>
            <p>Полный подтверждённый возврат отзывает доступ к скачиванию. Уже скачанную копию удалить у покупателя невозможно.</p>
          </form>}
        </article>;
      })}
    </>}
  </section>;
}
