import { BrandLockup } from './BrandMark'
import type { BrandArea } from './brandNavigation'
import { REPLAY_INTRO_EVENT, introEligible } from './osgardRouting'

const footerGroups = [
  { title: 'Продукты', links: [['OSGARD WORLD', '/'], ['OSA Intelligence', '/intelligence'], ['OSGARD PLAY', '/play'], ['Разработка', '/development']] },
  { title: 'Моя работа', links: [['Рабочий центр', '/workspace/overview'], ['Проекты', '/workspace'], ['Команды', '/teams'], ['Полученные материалы', '/deliveries'], ['Покупки', '/purchases'], ['Аккаунт', '/account'], ['Мои данные', '/data']] },
  { title: 'Информация', links: [['Фирменная система', '/brand'], ['Состояние сборки', '/quality'], ['Приватность', '/privacy/'], ['Условия', '/terms/'], ['Связаться', '/#contact']] },
]

/** Noncritical footer is deferred until after the product header and route. */
export default function OsgardFooter({ product, motion, reduced, locale }: { product: BrandArea; motion: boolean; reduced: boolean; locale: 'ru' | 'en' }) {
  const groups = locale === 'ru' ? footerGroups : [
    { title: 'Products', links: [['OSGARD WORLD', '/'], ['OSA Intelligence', '/intelligence'], ['OSGARD PLAY', '/play'], ['Development', '/development']] },
    { title: 'My work', links: [['Workspace', '/workspace/overview'], ['Projects', '/workspace'], ['Teams', '/teams'], ['Deliveries', '/deliveries'], ['Purchases', '/purchases'], ['Account', '/account'], ['My data', '/data']] },
    { title: 'Information', links: [['Brand system', '/brand'], ['Build status', '/quality'], ['Privacy', '/privacy/'], ['Terms', '/terms/'], ['Contact', '/#contact']] },
  ]
  const tx = (ru: string, en: string) => locale === 'ru' ? ru : en
  return <footer className="brand-footer">
    <div className="brand-footer-intro">
      <BrandLockup theme={product} />
      <p>{tx('Одна экосистема.', 'One ecosystem.')}<br />{tx('Разные способы двигаться вперёд.', 'Different ways to move forward.')}</p>
      <button type="button" className="brand-button"
        onClick={() => window.dispatchEvent(new Event(REPLAY_INTRO_EVENT))}
        disabled={reduced || !motion || !introEligible()}
        title={reduced || !motion ? tx('Заставка отключена настройкой уменьшения движения', 'Intro is disabled by the reduced motion setting') : !introEligible() ? tx('Заставка недоступна в этом режиме или на этом устройстве', 'Intro is unavailable in this mode or on this device') : tx('Повторить заставку OSGARD', 'Replay OSGARD intro')}>
        {tx('Повторить заставку', 'Replay intro')}
      </button>
    </div>
    {groups.map(group => <nav key={group.title} aria-label={group.title} className="brand-footer-group">
      <h2>{group.title}</h2>
      {group.links.map(([label, href]) => <a key={href} href={href}>{label}</a>)}
    </nav>)}
    <small className="brand-footer-note">
      {tx('Гостевой прогресс остаётся в этом браузере. Серверные проекты доступны через аккаунт.', 'Guest progress stays in this browser. Server projects are available through an account.')}
      {' '}<a href="/quality#measurements">{tx('Посмотреть и удалить локальный журнал действий', 'View and delete the local activity log')} →</a>
    </small>
  </footer>
}
