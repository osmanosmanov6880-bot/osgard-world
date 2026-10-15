import { useState } from 'react'
import { OSAMark } from './OSAMark'
import { ArrowRight, ArrowUpRight, BookOpen, Globe2, Layers3, ShieldCheck, Sparkles } from 'lucide-react'
import './osaIntelligenceHome.css'

type Locale = 'ru' | 'en'
const copy = {
  ru: {
    eyebrow: 'OSA INTELLIGENCE / BEYOND THE MODEL', titleA: 'Мышление', titleB: 'важнее модели.',
    lead: 'Изучайте искусственный интеллект, проверяйте доказательства и превращайте сложные вопросы в обоснованные решения — сохраняя человека в контуре.',
    primary: 'Начать OSA Original', secondary: 'Открыть Академию', proofA: '8 интерактивных сцен', proofB: '3 смысловых акта', proofC: 'Практика на вашем устройстве',
    artTop: 'INTELLIGENCE / 001', artTitle: 'Не верьте форме.', artBody: 'Проверьте содержание.', tagA: 'МОДЕЛЬ', tagB: 'ДОКАЗАТЕЛЬСТВА', tagC: 'РЕШЕНИЕ',
    sectionEyebrow: 'ЕДИНАЯ СРЕДА OSA', sectionTitle: 'От понимания — к действию.', sectionLead: 'Не просто читать об ИИ. Пробовать, задавать критерии, проверять источники и разбирать последствия.',
    cinemaTitle: 'OSA Original', cinemaBody: 'Интерактивное путешествие по возможностям ИИ, власти знаний и человеческой ответственности. Ваши выборы меняют ход обучения.', cinemaAction: 'Войти в опыт',
    academyTitle: 'AI Academy', academyBody: 'Учебные маршруты, локальный прогресс и практическая студия для проектов, проверки источников и ответственных решений.', academyAction: 'Продолжить практику',
    portalTitle: 'Экосистема OSGARD', portalBody: 'Вернитесь в общий портал продуктов, игр и цифровых проектов. Существующие разделы остаются на месте.', portalAction: 'Открыть портал',
    principleTitle: 'Три принципа.', principleA: 'Понимайте систему', principleABody: 'Отделяйте возможности модели от обещаний и ограничений.', principleB: 'Проверяйте доказательства', principleBBody: 'Открывайте первоисточники и уточняйте, что именно подтверждено.',
    principleC: 'Сохраняйте ответственность', principleCBody: 'Учитывайте приватность, риск ошибки и последствия решения.',
    footer: 'OSA Intelligence · Интерактивное обучение, проверка и практика.', footerNote: 'Прогресс сохраняется в этом браузере. Не вводите секреты и лишние персональные данные.',
    language: 'Переключить язык', home: 'OSA INTELLIGENCE'
  },
  en: {
    eyebrow: 'OSA INTELLIGENCE / BEYOND THE MODEL', titleA: 'Better thinking', titleB: 'beats bigger models.',
    lead: 'Explore artificial intelligence, verify evidence, and turn difficult questions into grounded decisions — with people remaining in the loop.',
    primary: 'Start OSA Original', secondary: 'Open the Academy', proofA: '8 interactive scenes', proofB: '3 connected acts', proofC: 'Practice on your device',
    artTop: 'INTELLIGENCE / 001', artTitle: 'Do not trust the form.', artBody: 'Examine the evidence.', tagA: 'MODEL', tagB: 'EVIDENCE', tagC: 'DECISION',
    sectionEyebrow: 'THE OSA ENVIRONMENT', sectionTitle: 'From understanding to action.', sectionLead: 'More than reading about AI. Try ideas, set criteria, verify sources, and examine consequences.',
    cinemaTitle: 'OSA Original', cinemaBody: 'An interactive journey through AI capabilities, the power of knowledge, and human responsibility. Your choices shape the learning experience.', cinemaAction: 'Enter the experience',
    academyTitle: 'AI Academy', academyBody: 'Learning paths, local progress tracking, and a practical studio for projects, source verification, and responsible decisions.', academyAction: 'Continue practising',
    portalTitle: 'OSGARD ecosystem', portalBody: 'Return to the wider portal for products, games, and digital projects. Existing sections remain in place.', portalAction: 'Open the portal',
    principleTitle: 'Three principles.', principleA: 'Understand the system', principleABody: 'Separate model capabilities from promises and limitations.', principleB: 'Verify the evidence', principleBBody: 'Open original sources and establish what they actually support.',
    principleC: 'Keep responsibility', principleCBody: 'Consider privacy, error risk, and the consequences of a decision.',
    footer: 'OSA Intelligence · Interactive learning, verification, and practice.', footerNote: 'Learning progress stays in this browser. Do not enter secrets or unnecessary personal data.',
    language: 'Switch language', home: 'OSA INTELLIGENCE'
  }
}

