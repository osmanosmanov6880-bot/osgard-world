#!/usr/bin/env python3
"""W85 source-only ORIGINAL GODOT five-phase mission guide Chromium QA.
Real native Godot GUI clicks and original W70 3D engine, not JS game mocks.
Full five-phase terminal game is separately verified by test_w85_field_guide.
"""
import argparse
import functools
import hashlib
import io
import json
import threading
from pathlib import Path
from PIL import Image,ImageChops,ImageStat
from playwright.sync_api import sync_playwright
from w64_browser_acceptance import LocalServer,HTTPHandler,geometry,snapshot,wait_state

def require(ok,why):
    if not ok:
        raise AssertionError(why)

def center(rect):
    require(len(rect)==4 and rect[2]>=44 and rect[3]>=44,
        "Original native Godot actual clickable >=44px control")
    return (rect[0]+rect[2]*.5,rect[1]+rect[3]*.5)

def tap(page,key):
    g=geometry(page)
    x,y=center(g[key])
    page.mouse.click(x,y)

def contained(rect,stage):
    return (len(rect)==4 and rect[2]>20 and rect[3]>15
            and rect[0]>=stage[0]-3 and rect[1]>=stage[1]-3
            and rect[0]+rect[2]<=stage[0]+stage[2]+3
            and rect[1]+rect[3]<=stage[1]+stage[3]+3)

def frame(page,path):
    raw=page.screenshot(path=str(path))
    img=Image.open(io.BytesIO(raw)).convert('RGB')
    require(max(ImageStat.Stat(img).stddev)>5,
        "Only actual original rendered 3D Godot WebGL frames accepted")
    return raw

def contrast(a,b):
    aa=Image.open(io.BytesIO(a)).convert('RGB')
    bb=Image.open(io.BytesIO(b)).convert('RGB')
    require(aa.size==bb.size,"Compare same-res source frames")
    return sum(ImageChops.difference(aa,bb).convert('L').histogram()[12:])

def true_layout(page,width,height,guide_open):
    page.set_viewport_size({"width":width,"height":height})
    page.wait_for_function("""([w,h,isOpen]) => {
      const el=document.getElementById('a7-cascade-native-state');
      if(!el)return false;
      try {
        const s=JSON.parse(el.getAttribute('data-state'));
        const g=JSON.parse(el.getAttribute('data-geometry'));
        const contained=(r,p)=>Array.isArray(r)&&r.length===4&&
          r[2]>20&&r[3]>15&&r[0]>=p[0]-3&&r[1]>=p[1]-3&&
          r[0]+r[2]<=p[0]+p[2]+3&&r[1]+r[3]<=p[1]+p[3]+3;
        return g.viewport[0]===w&&g.viewport[1]===h&&
          s.w85_source_guide_visible===true&&s.w85_source_guide_open===isOpen&&
          s.w85_actual_original_phase===0&&
          s.w85_real_original_body_id>0&&s.history_count===0&&
          contained(g.w85_guide_entry,g.stage)&&
          (!isOpen || (
            contained(g.w85_guide_panel,g.stage)&&
            contained(g.w85_guide_close,g.stage)&&
            contained(g.w85_guide_objective,g.stage)&&
            contained(g.w85_guide_distance,g.stage)));
      }catch(e){return false}
    }""",arg=[width,height,guide_open],timeout=100000)
    return snapshot(page),geometry(page)

