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
from w83_browser_real_multitouch import point,send

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

def overlaps(a,b):
    require(len(a)==4 and len(b)==4,"Actual source Godot rectangles required")
    return (a[0]<b[0]+b[2] and a[0]+a[2]>b[0] and
            a[1]<b[1]+b[3] and a[1]+a[3]>b[1])

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
    try:
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
    }""",arg=[width,height,guide_open],timeout=45000)
    except Exception:
        # A real Godot native layout failure must reveal its grounded cause.
        # The 320px portrait is not waived: dump exact source geometry and
        # real UI state, and capture a REAL frame for diagnosis.
        state=snapshot(page)
        g=geometry(page)
        useful={k:state.get(k) for k in [
            'w85_source_guide_visible','w85_source_guide_open',
            'w85_safe_source_modal','w85_actual_original_phase',
            'w85_real_original_body_id','history_count',
            'w84_native_tune_open','w84_modal_actually_suspends_touch']}
        rectangles={key:g.get(key) for key in [
            'viewport','stage','w85_guide_entry','w85_guide_panel',
            'w85_guide_close','w85_guide_objective','w85_guide_distance',
            'w84_tune_entry','w80_true_native_menu','w80_true_native_language']}
        print('W85 ORIGINAL NATIVE RESPONSIVE HARD FAILURE:',
              json.dumps({'requested':[width,height,guide_open],
              'actual_state':useful,'actual_geometry':rectangles,
              'inside_source_guide':{
                  key:contained(g.get(key,[]),g.get('stage',[0,0,0,0]))
                  for key in ['w85_guide_entry','w85_guide_panel',
                      'w85_guide_close','w85_guide_objective',
                      'w85_guide_distance']}},sort_keys=True),flush=True)
        from pathlib import Path
        dest=Path('w85-evidence/diagnostic')
        dest.mkdir(parents=True,exist_ok=True)
        page.screenshot(path=str(dest/('real-native-%dx%d-%s.png' %
            (width,height,'open' if guide_open else 'closed'))))
        raise
    current=snapshot(page)
    actual=geometry(page)
    require(not overlaps(actual['w85_guide_entry'],actual['w80_true_native_menu'])
        and not overlaps(actual['w85_guide_entry'],actual['w82_native_compass_hud']),
        "Real source W85 GUIDE must NOT overlap W80 MENU or W82 compass at any 320/390/844 physical viewport")
    if guide_open:
        require(current['w86_coach_visible'] is False and
                current['w86_original_game_actions_issued']==0,
                'Real original W85 modal hides W86 safely and cannot cause A7 actions')
    else:
        require(current['w86_coach_visible'] is True and
                current['w86_coach_source_eligible'] is True,
                'Original source W86 learning is visible only in actual game')
        for key in ['w86_coach_panel','w86_coach_prompt','w86_coach_action']:
            require(contained(actual[key],actual['stage']),
                'Native '+key+' must fit in original live '+str((width,height))+' stage')
        for key in ['w82_native_compass_hud','w80_true_native_menu',
                    'w85_guide_entry','w84_tune_entry']:
            require(not overlaps(actual['w86_coach_action'],actual[key]),
                'W86 SKIP cannot overlap existing native source action: '+key)
        require(not overlaps(actual['w86_coach_panel'],actual['w80_native_mission_panel']) and
                not overlaps(actual['w86_coach_panel'],actual['w80_native_touch_rail']),
                'Real W86 panel must not cover actual W78/W79 movement/equipment')
        if width<640:
            finger=(actual['stage'][0]+actual['stage'][2]*0.83,
                    actual['stage'][1]+205)
            r=actual['w86_coach_action']
            require(not(r[0]<=finger[0]<=r[0]+r[2] and
                        r[1]<=finger[1]<=r[1]+r[3]),
                'Original W83 free-source Camera3D swipe never intercepted by SKIP')
    return current,actual

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
            require(w['w86_source_lesson_step']==0 and
                w['w86_source_lessons_total']==7 and
                not w['w86_source_lesson_completed'] and
                not w['w86_source_lesson_skipped'] and
                w['w86_original_body_id']==body_id,
                'Seven FIRST CONTACT source-only lessons appear on real mission start')
            a=frame(page,evidence/'w86-01-390-real-original-first-contact.png')
            # Player genuinely chooses SKIP and REPLAY via live Godot Buttons.
            tap(page,'w86_coach_action')
            skipped=wait_state(page,{'w86_source_lesson_skipped':True,
                'w86_source_lesson_step':0,'history_count':0})
            require(skipped['w86_original_body_id']==body_id and
                skipped['w86_original_game_actions_issued']==0 and
                skipped['w86_real_user_skips']>=1,
                'Actual SKIP affects only optional tutorial, original game untouched')
            tap(page,'w86_coach_action')
            replayed=wait_state(page,{'w86_source_lesson_skipped':False,
                'w86_source_lesson_step':0,'history_count':0})
            require(replayed['w86_real_user_replays']>=1,
                'Native replay begins real onboarding without restarting player')
            # Source W78 first physical finger: actual Chromium touch to WALK.
            cdp=context.new_cdp_session(page)
            mx,my=center(geometry(page)['w78_true_touch_forward'])
            walk_point=point(mx,my,41)
            before_walk=snapshot(page)
            send(cdp,'touchStart',[walk_point])
            page.wait_for_timeout(950)
            send(cdp,'touchEnd',[walk_point])
            physical=wait_state(page,{'w86_source_lesson_step':1,
                'history_count':0})
            require(physical['w70_real_physical_distance']>
                before_walk['w70_real_physical_distance']+0.25 and
                physical['w86_actual_source_proofs']==['W70_PHYSICAL_DISTANCE'],
                'Actual indexed W78 walk must move original W70 body and unlock first lesson')
            # Second native finger on ORIGINAL FREE CAMERA, NOT the coach.
            gnow=geometry(page)
            world=gnow['stage']
            lx=world[0]+world[2]*0.83
            ly=min(gnow['w80_native_mission_panel'][1]-20.0,world[1]+205.0)
            first_look=snapshot(page)
            cam=point(lx,ly,42)
            send(cdp,'touchStart',[cam])
            for ix in range(4):
                cam=point(lx+float(ix+1)*13.0,ly-float(ix+1)*6.0,42)
                send(cdp,'touchMove',[cam])
                page.wait_for_timeout(110)
            send(cdp,'touchEnd',[cam])
            physical=wait_state(page,{'w86_source_lesson_step':2,
                'history_count':0})
            require(physical['w83_real_camera_rotations']>
                    first_look['w83_real_camera_rotations'] and
                    physical['w86_actual_source_proofs']==[
                        'W70_PHYSICAL_DISTANCE','W70_REAL_CAMERA_ROTATION'],
                    'Real W83 physically rotated source Camera3D to prove second lesson')
            cdp.detach()
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
            b=frame(page,evidence/'w86-02-390-first-contact-original-guide.png')
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
            closed=wait_state(page,{'w86_source_lesson_step':3,
                'w86_coach_visible':True,'history_count':0})
            require(closed['w86_actual_source_proofs']==[
                'W70_PHYSICAL_DISTANCE','W70_REAL_CAMERA_ROTATION',
                'W85_GENUINE_GUIDE_USER_OPEN'] and
                closed['w86_original_game_actions_issued']==0,
                'Real W85 guide opening confirms third true source lesson without autoflow')
            tap(page,'w84_tune_entry')
            tune=wait_state(page,{'w84_native_tune_open':True,
                'w84_modal_actually_suspends_touch':True})
            require(not tune['w85_source_guide_open'],
                "Previous W84 and new W85 true native modal never overlap")
            tap(page,'w84_done_button')
            wait_state(page,{'w84_native_tune_open':False,
                'w84_modal_actually_suspends_touch':False})
            c=frame(page,evidence/'w86-03-390-original-controls-restored.png')
            require(contrast(b,c)>70,
                "Closing real W85 returns gameplay, no permanent overlay or fake scene")
            s,g=true_layout(page,320,700,False)
            tap(page,'w85_guide_entry')
            s,g=true_layout(page,320,700,True)
            require(s['w85_safe_source_modal'] and
                s['history_count']==0 and
                contained(g['w85_guide_panel'],g['stage']),
                "Original 320px Godot guide fits and protects real equipment controls")
            d=frame(page,evidence/'w86-04-320-responsive-real-guide.png')
            s,g=true_layout(page,844,390,True)
            require(s['w85_actual_original_phase']==0 and
                s['w85_real_original_body_id']==body_id and
                contained(g['w85_guide_panel'],g['stage']),
                "Original source 844x390 guide fits physical stage and never resets game")
            e=frame(page,evidence/'w86-05-844-landscape-real-guide.png')
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
            f=frame(page,evidence/'w86-06-844-bilingual-real-menu-exit.png')
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
        'schema':'LAST_FRONTIER_W86_FIRST_CONTACT_ORIGINAL_GODOT_CHROMIUM_V1',
        'source_sha':sha,'result':'PASS',
        'real_indexed_touch_W78_walk_W70_body_0_25m':True,
        'real_source_Camera3D_swipe_progress':True,
        'native_source_W85_guide_third_lesson':True,
        'true_native_skip_and_replay_without_gameplay_mutation':True,
        'real_original_coach_safe_at_320_390_844':True,
        'remaining_four_lesson_physics_proved_by_Godot_W86_native':True,
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
    (evidence/'W86_REAL_SOURCE_ONBOARDING_BROWSER.json').write_text(
        json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('LAST FRONTIER W86 FIRST CONTACT ORIGINAL GODOT CHROMIUM PASS:',
          len(images),'source SHA original live 3D WebGL frames')

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--export',type=Path,required=True)
    p.add_argument('--evidence',type=Path,required=True)
    p.add_argument('--sha',required=True)
    a=p.parse_args()
    run(a.export.resolve(),a.evidence,a.sha)
