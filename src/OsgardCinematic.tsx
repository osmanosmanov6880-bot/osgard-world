import { useRef } from 'react'
import type { CSSProperties } from 'react'
import './osgardCinematic.css'

export type OsgardCinematicProps = {
  kind: 'intro' | 'transition' | 'play'
  phase?: string
  onComplete: () => void
  onSkip: () => void
  reduced?: boolean
  lowPower?: boolean
}

const ART = '/brand/intro/'

/** The original reference emblem is an alpha image; the scene remains layered DOM/SVG. */
export function OsgardLogoReveal({ compact = false, onFailure }: { compact?: boolean; onFailure: () => void }) {
  return <div className={'oc-brand-scene' + (compact ? ' oc-brand-compact' : '')}>
    <div className="oc-logo-space" aria-hidden="true">
      <div className="oc-core" />
      <svg className="oc-orbits" viewBox="0 0 700 700" fill="none">
        <circle className="oc-orbit-exterior" cx="350" cy="350" r="324" stroke="currentColor" strokeWidth=".6" strokeDasharray="1 9" />
        <circle cx="350" cy="350" r="284" stroke="currentColor" strokeWidth=".55" opacity=".45" />
        <path d="M71 340A280 280 0 0 1 610 244M90 458A280 280 0 0 0 572 521" stroke="currentColor" strokeWidth="1" opacity=".7" />
        <ellipse className="oc-orbit-diagonal" cx="350" cy="350" rx="331" ry="70" transform="rotate(-43 350 350)" stroke="url(#oc-orbit-color)" strokeWidth="1.2" />
        <ellipse className="oc-orbit-wide" cx="350" cy="350" rx="408" ry="120" transform="rotate(-14 350 350)" stroke="currentColor" strokeWidth=".65" opacity=".4" />
        <path d="M350 4V102M350 612V696M332 42H368M343 83H357M342 643H358" stroke="currentColor" strokeWidth=".6" opacity=".65" />
        <path d="M350 83l5 5-5 5-5-5Z" fill="#b8fbff" />
        <defs><linearGradient id="oc-orbit-color" x1="78" y1="552" x2="624" y2="190" gradientUnits="userSpaceOnUse"><stop stopColor="#c376ff" /><stop offset=".3" stopColor="#51d3ed" /><stop offset=".78" stopColor="#8bfaff" /><stop offset="1" stopColor="#bcb5ff" /></linearGradient></defs>
      </svg>
      <span className="oc-orbit-node oc-orbit-node-one" />
      <span className="oc-orbit-node oc-orbit-node-two" />
      <span className="oc-orbit-node oc-orbit-node-three" />
      <div className="oc-emblem">
        <img className="oc-emblem-image" src={ART + 'osgard-emblem.webp'} srcSet={ART + 'osgard-emblem-640.webp 640w, ' + ART + 'osgard-emblem.webp 1254w'} sizes="(max-width: 600px) 82vw, 50vh" width="1254" height="1254" alt="" fetchPriority="high" decoding="async" onError={onFailure} />
        <div className="oc-emblem-shards"><i /><i /><i /></div>
        <span className="oc-emblem-rim" /><span className="oc-emblem-sweep" />
      </div>
      <span className="oc-star oc-star-cyan" /><span className="oc-star oc-star-violet" />
    </div>
    <div className="oc-wordmark" role="img" aria-label="OSGARD">
      {'OSGARD'.split('').map((letter, index) => <span key={index} aria-hidden="true" style={{ '--letter': index } as CSSProperties}>{letter}</span>)}
    </div>
    <p className="oc-universe"><i aria-hidden="true" /><span>DIGITAL UNIVERSE</span><i aria-hidden="true" /></p>
    <div className="oc-brand-coordinate" aria-hidden="true"><i /><span /><b /></div>
  </div>
}

export function OsgardPortalEffect() {
  return <div className="oc-portal-depth" aria-hidden="true"><i /><i /><i /><span /></div>
}