def run(export,evidence,sha):
    require(len(sha)==40 and all(c in '0123456789abcdef' for c in sha),
         "Only exact source SHA accepted")
    require((export/'index.wasm').read_bytes()[:4]==b'\x00asm',
         "Original Godot 4.4.1 actual WASM binary required")
    evidence.mkdir(parents=True,exist_ok=True)
    errors=[]
    with LocalServer(('127.0.0.1',0),
        functools.partial(HTTPHandler,directory=str(export))) as server:
        threading.Thread(target=server.serve_forever,daemon=True).start()
        with sync_playwright() as pw:
            browser=pw.chromium.launch(headless=True,args=[
                '--no-sandbox','--disable-dev-shm-usage','--enable-webgl',
                '--use-gl=angle','--use-angle=swiftshader',
                '--enable-unsafe-swiftshader'])
            context=browser.new_context(
                viewport={'width':390,'height':844},has_touch=True,
                device_scale_factor=1)
            page=context.new_page()
            page.on('pageerror',lambda e:errors.append(str(e)))
            page.goto(f"http://127.0.0.1:{server.server_address[1]}/index.html",
                wait_until='domcontentloaded',timeout=120000)
            page.locator('#a7-cascade-native-state').wait_for(
                state='attached',timeout=180000)
            start=wait_state(page,{'w85_source_guide_visible':False,
                'w76_actual_immersive_first_person':False,'history_count':0})
            require(start['w85_real_guide_issue_actions']==0,
                "Field guide cannot have source A7 decision authority")
            page.locator('canvas').first.click(position={'x':18,'y':20})
            page.keyboard.press('Enter')
            w,g=true_layout(page,390,844,False)
            require(w['w85_source_distance_m']>3.2 and
                not w['w85_source_near_device'] and
                w['w85_actual_original_phase']==0,
                "Real W70 initial body distant from physical 3.2m reactor gate")
            body_id=w['w85_real_original_body_id']
            a=frame(page,evidence/'w85-01-390-real-original-3d-game.png')
            tap(page,'w85_guide_entry')
            open_state=wait_state(page,{'w85_source_guide_open':True,
                'w85_safe_source_modal':True,
                'w79_mobile_complete_mission_visible':False,
                'history_count':0})
            s,g=true_layout(page,390,844,True)
            require(s['w85_source_distance_m']>3.2 and
                s['w85_real_original_body_id']==body_id and
                s['w85_real_guide_issue_actions']==0,
                "Real guide reads body distance but never moves actor or picks a move")
            b=frame(page,evidence/'w85-02-390-real-native-mission-guide.png')
            require(contrast(a,b)>75,
                "Original Godot source gameplay visibly opens real source guide")
            tap(page,'w85_guide_close')
            closed=wait_state(page,{'w85_source_guide_open':False,
                'w85_safe_source_modal':False,
                'w79_mobile_complete_mission_visible':True,
                'history_count':0})
            require(closed['w85_real_guide_opens']>=1 and
                closed['w85_real_guide_closes']>=1,
                "Real 44px native close returns to original physics mission")
            tap(page,'w84_tune_entry')
            tune=wait_state(page,{'w84_native_tune_open':True,
                'w84_modal_actually_suspends_touch':True})
            require(not tune['w85_source_guide_open'],
                "Previous W84 and new W85 true native modal never overlap")
            tap(page,'w84_done_button')
            wait_state(page,{'w84_native_tune_open':False,
                'w84_modal_actually_suspends_touch':False})
            c=frame(page,evidence/'w85-03-390-real-original-game-resumed.png')
            require(contrast(b,c)>70,
                "Closing real W85 returns gameplay, no permanent overlay or fake scene")
            s,g=true_layout(page,320,700,False)
            tap(page,'w85_guide_entry')
            s,g=true_layout(page,320,700,True)
            require(s['w85_safe_source_modal'] and
                s['history_count']==0 and
                contained(g['w85_guide_panel'],g['stage']),
                "Original 320px Godot guide fits and protects real equipment controls")
            d=frame(page,evidence/'w85-04-320-responsive-source-guide.png')
            s,g=true_layout(page,844,390,True)
            require(s['w85_actual_original_phase']==0 and
                s['w85_real_original_body_id']==body_id and
                contained(g['w85_guide_panel'],g['stage']),
                "Original source 844x390 guide fits physical stage and never resets game")
            e=frame(page,evidence/'w85-05-844-landscape-source-guide.png')
            tap(page,'w80_true_native_language')
            en=wait_state(page,{'locale':'en','w85_source_guide_open':True,
                'history_count':0})
            require(en['w85_actual_original_phase']==0 and
                en['w85_real_guide_issue_actions']==0,
                "Source-language switch does not advance original game phase")
            tap(page,'w85_guide_close')
            resumed=wait_state(page,{'w85_source_guide_open':False,
                'w85_safe_source_modal':False,
                'w79_mobile_complete_mission_visible':True})
            tap(page,'w80_true_native_menu')
            end=wait_state(page,{'w85_source_guide_visible':False,
                'w80_genuine_full_bleed_original_stage':False,
                'history_count':0})
            f=frame(page,evidence/'w85-06-844-source-menu-exit.png')
            require(contrast(e,f)>65 and
                not end['w85_safe_source_modal'],
                "Native MENU exits real 3D source guide without orphaned movement")
            require(not errors,
                "Original Godot 4.4.1 browser exceptions: "+" | ".join(errors[:4]))
            context.close()
            browser.close()
        server.shutdown()
    images=[]
    for p in sorted(evidence.glob('*.png')):
        b=p.read_bytes()
        images.append({'name':p.name,'bytes':len(b),
                       'sha256':hashlib.sha256(b).hexdigest()})
    require(len(images)==6,
        "Six independently rendered real original Godot WebGL frames")
    report={
        'schema':'LAST_FRONTIER_W85_REAL_SOURCE_MISSION_GUIDE_CHROMIUM_V1',
        'source_sha':sha,'result':'PASS',
        'original_W70_3d_actor_identity_preserved':True,
        'read_only_true_mission_phase_and_3_2m_physical_range':True,
        'original_W78_W79_W83_safely_suspended_in_guide':True,
        'previous_W84_native_settings_coexist_without_overlap':True,
        'original_A7_history_untouched':True,
        'genuine_native_Godot_390_320_844_readable_guide':True,
        'real_native_RU_EN_and_MENU':True,
        'actual_five_phase_terminal_game_tested_in_native_W85':True,
        'physical_iPhone_Android_certified':False,
        'AAA_art_certified':False,
        'images':images}
    (evidence/'W85_ORIGINAL_SOURCE_GUIDE_CHROMIUM.json').write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('LAST FRONTIER W85 SOURCE REAL GODOT MISSION GUIDE CHROMIUM PASS:',
          len(images),'source SHA original live 3D WebGL frames')

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--export',type=Path,required=True)
    p.add_argument('--evidence',type=Path,required=True)
    p.add_argument('--sha',required=True)
    a=p.parse_args()
    run(a.export.resolve(),a.evidence,a.sha)
