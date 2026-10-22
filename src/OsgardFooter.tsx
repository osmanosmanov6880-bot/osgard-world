import { BrandLockup } from './BrandMark'
import type { BrandArea } from './brandNavigation'
import { REPLAY_INTRO_EVENT, introEligible } from './osgardRouting'

const footerGroups = [
  { title: 'Продукты', links: [['OSGARD WORLD', '/'], ['OSA Intelligence', '/intelligence'], ['OSGARD PLAY', '/play'], ['Разработка', '/development']] },
  { title: 'Моя работа', links: [['Рабочий центр', '/workspace/overview'], ['Проекты', '/workspace'], ['Команды', '/teams'], ['Полученные материалы', '/deliveries'], ['Покупки', '/purchases'], ['Аккаунт', '/account'], ['Мои данные', '/data']] },
  { title: 'Информация', links: [['Фирменная система', '/brand'], ['Состояние сборки', '/quality'], ['Приватность', '/privacy/'], ['Условия', '/terms/'], ['Связаться', '/#contact']] },
]

/** Noncritical footer is deferred until after the product header and route. */
export default function OsgardFooter({ product, motion, reduced }: { product: BrandArea; motion: boolean; reduced: boolean }) {
  return <footer className="brand-footer">
    <div className="brand-footer-intro">
      <BrandLockup theme={product} />
      <p>Одна экосистема.<br />Разные способы двигаться вперёд.</p>
      <button type="button" className="brand-button"
        onClick={() => window.dispatchEvent(new Event(REPLAY_INTRO_EVENT))}
        disabled={reduced || !motion || !introEligible()}
        title={reduced || !motion ? 'Заставка отключена настройкой уменьшения движения' : !introEligible() ? 'Заставка недоступна в этом режиме или на этом устройстве' : 'Повторить заставку OSGARD'}>
        Повторить заставку
      </button>
    </div>
    {footerGroups.map(group => <nav key={group.title} aria-label={group.title} className="brand-footer-group">
      <h2>{group.title}</h2>
      {group.links.map(([label, href]) => <a key={href} href={href}>{label}</a>)}
    </nav>)}
    <small className="brand-footer-note">
      Гостевой прогресс остаётся в этом браузере. Серверные проекты доступны через аккаунт.
      {' '}<a href="/quality#measurements">Посмотреть и удалить локальный журнал действий →</a>
    </small>
  </footer>
}
