extends Node2D

var sprite: AnimatedSprite2D
var library: Dictionary
var requested_animation: String = "idle"
var missing_animation: String = ""
var show_missing_labels: bool = OS.is_debug_build()
var clock: float = 0
var ghosts: Array[Dictionary] = []
var ghost_timer: float = 0
var actor: Fighter

func _ready() -> void:
	actor = get_parent() as Fighter
	library = CharacterAnimations.acquire("boss" if actor.is_boss else "challenger")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = library.frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	add_child(sprite)
	sprite.play("idle")

func _process(delta: float) -> void:
	clock += delta
	ghost_timer -= delta
	for i in range(ghosts.size()-1,-1,-1):
		ghosts[i].life -= delta
		if ghosts[i].life <= 0: ghosts.remove_at(i)
	update_animation()
	if actor.state == "dodge" and ghost_timer <= 0:
		ghost_timer = 0.025
		ghosts.append({"position":actor.position,"texture":sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame),
			"offset":sprite.offset,"flip":sprite.flip_h,"life":0.10})
	queue_redraw()

func desired_animation() -> String:
	match actor.state:
		"dead": return "death"
		"dodge", "dodge_recovery": return "dash"
		"transition": return "phase_transition"
		"staggered":
			return "stagger" if actor.stun_duration >= 0.9 else "hurt"
		"parry": return "parry_success" if actor.parry_success else "parry"
		"startup", "active", "recovery":
			var id: String = actor.attack.get("id","light")
			return {"light":"light_attack","heavy":"heavy_attack","sweep":"chain_sweep","feint":"delayed_heavy","recall":"chain_recall"}.get(id,id)
	if not actor.enabled and absf(actor.velocity.x) < 1: return "idle"
	if not actor.is_boss:
		if actor.velocity.y < -1: return "jump"
		if actor.velocity.y > 1: return "fall"
		if actor.landing_time > 0: return "landing"
		if actor.stance_time > 0: return "stance_transition"
	if absf(actor.velocity.x) > 8: return "walk"
	if not actor.is_boss: return "defensive_stance" if actor.defensive else "offensive_stance"
	return "idle"

func update_animation() -> void:
	requested_animation = desired_animation()
	var resolved := CharacterAnimations.resolve(library,requested_animation)
	missing_animation = requested_animation if resolved.missing else ""
	var spec: Dictionary = library.metadata[resolved.name]
	var changed: bool = sprite.animation != resolved.name
	if changed: sprite.play(resolved.name)
	var divisor: int = int(library.config.pixel_divisor)
	var origin := Vector2(round(float(spec.anchor[0])/divisor),round(float(spec.anchor[1])/divisor))
	sprite.flip_h = (actor.facing > 0) != bool(library.config.faces_right)
	var cell_width: float = float(spec.cell[0])/divisor
	sprite.offset = Vector2(origin.x-cell_width if sprite.flip_h else -origin.x,-origin.y)
	sprite.modulate = Color("ffe8ca") if actor.hurt_flash > 0 else Color.WHITE
	if resolved.missing:
		if resolved.pose >= 0:
			sprite.pause()
			sprite.set_frame_and_progress(clampi(resolved.pose,0,sprite.sprite_frames.get_frame_count(resolved.name)-1),0)
		elif not sprite.is_playing(): sprite.play(resolved.name)
	elif actor.state in ["startup","active","recovery"] and spec.has("segments"):
		var segment: Array = spec.segments[actor.state]
		pose_segment(segment, actor.state_time / maxf(float(actor.attack.get(actor.state,0.2)),0.001))
	elif actor.state == "parry":
		var window: float = actor.defensive_parry_window if actor.defensive else actor.offensive_parry_window
		var parry_segment: Array = spec.segments.window if actor.state_time <= window else spec.segments.recovery
		var progress: float = actor.state_time/window if actor.state_time <= window else (actor.state_time-window)/(actor.parry_recovery-window)
		pose_segment(parry_segment,progress)
	elif actor.state in ["dodge","dodge_recovery"]:
		pose_segment([0,sprite.sprite_frames.get_frame_count(resolved.name)-1],actor.dash_elapsed/maxf(actor.dodge_duration,0.001))
	elif actor.state == "staggered":
		pose_segment([0,sprite.sprite_frames.get_frame_count(resolved.name)-1],actor.state_time/maxf(actor.stun_duration,0.001))
	elif not sprite.is_playing() and (changed or spec.loop):
		sprite.play(resolved.name)

func pose_segment(segment: Array, progress: float) -> void:
	sprite.pause()
	var first := int(segment[0])
	var last := int(segment[1])
	var index := first + mini(int(clampf(progress,0,1)*float(last-first+1)),last-first)
	sprite.set_frame_and_progress(index,0)

func _draw() -> void:
	if actor == null or sprite == null: return
	var accent := Color("bca4dc") if actor.is_boss else (Color("9ee6dd") if actor.defensive else Color("eaca99"))
	for ghost in ghosts:
		var pos: Vector2 = ghost.position - actor.position + ghost.offset
		var size: Vector2 = ghost.texture.get_size()
		var rect := Rect2(pos,size)
		if ghost.flip:
			rect.position.x += size.x
			rect.size.x = -size.x
		draw_texture_rect(ghost.texture,rect,false,Color(0.55,0.85,0.9,ghost.life*3))
	if actor.state == "active" and actor.hitbox != null:
		# Effects follow collision geometry even when the authored attack is absent.
		var center: Vector2 = actor.hitbox.position
		var size: Vector2 = actor.attack.get("size",Vector2(34,27))
		if actor.attack.get("id","") == "thrust":
			draw_line(center-Vector2(size.x/2,0),center+Vector2(size.x/2,0),accent,2)
		else:
			var from: float = -0.8 if actor.facing > 0 else PI-0.8
			draw_arc(Vector2(0,center.y),size.x*0.7,from,from+1.6,9,accent,2)
			draw_line(center+Vector2(-size.x/2,2),center+Vector2(size.x/2,2),Color(accent,0.45),1)
	if actor.state == "parry":
		draw_arc(Vector2(actor.facing*9,-18),15,-1.4 if actor.facing>0 else 1.7,1.4 if actor.facing>0 else 4.5,9,accent,1)
	if not actor.is_boss and actor.health > 0:
		draw_line(Vector2(-4,-1),Vector2(4,-1),accent,1)
	if show_missing_labels and not missing_animation.is_empty():
		var label := "[ANIM MISSING: %s]" % missing_animation.to_upper()
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
		var x: float = clampf(actor.position.x-width/2,3,477-width)-actor.position.x
		var y: float = -83 if actor.is_boss else -43
		draw_rect(Rect2(x-2,y-8,width+4,11),Color(0.025,0.04,0.07,0.9))
		draw_string(font,Vector2(x,y),label,HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("b4c2cd"))
