import type { SVGProps } from 'react'
import { BrandMark } from './BrandMark'
export type OSAMarkVariant='mark'|'lockup'
type Props={variant?:OSAMarkVariant;className?:string;title?:string;symbolProps?:SVGProps<SVGSVGElement>}
/** Retains the existing component contract while using the common portal geometry. */
export function OSAMark({variant='lockup',className='',title='OSA Intelligence',symbolProps}:Props){
 const compact=variant==='mark'
 return <span className={'osa5-mark-lockup '+(compact?'osa5-mark-only':'osa5-mark-with-name')+' '+className} role={compact?undefined:'img'} aria-label={compact?undefined:title} aria-hidden={compact?true:undefined}>
 <BrandMark theme="intelligence" className="osa5-mark-symbol" width="36" height="36" {...symbolProps}/>
 {!compact&&<span className="osa5-mark-word"><strong>OSA</strong><small>INTELLIGENCE</small></span>}
 </span>
}
