import type { SVGProps } from 'react'

export type OSAMarkVariant = 'mark' | 'lockup'
type Props = { variant?: OSAMarkVariant; className?: string; title?: string; symbolProps?: SVGProps<SVGSVGElement> }

/** Original OSA 5.0 vector: open angular frame with integrated O/S/A strokes. */
export function OSAMark({ variant = 'lockup', className = '', title = 'OSA 5.0', symbolProps }: Props) {
  const compact = variant === 'mark'
  return <span
    className={'osa5-mark-lockup' + (compact ? ' osa5-mark-only' : ' osa5-mark-with-name') + (className ? ' ' + className : '')}
    role={compact ? undefined : 'img'}
    aria-label={compact ? undefined : title}
    aria-hidden={compact ? true : undefined}
  >
    <svg className="osa5-mark-symbol" viewBox="0 0 64 64" fill="none" aria-hidden="true" focusable="false" {...symbolProps}>
      <path d="M18 7.5h20.5L52 21v22L38.5 56.5H18L4.5 43V21Z" />
      <path d="M42 20.5H25L19.5 26v3L24 33.5h13L42 38v3l-5.5 5.5h-16" />
      <path d="M22.5 45.5 31.5 16 41 45.5M26 34.5h11" />
      <path d="M45 11h5v5" />
      <circle cx="45" cy="11" r="1.5" className="osa5-mark-point" />
    </svg>
    {!compact && <span className="osa5-mark-word"><strong>OSA</strong><small>5.0</small></span>}
  </span>
}