export default function OSAIntelligenceHome() {
  const [locale, setLocale] = useState<Locale>('ru')
  const t = copy[locale]
  return <main className="osa-home" lang={locale}>
    <div className="osa-home-noise" aria-hidden="true" />
    <header className="osa-home-header">
      <a className="osa-home-brand" href="/" aria-label={t.home}><span className="osa-home-brand-mark"><OSAMark variant="mark" className="osa-home-symbol" /></span><span><strong>OSA</strong><small>INTELLIGENCE <i> / 5.0</i></small></span></a>
      <div className="osa-home-header-actions"><span className="osa-home-status"><i />{locale === 'ru' ? 'ИНТЕЛЛЕКТ · ИССЛЕДОВАНИЕ · ДЕЙСТВИЕ' : 'INTELLIGENCE · RESEARCH · ACTION'}</span>
        <button className="osa-home-language" type="button" onClick={() => setLocale(locale === 'ru' ? 'en' : 'ru')} aria-label={t.language}><Globe2 size={15} />{locale.toUpperCase()}</button>
        <a className="osa-home-portal-link osa-home-lectures-link" href="/lectures" aria-label={locale === 'ru' ? 'Курсы и лекции' : 'Courses and lectures'}>{locale === 'ru' ? 'КУРСЫ И ЛЕКЦИИ' : 'COURSES & LECTURES'} <BookOpen size={14} /></a><a className="osa-home-portal-link" href="/portal">OSGARD <ArrowUpRight size={14} /></a>
      </div>
    </header>

    <section className="osa-home-hero" aria-labelledby="osa-home-title">
      <div className="osa-home-copy">
        <p className="osa-home-eyebrow"><span />{t.eyebrow}</p>
        <h1 id="osa-home-title">{t.titleA}<br /><em>{t.titleB}</em></h1>
        <p className="osa-home-lead">{t.lead}</p>
        <div className="osa-home-actions">
          <a className="osa-home-button osa-home-button-primary" href="/osa-cinema">{t.primary}<ArrowUpRight size={17} /></a>
          <a className="osa-home-button osa-home-button-secondary" href="/academy">{t.secondary}<ArrowRight size={16} /></a>
        </div>
        <div className="osa-home-proof" aria-label={locale === 'ru' ? 'Состав опыта' : 'Experience overview'}>
          <span><BookOpen size={15} />{t.proofA}</span><span><Layers3 size={15} />{t.proofB}</span><span><ShieldCheck size={15} />{t.proofC}</span>
        </div>
      </div>
      <div className="osa-home-art" role="img" aria-label={locale === 'ru' ? 'Схема модели, доказательств и решения' : 'Model, evidence, and decision diagram'}>
        <div className="osa-home-art-grid" /><div className="osa-home-orbit osa-home-orbit-one" /><div className="osa-home-orbit osa-home-orbit-two" />
        <div className="osa-home-art-caption">{t.artTop}</div>
        <div className="osa-home-core"><Sparkles size={22} /><strong>OSA</strong><small>THINK / VERIFY / ACT</small></div>
        <div className="osa-home-float osa-home-float-model"><i>01</i><span>{t.tagA}</span></div>
        <div className="osa-home-float osa-home-float-evidence"><i>02</i><span>{t.tagB}</span></div>
        <div className="osa-home-float osa-home-float-decision"><i>03</i><span>{t.tagC}</span></div>
        <div className="osa-home-art-note"><strong>{t.artTitle}</strong><span>{t.artBody}</span></div>
        <div className="osa-home-art-cross osa-home-cross-a" /><div className="osa-home-art-cross osa-home-cross-b" />
      </div>
    </section>

    <section className="osa-home-modules" aria-labelledby="osa-home-modules-title">
      <div className="osa-home-section-heading"><div><p className="osa-home-eyebrow">{t.sectionEyebrow}</p><h2 id="osa-home-modules-title">{t.sectionTitle}</h2></div><p>{t.sectionLead}</p></div>
      <div className="osa-home-card-grid">
        <a className="osa-home-card osa-home-card-featured" href="/osa-cinema"><span className="osa-home-card-index">01 / ORIGINAL</span><span className="osa-home-card-icon"><BookOpen size={21} /></span><h3>{t.cinemaTitle}</h3><p>{t.cinemaBody}</p><span className="osa-home-card-action">{t.cinemaAction}<ArrowUpRight size={16} /></span></a>
        <a className="osa-home-card" href="/academy"><span className="osa-home-card-index">02 / PRACTICE</span><span className="osa-home-card-icon"><ShieldCheck size={21} /></span><h3>{t.academyTitle}</h3><p>{t.academyBody}</p><span className="osa-home-card-action">{t.academyAction}<ArrowUpRight size={16} /></span></a>
        <a className="osa-home-card" href="/portal"><span className="osa-home-card-index">03 / ECOSYSTEM</span><span className="osa-home-card-icon"><Globe2 size={21} /></span><h3>{t.portalTitle}</h3><p>{t.portalBody}</p><span className="osa-home-card-action">{t.portalAction}<ArrowUpRight size={16} /></span></a>
      </div>
    </section>

    <section className="osa-home-principles" aria-labelledby="osa-home-principles-title">
      <div className="osa-home-principles-heading"><p className="osa-home-eyebrow">OSA / METHOD</p><h2 id="osa-home-principles-title">{t.principleTitle}</h2></div>
      <div className="osa-home-principle"><span>01</span><div><h3>{t.principleA}</h3><p>{t.principleABody}</p></div></div>
      <div className="osa-home-principle"><span>02</span><div><h3>{t.principleB}</h3><p>{t.principleBBody}</p></div></div>
      <div className="osa-home-principle"><span>03</span><div><h3>{t.principleC}</h3><p>{t.principleCBody}</p></div></div>
    </section>
    <footer className="osa-home-footer"><a className="osa-home-footer-brand" href="/"><span>OSA</span> INTELLIGENCE</a><p>{t.footer}</p><small>{t.footerNote}</small></footer>
  </main>
}
