# Gitgud: Cycle — codebase and tuning cheatsheet

Start here when you want to change how the game feels. Values below describe v0.2 after the facing fix. Example changes are suggestions; this document does not apply them to the game.

## 1. The three files you'll use most

| File | What it controls |
| --- | --- |
| [`scripts/player.gd`](../scripts/player.gd) | Challenger movement, dash, jump, light/heavy attacks, parry, and stance modifiers |
| [`scripts/boss.gd`](../scripts/boss.gd) | Boss HP, attacks, decision-making, combos, phase thresholds, and stagger |
| [`scripts/fighter.gd`](../scripts/fighter.gd) | Shared character foundation: starting health, posture, collision body, taking damage, death signals |

`Challenger` and `FormerVictor` both **extend `Fighter`**: they inherit its fields and functions and add their own behavior. A value overridden in the child wins over the shared default. For example, Fighter defaults to 100 max HP, but the boss sets its own max HP to 430.

There is **no strength, level, armor, or stamina stat**. To make the player stronger, adjust attack damage, posture damage, or survivability independently.

## 2. Quick lookup: “I want to…”

| Goal | File / search for | Current value | Direction to change |
| --- | --- | --- | --- |
| Increase player sword damage | `player.gd` → `begin_attack` → `"damage"` | Light **11**, heavy **23** | Increase these numbers |
| Decrease boss HP | `boss.gd` → `_init` → `max_health` | **430** | Lower it |
| Change player starting HP | `fighter.gd` → exported `max_health` | **100** | Higher = more survivable; boss overrides this default |
| Reduce incoming damage | `boss.gd` → `attacks` → each `damage` | **20–35**, depending on attack | Lower selected attacks |
| Make player attacks break posture faster | `player.gd` → `light_posture_damage`, `heavy_posture_damage` | **9**, **19** | Increase |
| Make parries break boss posture faster | `player.gd` → `parry_posture_damage` | **31** | Increase |
| Make boss posture easier to break | `boss.gd` → `_init` → `max_posture` | **100** | Lower |
| Move faster | `player.gd` → `run_speed` | **108 px/s** | Increase |
| Stop more sharply | `player.gd` → `ground_friction` | **2100 px/s²** | Increase |
| Dash farther | `player.gd` → `dodge_distance` | **46 px** | Increase |
| Dash faster over the same distance | `player.gd` → `dodge_duration` | **0.1333 s** | Decrease |
| Dodge more frequently | `player.gd` → `dodge_cooldown` | **0.34 s** | Decrease |
| Make dodges more forgiving | `player.gd` → `dodge_invulnerability` | **0.11 s** | Increase, usually no longer than dash duration |
| Jump higher | `player.gd` → `jump_height` | **42 px** | Increase |
| Make parrying easier | `player.gd` → `offensive_parry_window`, `defensive_parry_window` | **0.085 / 0.16 s** | Increase |
| Give more time to punish the boss | `boss.gd` → attack `recovery` | Varies by attack | Increase |
| Make the boss combo less | `boss.gd` → `combo_frequency` | **[0.35, 0.65, 0.85]** | Lower entries |
| Limit combo length | `boss.gd` → `max_combo_attacks` | **[2, 3, 4]** | Lower entries |
| Reduce screen shake | `game.gd` → `shake_strength` | **1.0** | Lower; **0** turns it off |
| Reduce impact freezes | `game.gd` → `hitstop_durations` | Per-event seconds | Lower selected durations |
| Correct sprite facing | `assets/characters/animations.json` → `faces_right` | **true** for both | Describes the source art, not the current movement direction |

Numbers representing time are **seconds**: `0.10` = 100 ms, about 6 physics frames. Distances are native pixels in the **480×270** game, not the larger desktop window. Array entries for phase settings are always **[phase 1, phase 2, phase 3]**.

## 3. Exact examples: damage and HP

### Stronger player attacks

In `scripts/player.gd`, find `func begin_attack`. This expression sets attack damage:

```gdscript
"damage": (23.0 if heavy else 11.0) * (0.85 if defensive else 1.0),
```

The number **before `if heavy` is heavy damage**; the number **after `else` is light damage**. To make heavy attacks deal 30 and light attacks deal 16, replace only that expression with:

```gdscript
"damage": (30.0 if heavy else 16.0) * (0.85 if defensive else 1.0),
```

Keep the surrounding attack dictionary. Guard stance's `0.85` multiplier still applies. With the original values, Guard deals 9.35 light damage and 19.55 heavy damage. During a boss posture-break stagger, `boss.gd` multiplies incoming damage by **1.5** again. A normal parry deflection does not grant that damage bonus.

### Lower boss HP

In `scripts/boss.gd`, change the existing initialization:

