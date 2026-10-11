# Controls and combat reference

**Enter** starts. **Tab** or **Enter** skips dialogue. **Esc** pauses. **M** toggles sound. **F3** toggles missing-animation labels in development builds.

| Action | Key | Detail |
| --- | --- | --- |
| Move | A / D | Accelerates on the floor; can steer in the air |
| Jump | Space | 120 ms buffer, 90 ms coyote window; early release cuts height |
| Light strike | J | Assault: 100 ms startup, 100 ms active, 190 ms recovery |
| Heavy strike | K | Assault: 250 ms startup, 100 ms active, 310 ms recovery |
| Parry | L | Facing matters; press shortly before a gold attack lands |
| Dodge | Shift | 46 px in 133 ms, first 110 ms invulnerable, 50 ms recovery, 340 ms between starts |
| Stance | Q | Can switch responsively during other actions |
| Retry | R | After death or once CYCLE COMPLETE is visible |

**Assault:** 108 px/s top speed, full strike damage, 85 ms parry window.

**Guard:** 86% movement speed, 20% longer attack startup/recovery, 85% damage, 160 ms parry window, 35% less incoming posture. The next 65 ms of a late frontal parry guards eligible attacks for 20% health damage. Later recovery is fully vulnerable.

A successful parry interrupts a parryable attack and cancels the rest of that combo, adds 31 boss posture, and restores 18 player posture. Failed parry commits for 400 ms; a success recovers in 220 ms. Holding the button does not repeatedly parry. The boss's two violet chain attacks bypass both parry and guard.

Attack inputs buffer for 160 ms. Parry/dodge buffer for 100 ms at the end of recovery; they do not cancel it. A full jump rises about 42 pixels. Movement, another attack, a jump, or a dodge cannot cancel attack recovery. You can change stance at any time while alive. A hit normally grants the player 520 ms damage immunity to prevent overlapping active frames from stacking.

Health bars deplete; posture bars **fill toward a break**. Posture recovers after a quiet interval. A boss break provides a two-second opening and 1.5× incoming damage. A player break stuns for 950 ms.

All defaults use Godot InputMap actions. To remap without changing scripts, add the corresponding action (`move_left`, `move_right`, `jump`, `light`, `heavy`, `parry`, `dodge`, `stance`, `retry`, `pause`, `confirm`, `skip`, `mute`, `animation_debug`) in Project Settings → Input Map. Existing actions are preserved.
