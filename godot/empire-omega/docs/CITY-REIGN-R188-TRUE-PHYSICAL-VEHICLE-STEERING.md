# CITY REIGN R188 — TRUE PHYSICAL STEERING AND CORNER TRACKING

Parent R187 exact \`a356873cb08840d72bbcc08b19b4a35fa41c2211\` was independently SUCCESS in full native Godot 4.4.1, original 40 missions/physics/save, true WebGL2 and real Chromium desktop/mobile-sized input/camera and source SHA (2/2 independent CI). Production SSH remains unchanged.

## Critical source driving defect repaired
R185 placed all 12 actual 4.1m-long, 2.25m-wide colliding native NPCs in separate +2m **right-hand asphalt lanes**, while R186 handled physically boxed exits and cross traffic. But original \`TrafficAgent._physics_process\` still updated \`rotation.y\` via a smooth \`lerp_angle\` **and simultaneously snapped the entire native physics velocity instantly toward the next waypoint**. At 90-degree corners, the visible 3D car body was visually sliding sideways relative to its true CharacterBody3D movement. This is not GTA-quality road handling.

## Source block A — actual native 3D motion now follows physical chassis yaw
- New pure finite-safe \`city_reign_physical_corner_steering.gd\` computes a short lookahead **on the ORIGINAL R185 true +2m source road** before a real ~90-degree turn, without removing/changing original A* stops or cutting between buildings. No lookahead on straight segments, U-turns, impossible turns, non-finite routes or off-road endpoints. Corner waypoints remain original.
- The car's true \`CharacterBody3D.velocity\` is now derived from the SAME yaw used to rotate its existing mesh. Rotation is capped in radians/second, with additional actual **wet grip / speed-dependent lateral acceleration** limits. A fast or rain-wet car cannot instantly rotate 90° in one physics tick or glide sideways. Initial 12 civilian NPCs spawn facing their real first route segment.
- Original four wheel meshes are reused: the TWO existing front wheels articulate around their own up axis at the actual bounded steering command, before all 4 continue their original rolling spin. No new meshes, nodes, sprite replacements or art assets.
- The real original BoxShape3D is 2.25m wide. A *centre point* still inside the road can have the BODY off asphalt. R188 checks the future movement footprint with a conservative original 10m source road half-width and existing R185 mesh graph. If physical source motion would leave valid pavement, car **stops** rather than teleporting or cutting through original geometry. All 12 original NPC physical colliders remain; existing pursuit/patrol off-road AI is deliberately unchanged.

## Block B — original live game safety priorities preserved
- ALL original R163 car-following, R178 stop bar/red/amber phase law, R180 real pedestrian WALK/WAIT, R182 physical crossing occupation, R186 actual box clearance, true Godot physical raycast, R185 original closed roads/route planner, R184 existing 90kmh city law and wet \`TrafficSafety\` run unchanged before movement. A new vehicle turning rule never grants faster motion or automatic signal priority.
- The new source remains ONLY in the original native Godot \`TrafficAgent\` for non-patrol 12 cars; no manual player steering assist, route teleport, physics proxy, save mutation, tracking API or network asset.
- Existing original opt-in R183 LAB now aggregates **only** counts of actually observed physical front-wheel turns, road-edge safety rejections and the maximum observed front-wheel angle; never logs individual positions, routes, hardware IDs, raw controls or per-frame trajectory. Synthetically exercised unit fixtures must NOT be called a real phone FPS benchmark.

## Block C — three rigorous native original Godot regressions
- \`v213\` pure true source right-lane geometry and road *body* footprint, 90° physical lookahead, real wet yaw grip, exact visual yaw / physical vector equality, original no-U-turn/invalid/huge browser frame fail closed.
- \`v214\` actually loads the entire original \`main.tscn\`, verifies 12 native 3D colliding NPCs, 34 real residents, original 16 signal/marked junctions. An actual native \`CharacterBody3D\` turns at a true R185 source corner, its wheels visibly articulate, the speed vector aligns with the 3D chassis and the original full 2.25m physical footprint stays on actual pavement. Original economy/40 missions unchanged.
- \`v215\` private opt-in original 2Hz LAB now derives only real source style steering counts from native \`CharacterBody3D\`, excludes older fixture Node3Ds, never claims actual phone FPS.
- Inherit all R187–R169 strict Godot 4.4.1 full native 40-mission/saves/road law, WebGL2 export and genuine Chromium desktop/mobile-sized player drive/camera/source-SHA verification.

**Release gate**: two independent full CI SUCCESS on the same immutable latest commit, before marking accepted. DRAFT, production SSH untouched. No claim of actual physical phone performance, human playtest, professional autonomous-driving certification or GTA/Forza photorealism.
