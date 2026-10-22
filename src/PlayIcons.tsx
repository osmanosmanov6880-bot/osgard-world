import type { SVGProps } from 'react'

type Props = SVGProps<SVGSVGElement> & { size?: number | string }

// The same Lucide geometry lives in a small cacheable SVG sprite. These icons
// need neither per-icon JavaScript modules nor the Lucide runtime wrapper.
function icon(name: string) {
  return function PlayIcon({ size = 24, ...props }: Props) {
    return <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24"
      fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" {...props}>
      <use href={'/brand/play/ui-icons.svg#' + name} />
    </svg>
  }
}

export const ArrowDown = /* @__PURE__ */ icon('arrow-down')
export const ArrowRight = /* @__PURE__ */ icon('arrow-right')
export const ArrowUpRight = /* @__PURE__ */ icon('arrow-up-right')
export const Bookmark = /* @__PURE__ */ icon('bookmark')
export const Box = /* @__PURE__ */ icon('box')
export const ChevronLeft = /* @__PURE__ */ icon('chevron-left')
export const ChevronRight = /* @__PURE__ */ icon('chevron-right')
export const Film = /* @__PURE__ */ icon('film')
export const Gamepad2 = /* @__PURE__ */ icon('gamepad2')
export const InfinityIcon = /* @__PURE__ */ icon('infinity')
export const Layers3 = /* @__PURE__ */ icon('layers3')
export const Orbit = /* @__PURE__ */ icon('orbit')
export const ShieldCheck = /* @__PURE__ */ icon('shield-check')
export const Search = /* @__PURE__ */ icon('search')
export const Sparkles = /* @__PURE__ */ icon('sparkles')
export const Waypoints = /* @__PURE__ */ icon('waypoints')
export const X = /* @__PURE__ */ icon('x')
export const Zap = /* @__PURE__ */ icon('zap')
