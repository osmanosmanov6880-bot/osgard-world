// HORIZON R13 — exact touch-hit geometry mirrored from
// godot/empire-omega/scripts/horizon_touch_controls.gd::_layout().
// Keeps real Chromium gestures inside circular TouchScreenButton shapes.
const clamp=(v,lo,hi)=>Math.max(lo,Math.min(hi,v))

export function mobileTouchCenters(width,height){
  if(!Number.isFinite(width)||!Number.isFinite(height)||width<290||height<410)
    throw new RangeError('Expected a valid playable Godot viewport')
  const scale=clamp(Math.min(width/390,height/760),0.72,1.12)
  const margin=53*scale
  const spacing=78*scale
  const lower=height-58*scale
  const upper=height-142*scale
  return {
    enter_vehicle:{x:width-margin-spacing,y:upper},
    interact:{x:width-margin-spacing*2,y:upper},
    pause_game:{x:margin,y:upper},
    move_left:{x:margin,y:lower},
    move_right:{x:margin+spacing,y:lower},
    move_backward:{x:width-margin-spacing,y:lower},
    move_forward:{x:width-margin,y:lower},
    jump:{x:width-margin,y:upper}
  }
}

export function browserTouchPoint(box,command){
  if(!box||!Number.isFinite(box.x)||!Number.isFinite(box.y)||
    !Number.isFinite(box.width)||!Number.isFinite(box.height))
    throw new TypeError('Expected real canvas screen bounds')
  const all=mobileTouchCenters(box.width,box.height)
  if(!Object.hasOwn(all,command))throw new RangeError('Unknown game touch command')
  return {x:Math.round(box.x+all[command].x),y:Math.round(box.y+all[command].y)}
}
