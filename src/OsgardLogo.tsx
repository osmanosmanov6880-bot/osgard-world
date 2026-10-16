import './logo.css'
import { BrandMark } from './BrandMark'

type Props = { variant?: 'header' | 'footer' | 'preloader'; className?: string }

export function OsgardLogo({ variant = 'header', className = '' }: Props) {
  return <span className={'osgard-logo osgard-logo-' + variant + (className ? ' ' + className : '')} role="img" aria-label="OSGARD WORLD">
    <BrandMark className="osgard-logo-symbol" />
    <span className="osgard-logo-copy"><strong>OSGARD</strong><small>WORLD</small></span>
  </span>
}