```gdscript
func _init() -> void:
    is_boss = true
    max_health = 300  # Previously 430.
    max_posture = 100
```

The next fight starts at 300 HP. Phase thresholds use percentages, so they automatically move with max HP: phase 2 begins at 210 HP or less; phase 3 begins below 105 HP.

### Change player HP

The current player inherits this line in `scripts/fighter.gd`:

```gdscript
@export var max_health: float = 100.0
```

Changing it to `150.0` gives the player 150 starting HP. The boss still uses its explicit 430 override. This remains a **shared default**, so future characters inheriting Fighter would also receive it unless overridden.

For an explicitly player-only setting instead, add this line immediately after `player = Challenger.new()` in `game.gd` → `spawn_fighters`, **before** `world.add_child(player)`:

```gdscript
player.max_health = 150.0
```

Choose one place for your player HP setting; keeping both an override and an edited default can be confusing.

**Change `max_health`, not the initial `health` value.** `Fighter._ready()` sets `health = max_health` when a fighter enters the scene. `health` is the current, changing value during a fight. The HUD uses their ratio automatically.

## 4. Health versus posture

Health goes **down** toward death. Posture goes **up** toward a break, then resets. Increasing `max_posture` therefore makes a character harder to stagger.

| Mechanic | Where to tune it |
| --- | --- |
| Player posture capacity | `fighter.gd` → `max_posture` default; or `player.max_posture` before adding player to the world |
| Boss posture capacity | `boss.gd` → `_init` → `max_posture` |
| Posture added by strikes | Player `light_posture_damage` / `heavy_posture_damage`; boss attack `posture` fields |
| Posture added by a successful player parry | Player `parry_posture_damage` |
| Player posture relief on a parry | Player `receive_attack`, the subtraction of `18` |
| Posture regeneration | Fighter `tick_common`: 12/s normally, 22/s in Guard, after `posture_delay` expires and while in eligible states |
| Boss normal parry deflection | Boss `parry_stun = 0.44` seconds |
| Boss posture-break opening | Boss `stagger_duration = 2.0` seconds |
| Player posture-break opening | Player `receive_attack`, `stun_duration = 0.95` |
| Boss damage vulnerability during a break | Boss `receive_attack`, multiplier `1.5` |

Capacity and regeneration are different knobs. Lowering capacity gives quicker breaks; lowering regeneration lets posture pressure persist between attacks.

## 5. Movement, stance, and timing

Most movement values are `@export` variables at the top of `player.gd`.

| Parameter | Meaning |
| --- | --- |
| `acceleration = 1800` | How quickly movement reaches top speed |
| `ground_friction = 2100` | How quickly releasing movement stops the player |
| `air_acceleration = 760`, `air_friction = 320` | Separate steering and slowing while airborne |
| `gravity = 920` | Downward acceleration; jump launch speed is calculated from gravity and jump height |
| `jump_height = 42` | Full-held jump height; releasing Space early shortens the jump |
| `coyote_window = 0.09` | Time allowed to jump just after leaving the floor |
| `jump_buffer_window = 0.12` | How early a jump can be pressed before landing |
| `action_buffer_window = 0.16` | How early the next attack can be queued before becoming available |
| `defense_buffer_window = 0.10` | Equivalent short queue for parry/dodge |
| `dodge_recovery = 0.05` | Short commitment after dash movement stops |
| `light_startup = 0.10`, `heavy_startup = 0.25` | Delay before a sword hit can land |
| `light_recovery = 0.19`, `heavy_recovery = 0.31` | Commitment after the active strike |
| `parry_recovery = 0.40` | Total time committed by an unsuccessful parry |

Dash speed is calculated as **distance / duration**: 46 / 0.1333 ≈ 345 px/s. Duration and invulnerability are separate. Use a positive duration. Cooldown starts at dash initiation, so the earliest next dash is constrained by both cooldown and action recovery.

An attack proceeds through **startup → active → recovery → idle**. The player strike is active for 0.10 seconds, defined inside `begin_attack`. Reducing startup makes a strike arrive sooner. Reducing recovery makes it less punishable. Increasing sprite FPS alone does not do either for gameplay-synchronized animations.

Guard stance currently applies these modifiers in `player.gd`:

- Movement speed × **0.86** in the idle/movement branch.
- Strike damage × **0.85** and startup/recovery duration × **1.2** in `begin_attack`.
- Parry window **0.16 s**, versus Assault's **0.085 s**.
- Incoming posture × **0.65** in `receive_attack`.
- A slightly late frontal parry can guard eligible attacks for **20% health damage**; it is not a held block.

Taking a hit gives the player **0.52 seconds** of damage immunity (`receive_attack`). This is separate from dash invulnerability. Buffering does not cancel committed attack recovery.

## 6. Boss difficulty: four independent controls

