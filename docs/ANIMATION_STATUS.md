# Animation status — v0.2

All **12 supplied PNG sheets** are used. Original PNGs are unchanged. Combat still controls hitboxes and timing; `AnimatedSprite2D` presents the corresponding frames. Missing art never disables an action.

Layout, timing, anchors, color keys, source orientation, and fallbacks are configured in [`assets/characters/animations.json`](../assets/characters/animations.json). An asset is only considered available when its texture loads successfully. Fallback resolution is explicit in `scripts/animation_library.gd`.

## Verified source inventory

Paths below are relative to `assets/characters/[character]/animations/`. Frames are numbered from **zero**, read left-to-right, then top-to-bottom.

| Character / file | Sheet | Cells / used frames | Handling |
| --- | --- | --- | --- |
| Challenger `chally_idle.png` | 512×64 | 64×64 / 8 | Remove solid lavender key at runtime |
| Challenger `chally_walk.png` | 512×64 | 64×64 / 8 | Existing alpha |
| Challenger `chally_parry.png` | 512×64 | 64×64 / 8 | Remove solid lavender key at runtime |
| Challenger `chally_death.png` | 512×64 | 64×64 / 8 | Remove solid lavender key at runtime |
| Challenger `chally_dash.png` | 192×192 | 64×64 / first 8 | Existing alpha; ninth cell is empty |
| Challenger `chally_hurt.png` | 192×192 | 64×64 / first 8 | Existing alpha; ninth cell is empty |
| Challenger `chally_stumble.png` | 192×192 | 64×64 / first 8 | Existing alpha; ninth cell is empty |
| Challenger `chally_jump.png` | 240×240 | 80×80 / first 8 | Existing alpha; rise 0–4, fall 5–6, landing 7 |
| Boss `boss_idle.png` | 464×58 | 58×58 / 8 | Remove solid teal key at runtime |
| Boss `boss_walk.png` | 464×58 | 58×58 / 8 | Remove solid teal key at runtime |
| Boss `boss_swordslash_basic.png` | 512×64 | 64×64 / 8 | Remove solid teal key at runtime |
| Boss `boss_defeat.png` | 512×64 | 64×64 / 8 | Remove solid teal key at runtime |

The apparently patterned backgrounds in several grid sheets are RGB data under **zero alpha**, not visible artwork. They remain transparent. Flat-color sheets specify their actual background RGB in the manifest with a 12/255 channel tolerance. Transparent re-exports would eliminate the need for color keying and avoid ambiguity if future costume colors match a key.

## Challenger states

| State | Asset status | Current presentation / fallback | Follow-up |
| --- | --- | --- | --- |
| Idle | **Integrated** `chally_idle.png` | 8-frame loop | None required |
| Walk | **Integrated** `chally_walk.png` | 8-frame loop | Review speed against movement during playtest |
| Jump | **Integrated section** `chally_jump.png` 0–4 | Non-looping rise; holds last frame | Dedicated rise sheet optional |
| Fall | **Integrated section** `chally_jump.png` 5–6 | Falling poses, holds last frame | Dedicated falling loop optional |
| Landing | **Integrated section** `chally_jump.png` 7 | Brief authored landing pose; no input lock | More landing frames optional |
| Dash | **Integrated** `chally_dash.png` | All 8 frames driven by dash distance/time; last pose in recovery | Review compressed timing at 133 ms |
| Light attack | **Missing** | Frozen parry frame 2 + gameplay slash trail | Supply light-attack sheet and startup/contact/recovery markers |
| Heavy attack | **Missing** | Frozen parry frame 4 + heavier trail/feedback | Supply heavy-attack sheet and timing markers |
| Parry | **Integrated** `chally_parry.png` | Frames 0–3 during window, 4–7 during recovery | Refine artist timing markers if desired |
| Parry success | **Missing dedicated reaction** | Frozen parry frame 5 + clash flash and sparks | Supply success reaction |
| Hurt | **Integrated** `chally_hurt.png` | 8 frames synchronized with short hitstun | None required |
| Stagger | **Integrated** `chally_stumble.png` | 8 frames synchronized with posture-break stun | None required |
| Death | **Integrated** `chally_death.png` | Plays once, holds final frame | None required |
| Offensive stance | **Missing dedicated pose** | Idle loop; gold HUD/foot indicator | Supply stance idle loop |
| Defensive stance | **Missing dedicated pose** | Idle loop; cyan HUD/foot indicator | Supply stance idle loop |
| Stance transition | **Missing** | Idle frame 0 + stance cue | Supply short transition |