function OsgardEnergyPlatform() {
  return <svg className="oc-platform" viewBox="0 0 1200 270" fill="none" aria-hidden="true">
    <defs>
      <linearGradient id="oc-floor-color" x1="112" y1="140" x2="1090" y2="141" gradientUnits="userSpaceOnUse"><stop stopColor="#2676a1" stopOpacity="0" /><stop offset=".22" stopColor="#3bdafb" /><stop offset=".5" stopColor="#d0ffff" /><stop offset=".77" stopColor="#49d9ec" /><stop offset="1" stopColor="#586cba" stopOpacity="0" /></linearGradient>
      <radialGradient id="oc-floor-core"><stop stopColor="#a3fbff" stopOpacity=".4" /><stop offset=".14" stopColor="#39e7f2" stopOpacity=".15" /><stop offset="1" stopColor="#18b2df" stopOpacity="0" /></radialGradient>
    </defs>
    <ellipse cx="600" cy="148" rx="370" ry="86" fill="url(#oc-floor-core)" />
    <g className="oc-floor-ring oc-floor-ring-one"><ellipse cx="600" cy="136" rx="207" ry="28" stroke="url(#oc-floor-color)" strokeWidth="1.6" /><ellipse cx="600" cy="137" rx="181" ry="21" stroke="#6ff4ff" strokeWidth=".7" opacity=".55" /></g>
    <g className="oc-floor-ring oc-floor-ring-two"><ellipse cx="600" cy="142" rx="302" ry="51" stroke="url(#oc-floor-color)" strokeWidth="1.5" /><ellipse cx="600" cy="146" rx="317" ry="51" stroke="#35c9e3" strokeWidth=".6" strokeDasharray="52 7 12 5" /></g>
    <g className="oc-floor-ring oc-floor-ring-three"><ellipse cx="600" cy="147" rx="398" ry="73" stroke="url(#oc-floor-color)" strokeWidth="1" /><ellipse cx="600" cy="151" rx="418" ry="73" stroke="#2694ba" strokeWidth=".6" opacity=".65" /></g>
    <g className="oc-floor-ring oc-floor-ring-four"><ellipse cx="600" cy="152" rx="566" ry="104" stroke="url(#oc-floor-color)" strokeWidth=".7" strokeDasharray="170 12 68 12" /><path d="M16 149H215M985 149H1186M600 97V116M600 180V250M180 214l116-38M900 184l106 34" stroke="url(#oc-floor-color)" strokeWidth="1" /></g>
    <path className="oc-floor-reflection" d="M598 145L590 267H610L602 145Z" fill="#55f4ff" opacity=".2" />
    <path d="M578 142H622M600 124V163" stroke="#ccffff" strokeWidth="1.1" />
  </svg>
}

const phaseLabels: Record<string, string> = {
  awakening: 'ПРОБУЖДЕНИЕ', activation: 'ЭНЕРГИЯ В ДВИЖЕНИИ', reveal: 'OSGARD DIGITAL UNIVERSE',
  online: 'ВСЕЛЕННАЯ ОТКРЫВАЕТСЯ', enter: 'ТВОЯ ИСТОРИЯ НАЧИНАЕТСЯ',
}

/** A finite, silent sequence. The provider also owns an independent completion deadline. */
export default function OsgardCinematic({ kind, phase = 'awakening', onComplete, onSkip, reduced = false, lowPower = false }: OsgardCinematicProps) {
  const completed = useRef(false)
  const finish = () => { if (!completed.current) { completed.current = true; onComplete() } }
  return <section className="osgard-cinematic" data-kind={kind} data-phase={phase} data-reduced={reduced} data-low-power={lowPower}
    role="dialog" aria-modal="true" aria-label={kind === 'intro' ? 'Заставка OSGARD DIGITAL UNIVERSE' : 'Переход между разделами OSGARD'}
    onAnimationEnd={event => { if (event.target === event.currentTarget && ['oc-intro-lifetime', 'oc-transition-lifetime', 'oc-reduced-lifetime'].includes(event.animationName)) finish() }}>
    <div className="oc-cosmos" aria-hidden="true">
      <picture className="oc-environment">
        <source media="(max-width: 600px)" srcSet={ART + 'energy-platform-mobile-780.webp 780w, ' + ART + 'energy-platform-mobile.webp 1024w'} sizes="100vw" />
        <img src={ART + 'energy-platform.webp'} srcSet={ART + 'energy-platform-1280.webp 1280w, ' + ART + 'energy-platform.webp 1672w'} sizes="100vw" alt="" width="1672" height="941" fetchPriority="high" decoding="async" />
      </picture>
      <div className="oc-environment-shade" />
      <div className="oc-particles">{Array.from({ length: lowPower ? 6 : 22 }, (_, index) => <i key={index} style={{
        '--particle': index, left: ((index * 43 + 7) % 96) + '%', top: ((index * 29 + 9) % 88) + '%',
      } as CSSProperties} />)}</div>
      <div className="oc-guides"><i /><i /><i /><i /></div>
      <div className="oc-beam" /><div className="oc-horizon" />
      <OsgardEnergyPlatform />
    </div>
    {kind === 'play' && <OsgardPortalEffect />}
    <OsgardLogoReveal compact={kind !== 'intro'} onFailure={finish} />
    <div className="oc-arrival-light" aria-hidden="true" />
    <div className="oc-caption" aria-hidden="true"><span className="oc-caption-signal" /><span>{kind === 'intro' ? phaseLabels[phase] || 'OSGARD DIGITAL UNIVERSE' : kind === 'play' ? 'ВХОД В ИГРОВЫЕ МИРЫ' : 'ПЕРЕХОД ВО ВСЕЛЕННОЙ'}</span></div>
    <button className="oc-skip" type="button" autoFocus onClick={onSkip}>Пропустить <svg viewBox="0 0 24 24" width="17" height="17" fill="none" stroke="currentColor" strokeWidth="1.4" aria-hidden="true"><path d="m5 6 7 6-7 6M15 6v12" /></svg></button>
    <span className="oc-keyboard-hint" aria-hidden="true">ESC · ВОЙТИ СРАЗУ</span>
  </section>
}