**Fight length:** boss `max_health` and player attack damage.

**Mistake cost:** the `damage` values inside the boss's `attacks` dictionary.

| Attack ID | Current damage | Parryable? |
| --- | --- | --- |
| `slash` | 20 | Yes |
| `overhead` | 32 | Yes |
| `thrust` | 24 | Yes |
| `sweep` | 26 | No |
| `feint` | 35 | Yes |
| `recall` | 23 | No |

**Reaction difficulty:** per-attack `startup`, plus player parry/dodge windows. Boss `begin_attack` multiplies startup by **1.0 / 0.94 / 0.87** across phases; phase 3 recovery is also × **0.9**. Check both base timings and these multipliers when tuning later phases.

**Pressure:** movement, idle gaps, and branching.

```gdscript
@export var phase_aggression: Array[float] = [1.0, 1.20, 1.42]
@export var combo_frequency: Array[float] = [0.35, 0.65, 0.85]
@export var max_combo_attacks: Array[int] = [2, 3, 4]
```

Higher `phase_aggression` increases approach/reposition speed and reduces the gaps calculated in `finish_recovery`; it does not directly change sword startup. Lowering `combo_frequency` makes sequences stop more often. Keep three array entries. `max_combo_attacks` includes the opening attack.

`attack_selection_weights` changes relative preference, **not guaranteed probabilities**. For example, increasing `"thrust": 1.0` to `2.0` favors thrust, but range, phase, and recent attacks still matter. `followup_weights` describes which attack can follow another. A follow-up is selected only after recovery and still gets its own anticipation.

`decision_seed = 0` means randomized fights. Set a positive seed, such as `713`, before starting the game for repeatable tuning. The same inputs and circumstances are still needed to reproduce a whole duel.

Phase thresholds live in `_physics_process`: phase 2 at **≤70% HP**, phase 3 at **<35% HP**. Keep the phase-3 check first and lower than phase 2 when changing thresholds. Extreme damage buffs can jump over a phase; the current code selects the phase appropriate to the remaining HP.

For an easier art-playtesting session, try changing **one** knob first: boss HP 430→300, or player HP 100→150. Those reduce fight length or punishment without changing timing you are learning.

## 7. Sprites and animations

Source art is in `assets/characters/[character]/animations/`. The game reads [`assets/characters/animations.json`](../assets/characters/animations.json) to interpret it.

| Manifest field | Meaning |
| --- | --- |
| `file` | PNG filename inside that character's animation folder |
| `cell` | Width and height of one frame, not the entire sheet |
| `count` | Number of usable frames; excludes unused trailing cells |
| `indices` | Optional selected frame numbers, zero-based, row-by-row |
| `fps`, `loop` | Normal animation playback settings |
| `anchor` | Local origin/feet point in source pixels; keep consistent across sheets |
| `pixel_divisor` | Character-wide integer reduction: Challenger 2, boss 1 |
| `faces_right` | Whether the unflipped source art faces right; currently true for both |
| `color_key` | Solid background color removed at runtime; omit for true-alpha art |
| `segments` | Frame ranges tied to gameplay phases for supported synchronized animations |
| `fallbacks` | Existing animation to use when requested art is missing; `pose: -1` allows playback, otherwise freezes the specified frame |

`character_visual.gd` maps gameplay states to animation names. `animation_library.gd` loads and caches frames. Neither deals damage. Sprite scaling does not resize hurtboxes or weapon hitboxes.

For a new sheet: put the PNG in the correct folder, add its metadata under the exact requested animation name, save, then **stop and restart the game**. Frames are cached within a running process, so `R` alone does not reload changed sheets/metadata. F3 labels name the missing requested state. Read [ANIMATION_STATUS.md](ANIMATION_STATUS.md) before adding or renaming art.

For a new attack sheet with custom anticipation/contact/recovery frames, define the corresponding `segments`. Existing boss `slash` demonstrates the format. Changing only `fps` will not speed up an animation that the visual controller samples from combat time.

## 8. The rest of the codebase

