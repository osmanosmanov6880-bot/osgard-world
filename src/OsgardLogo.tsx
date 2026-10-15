import { OSAMark } from './OSAMark'

type Props = { variant?: 'header' | 'footer' | 'preloader'; className?: string }

export function OsgardLogo({ variant = 'header', className = '' }: Props) {
  return <span className={'osgard-logo osgard-logo-' + variant + (className ? ' ' + className : '')} role="img" aria-label="OSGARD WORLD · OSA 5.0">
    <OSAMark variant="mark" className="osgard-logo-symbol" />
    <span className="osgard-logo-copy"><strong>OSGARD</strong><small>WORLD <i aria-hidden="true">/</i> OSA 5.0</small></span>
  </span>
}
