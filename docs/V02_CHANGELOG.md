# Gitgud: Cycle — v0.2

This update extends the existing v0.1 project and the `upload assets` commit. The arena, InputMap controls, damage/posture rules, stances, phase thresholds, intro, death counter, retry, and ending remain in place.

## Movement

The old dodge lasted 260 ms, travelled about 69 pixels before additional friction drift, and retained its high horizontal velocity at the end. The new dodge moves **46 pixels in 133 ms**, applies its full ~345 px/s immediately, locks its direction, and sets horizontal velocity to zero at the endpoint. It has **110 ms invulnerability**, **50 ms recovery**, and a **340 ms cooldown**. A clamped final integration step avoids extra distance from physics tick rounding.

Ground acceleration is 1800 px/s² and stopping friction is 2100 px/s². Air acceleration/friction are separate. Jump height is exposed directly (42 px at full hold), while early-release height control, 120 ms jump buffering, and 90 ms coyote time remain. Landing has a brief visual reaction and no new control lock.

Attack buffering remains 160 ms. Parry/dodge can now buffer for the final 100 ms of an existing recovery; they never cancel committed startup/active/recovery. Early inputs expire. Light/heavy startup is 100/250 ms in Assault; the meaningful 190/310 ms recoveries are retained.

## Supplied sprites

All twelve supplied sheets are integrated using `AnimatedSprite2D` / `SpriteFrames`. Sheet metadata lives in `assets/characters/animations.json`. The loader handles horizontal strips, 3×3 grids, blank cells, different cell sizes, solid-color keys, integer reduction, and per-sheet feet anchors. PNG originals remain unchanged. The procedural character drawing has been replaced; lightweight weapon and feedback effects remain code-drawn.

Jump/fall/landing use verified sections of the supplied jump sheet. Authored boss-slash phases follow gameplay timing. Missing states use an existing pose from the same character with temporary **F3** labels, enabled by default in development and disabled in release. Detailed availability and follow-up art are in [ANIMATION_STATUS.md](ANIMATION_STATUS.md).

## Boss decisions and pressure

Fixed repeating patterns are replaced with weighted choices based on range, phase, observed height, and recent attacks. The boss never queries player input. Short attacks are excluded out of range; long-range attacks gain weight at distance. Recent moves are penalized, and a third identical consecutive attack is excluded. Normal gameplay randomizes its RNG; tests and tuning can set a seed.

Branches are chosen **after the full recovery**, with no guaranteed continuation. Slash can lead to thrust or delayed heavy; overhead can lead to recall; sweep can lead to recall; thrust can reset spacing before a slash. Every follow-up has a fresh, full anticipation and locked facing. Parries and phase changes cancel queued branches.

| Phase | Approach pressure multiplier | Follow-up probability | Maximum attacks per sequence |
| --- | --- | --- | --- |
| Duel | 1.00 | 35% | 2 |
| Recognition | 1.20 | 65% | 3 |
| Inheritance | 1.42 | 85% | 4 |

Branch probabilities are upper bounds: distance, allowed moves, and sequence caps can also end a combo. Idle pauses vary within a short range and shrink with phase aggression. Backsteps respect arena edges. Recovery windows and the original readable startup floors remain; intensity comes from choices and positioning as well as cadence.

## Feedback

Fourteen synthesized effects now distinguish light/heavy contact, ordinary/major boss hits, perfect/failed parries, light/heavy swings, dodge, posture break, landing, stance and phase cues. Impacts add a short metallic ring and shaped transient rather than relying on volume alone.

Hit-stop is configurable by event: light 28 ms, heavy 52 ms, ordinary boss 40 ms, major boss 60 ms, parry 65 ms, posture break 85 ms. Effects include directional sparks, short clash flashes, stronger break rings, trails aligned with weapon areas, dash afterimages, and small boss recoil during punishable states. Failed-parry cues do not freeze combat.

## Tuning map

| Concern | Location / parameters |
| --- | --- |
| Speed / stopping / air control | `scripts/player.gd`: `run_speed`, `acceleration`, `ground_friction`, `air_acceleration`, `air_friction` |
| Dash | `dodge_distance`, `dodge_duration`, `dodge_invulnerability`, `dodge_recovery`, `dodge_cooldown` |
| Jump | `jump_height`, `gravity`, `coyote_window`, `jump_buffer_window` |
| Buffering | `action_buffer_window`, `defense_buffer_window` |
| Player strikes | `light_startup`, `heavy_startup`, `light_recovery`, `heavy_recovery`, posture variables and `begin_attack` data |
| Parry | Player window, recovery and posture exports; boss `parry_stun`, `stagger_duration` |
| Boss decisions | `scripts/boss.gd`: `phase_aggression`, `attack_selection_weights`, `repetition_penalty`, `combo_frequency`, `max_combo_attacks`, `followup_weights`, `decision_seed` |
| Boss attack timing / geometry | Boss `attacks` dictionary, phase factors in `begin_attack` |
| Hit-stop / shake | `scripts/game.gd`: `hitstop_durations`, `hitstop_scale`, `shake_strength` |
| Sprites / poses / FPS | `assets/characters/animations.json` |

## Verification performed

`python3 tools/check.py` passes **97 assertions plus a full input-driven duel** on Godot 4.6.3 / Linux:

- Existing combat, timing, and complete-loop checks are retained. The old fixed-pattern structural assertion now checks phase combo limits/frequency; the audio inventory assertion reflects the new effect set.
- Ten movement checks verify immediate dash speed, direction lock, exact distance, sharp stopping, friction, buffered defense, commitment, and invulnerability expiry.
- Nineteen animation checks verify all supplied sheets, transparency, integer scale, actual playback, orientation, anchoring, phase synchronization, and F3 fallback behavior.
- Thirteen boss checks verify range-aware choices, variation, repetition avoidance, alternative endings, finite combos, directional commitment, full recovery, actual branching, cancellation and phase escalation.
- Seven feedback checks verify distinct waveforms, directed sparks, stronger heavy/parry/break feedback, real contact recoil, and failed-parry behavior.
- Three real-time audio checks validate PCM generation, playback start and completion.
- The full-duel agent uses ordinary movement, strikes, parries and dodges, with RNG seed 713. It encounters all six attacks and defeats all phases without changing health, damage or invulnerability. Presentation hit-stop is separately tested.

Real graphical runs use the Compatibility renderer under Xvfb/Mesa. The capture script stages title, live sprite poses, slash, dash, parry, phase three, labels hidden, and defeat for inspection; captures live in `docs/screenshots/v02/`. These are actual renderer outputs, not mockups or evidence of a human balance playtest.

## Remaining problems / limits

- Dedicated Challenger attack art and five boss attack animations are still missing. Fallback poses plus timing markers and effects are functional, but cannot convey authored sword motion as clearly as complete sheets.
- Idle stance poses, parry-success reaction, and boss hurt/stagger/phase reactions remain missing; see the inventory. Some listed boss states are intentionally not part of its mechanics.
- Supplied color-key sheets should ideally be re-exported with true alpha. Grid sheets already have alpha; the original files are preserved.
- The Challenger's detail is reduced at half source resolution to preserve the existing 480×270 composition and boss size relationship. Art scale and the very fast dash sequence need human review.
- Native Windows execution, integrated-GPU performance, subjective audio quality, and difficulty have not been human-tested here. A deterministic perfect-timing bot proves the fight remains winnable, not that balancing is finished.
- No new enemies, levels, progression, controller support, music, or save system were added.