| File | Responsibility / where you would edit |
| --- | --- |
| [`project.godot`](../project.godot) | Entry scene, 480×270 native resolution, integer window scaling, Compatibility renderer, 60 FPS cap |
| [`scenes/main.tscn`](../scenes/main.tscn) | Entry node with `game.gd` attached |
| [`scripts/game.gd`](../scripts/game.gd) | Builds the world, spawns characters, intro/dialogue, pause, death/retry, ending, hit-stop, particles and shake |
| [`scripts/hitbox.gd`](../scripts/hitbox.gd) | Weapon `Area2D` overlap detection; one result per opponent per swing |
| [`scripts/character_visual.gd`](../scripts/character_visual.gd) | Animation selection, phase-aligned frames, flipping, trails, afterimages, missing labels |
| [`scripts/animation_library.gd`](../scripts/animation_library.gd) | Manifest parsing, sheet slicing, transparency, frame cache and fallback lookup |
| [`scripts/arena.gd`](../scripts/arena.gd) | Drawn hall, mural, lighting colors, phase reactions, boss tells and chain visuals |
| [`scripts/hud.gd`](../scripts/hud.gd) | Health/posture bars, title/death/pause text, dialogue display, attack names and impact flashes |
| [`scripts/sound.gd`](../scripts/sound.gd) | Synthesized sound recipes; `volume_db = -15` sets each effect voice's volume |
| [`scripts/controls.gd`](../scripts/controls.gd) | Default InputMap bindings; existing configured actions take precedence |
| [`export_presets.cfg`](../export_presets.cfg) | Windows export preset; matching Godot export templates are installed separately |
| [`tools/check.py`](../tools/check.py) | Runs import checks and all gameplay suites |
| `tests/` | Combat, movement, timing, AI, animation, feedback, audio, full loop and an automated duel |
| `.godot/` | Generated Godot cache, ignored by Git; not a tuning location |
| `.gd.uid` / `.png.import` | Godot resource identity/import settings; retain these alongside their assets |

The mute action is registered in `game.gd`; the other defaults are in `controls.gd`. Bindings can also be configured in Project Settings → Input Map using those action names.

## 9. Why the scene looks empty in the editor

The main scene contains only a root node. `game.gd` creates the arena, floor, player, boss and HUD **when the game starts**. There currently isn't a player scene or boss scene with preconfigured Inspector values.

`@export` allows a property to appear in Godot's Inspector on an instance. For the runtime-created characters here, edit the defaults at the top of their scripts or set properties in `spawn_fighters` before `add_child`. The game root's exported feedback settings can be edited directly in the main scene's Inspector. Saved Inspector overrides take precedence over script defaults.

During a run, Godot's **Remote** scene tree lets you inspect the actual player/boss and their current health/state. Changes there are temporary. A stop/restart or retry creates fresh actors and resets their state.

`_init()` runs when an object is created. `_ready()` runs when it enters the scene. `_physics_process(delta)` advances gameplay at fixed physics steps; `delta` is elapsed seconds. `_process(delta)` updates presentation and flow each rendered frame. `change_state()` also resets `state_time`, so use it instead of assigning a gameplay state directly.

## 10. Combat geometry and the game loop

A sword swing prepares a rectangle in `hitbox.gd`; only its active period samples overlaps. A contact calls the opponent's `receive_attack`, which resolves immunity, dodge/parry, damage and posture. Feedback signals tell `game.gd` to play sound/effects. Death signals trigger retry or ending flows.

In an attack dictionary, `size` is the hit rectangle, `reach` is its horizontal **center offset**, and `height` is its vertical center relative to the feet. For example, reach 23 with width 34 extends to about 40 pixels forward. Negative height means above the floor. The character's damage-receiving body size is separate, in `fighter.gd`.

Collision layer 1 is the world, layer 2 the player, layer 3 the boss (bitmask values 1, 2, 4). Bodies collide with the floor, and weapon areas detect the opponent's body. Characters intentionally pass through each other for cross-through dodges.

`game.gd` has modes `title`, `intro`, `fight`, `death`, and `ending`. `retry()` replaces both fighters and returns directly to combat, preserving the session death count. HP/posture, phase, scale, immunity and timers reset. There is no save file or persistence across game launches.

To edit dialogue, use `update_intro` in `game.gd`. To edit displayed menus/prompts, use `hud.gd`. Floor collision is created in `game.gd`, while floor art is drawn in `arena.gd`; moving the floor requires keeping both aligned. Changing native resolution is a layout change, not just a window-size change, because arena/HUD positions and world bounds use native coordinates.

## 11. A practical edit-and-test routine

1. Stop the running game (**F8** in Godot), change one value or one related group, and save.
2. Start with **F5**, press Enter, then Tab to skip the intro.
3. Check the intended effect in both stances. Use R after death for another attempt.
4. Run `python tools/check.py` on Windows, or `python3 tools/check.py` on Linux/macOS. Godot must be on PATH, or set the `GODOT` environment variable to its executable.
5. Review the change in Git and commit a clear description, such as “Reduce boss HP to 300 for playtesting.”

The current baseline passes **97 assertions plus one complete input-driven duel**. Some tests deliberately assert exact damage, distance, or audio inventory. An intentional balance change may require updating those expectations. Check that each failure follows from your intended change; retain the behavior checks for collisions, recovery, parries, phases and the full loop.

You do not need to edit every system to tune the fight. For the first pass, focus on **player damage, boss HP, incoming boss damage, and parry windows**. The other sections are here when you need them.
