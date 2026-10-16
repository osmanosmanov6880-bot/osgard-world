import type { SVGProps } from 'react'
export type ProductTheme='world'|'intelligence'|'play'
export function BrandMark({theme='world',...props}:SVGProps<SVGSVGElement>&{theme?:ProductTheme}) {
 return <svg viewBox="0 0 64 64" fill="none" aria-hidden="true" focusable="false" {...props}>
  <path d={theme==='play'?'M47 11A25 25 0 1 0 56 39':'M49.7 14.3A25 25 0 1 0 57 32'} stroke="currentColor" strokeWidth={theme==='intelligence'?3:5} strokeLinecap={theme==='play'?'square':'round'}/>
  <path d={theme==='play'?'M60 23H33l8 8':'M57 32H34l8-8'} stroke="currentColor" strokeWidth={theme==='intelligence'?3:5} strokeLinecap="round" strokeLinejoin="round"/>
  {theme==='intelligence'&&<circle cx="32" cy="32" r="12" stroke="currentColor" strokeWidth="1" opacity=".55"/>}
 </svg>
}
export function BrandLockup({theme='world'}:{theme?:ProductTheme}){return <span className="brand-lockup"><BrandMark theme={theme}/><span><b role="img" aria-label={theme==='intelligence'?'OSA':'OSGARD'}>{theme==='intelligence'?'OSA':<><span>OS</span><BrandMark theme={theme} className="brand-letter-g"/><span>ARD</span></>}</b><small>{theme==='world'?'WORLD':theme==='play'?'PLAY':'INTELLIGENCE'}</small></span></span>}