The genuine idle loop plays on the title screen, during stationary cinematics, and as the stance fallback. Standing in active combat requests the appropriate stance pose and therefore correctly shows a missing label until stance art is supplied.

## Former Victor states

| State | Asset status | Current presentation / fallback | Follow-up |
| --- | --- | --- | --- |
| Idle | **Integrated** `boss_idle.png` | 8-frame loop | None required |
| Walk / approach / reposition | **Integrated** `boss_walk.png` | 8-frame loop; backsteps retain facing | Dedicated backstep optional |
| Jump | **Missing; no boss jump mechanic** | Idle pose if requested | Optional future art; no new mechanic added |
| Fall | **Missing; no boss aerial mechanic** | Idle pose if requested | Optional |
| Landing | **Missing; no boss landing action** | Idle pose if requested | Optional |
| Dash | **Missing; no boss dash action** | Idle pose if requested | Optional |
| Generic light attack | **Missing; named attacks used instead** | Sword-slash frame 2 if requested | Optional |
| Generic heavy attack | **Missing; named attacks used instead** | Sword-slash frame 2 if requested | Optional |
| Parry | **Missing; boss is parried rather than parrying** | Idle pose if requested | Optional |
| Parry success | **Missing; no boss parry action** | Idle pose if requested | Optional |
| Hurt / deflected | **Missing** | Idle frame 0, impact tint and recoil | Supply hit/deflection reaction |
| Stagger | **Missing** | Idle frame 0 + break flash/HUD cue | Supply posture-break stagger |
| Death | **Integrated** `boss_defeat.png` | Plays once, holds final frame | Review collapse readability; original poses preserved |
| Offensive stance | **Missing; no boss stance switch** | Idle pose if requested | Optional |
| Defensive stance | **Missing; no boss stance switch** | Idle pose if requested | Optional |
| Stance transition | **Missing; no boss stance switch** | Idle pose if requested | Optional |
| Horizontal slash | **Integrated** `boss_swordslash_basic.png` | Startup 0–2, active 3–5, recovery 6–7 | Refine contact markers after art playtest |
| Overhead strike | **Missing** | Sword-slash frame 2 + overhead hit area and gold tell | Supply overhead sheet |
| Forward thrust | **Missing** | Sword-slash frame 2 + narrow thrust streak and gold tell | Supply thrust sheet |
| Chain sweep | **Missing** | Sword-slash frame 2 + low chain, violet tell and hit area | Supply sweep sheet |
| Delayed heavy | **Missing** | Sword-slash frame 2 + long tell and heavy effects | Supply delayed-heavy sheet |
| Chain recall | **Missing** | Sword-slash frame 2 + returning chain and violet tell | Supply recall sheet |
| Phase 2 transition | **Missing** | Idle frame 0 + Recognition banner, mural and lighting change | Supply recognition reaction |
| Phase 3 transition | **Missing** | Idle frame 0 + Inheritance banner, mural and lighting change | Supply inheritance reaction |

## Scale, alignment, timing, and labels

- Challenger art is reduced by an **integer factor of two** using nearest-neighbor once on first load. Its roughly 59-pixel body becomes about 30 native game pixels. Boss art stays 1:1, about 55 pixels tall. Sprite node scale stays `(1,1)` during combat. The existing ending deliberately grows the Challenger vertically as part of the transformation.
- Anchors are fixed per sheet, never inferred per frame: Challenger `(32,62)` or `(40,78)` before reduction; boss `(29,57)` for 58-pixel cells and `(32,60)` for 64-pixel cells. This preserves intentional pose movement while keeping standing feet aligned.
- Both supplied characters face left. Facing right mirrors the sprite and its anchor; physics direction remains independent.
- Attack segments are sampled from gameplay `state_time` and the configured startup/active/recovery durations. Increasing phase tempo does not desynchronize attack frames. Fallback poses never change damage, collision, or commitment.
- **F3** toggles `[ANIM MISSING: STATE]` on both fighters, including while paused. The setting survives retries. Labels default on in debug/editor builds and off in release builds; F3 is inactive in release builds.
- For new art, add or update an `animations` entry with the actual `file`, `cell`, `count`, `anchor`, `fps`, `loop`, and optional frame `indices`/phase `segments`. Remove a color key for true-alpha exports. No frame count is assumed by gameplay scripts.

Priority art gaps: Challenger light/heavy attacks, then the boss's five missing attacks, then posture/parry reactions and stance poses. All actions remain playable with clearly identified fallbacks.
