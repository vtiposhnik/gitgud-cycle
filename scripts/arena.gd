extends Node2D

var game: Node2D
var motes: Array[Vector3] = []
var clock: float = 0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 713
	for i in range(38): motes.append(Vector3(rng.randf_range(0,480), rng.randf_range(40,214), rng.randf_range(0.2,1)))

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var phase: int = game.boss.phase if is_instance_valid(game.boss) else 1
	var violet := Color("171826") if phase == 1 else (Color("241d35") if phase == 2 else Color("302139"))
	draw_rect(Rect2(0,0,480,270), Color("0b111b"))
	var drift: float = (game.player.position.x - 240) * -0.015 if is_instance_valid(game.player) else 0
	draw_set_transform(Vector2(drift,0))
	# Recessed masonry, symmetrical buttresses, and a ritual eclipse.
	draw_rect(Rect2(72,32,336,181), violet)
	for row in range(6):
		for col in range(8):
			var x: float = 73 + col * 43 - (21 if row % 2 else 0)
			draw_rect(Rect2(x,36+row*29,41,27), Color(0.20,0.24,0.30,0.10))
	draw_rect(Rect2(164,45,152,159), Color("0f1622"))
	draw_rect(Rect2(168,49,144,151), Color("1b2430") if phase == 1 else Color("322a43"))
	for i in range(3):
		draw_arc(Vector2(240,111), 47+i*5, 0, TAU, 64, Color("394652") if phase == 1 else Color("64506d"), 1)
	draw_circle(Vector2(240,111), 40, Color("242f3b") if phase == 1 else Color("47334f"))
	draw_circle(Vector2(251,101), 35, Color("1b2430") if phase == 1 else Color("322a43"))
	# Mural of the victor; phase three reveals those who came before.
	mural_figure(Vector2(240,154), 1.0, Color("46505a"))
	if phase >= 2:
		var crack := PackedVector2Array([Vector2(226,50),Vector2(233,76),Vector2(219,97),Vector2(235,122),Vector2(227,157),Vector2(240,198)])
		draw_polyline(crack, Color("a385b5") if phase == 3 else Color("6d5c7f"), 1)
		draw_polyline(PackedVector2Array([Vector2(232,122),Vector2(267,135),Vector2(279,160)]), Color("6d5c7f"), 1)
	if phase == 3:
		for i in range(5): mural_figure(Vector2(186+i*27,181), 0.65, Color("97819f"))
	# Throne beneath the mural.
	draw_rect(Rect2(222,158,36,48), Color("101822"))
	draw_rect(Rect2(227,152,26,37), Color("313a46"))
	draw_rect(Rect2(230,156,20,32), Color("171e2b"))
	draw_rect(Rect2(219,184,42,6), Color("4c5058"))
	for x in [219,256]: draw_rect(Rect2(x,179,5,27), Color("38434e"))
	for side in [0,1]:
		var x: float = 89 if side == 0 else 379
		draw_colored_polygon(PackedVector2Array([Vector2(x,47),Vector2(x+12,47),Vector2(x+51,217),Vector2(x-34,217)]), Color(0.49,0.64,0.75,0.025))
		draw_rect(Rect2(x,49,9,50), Color("617786") if phase == 1 else Color("8c769f"))
		for y in [63,82]: draw_line(Vector2(x,y),Vector2(x+9,y),Color("18212f"),2)
	draw_set_transform(Vector2.ZERO)
	for x in [39,132,335,428]:
		var top: int = 38 if x in [39,428] else 58
		draw_rect(Rect2(x-8,top-6,27,8), Color("303d4a"))
		draw_rect(Rect2(x-4,top,19,154), Color("1d2a36"))
		draw_rect(Rect2(x-3,top,3,151), Color("3c4a57"))
		draw_rect(Rect2(x+11,top,4,151), Color("131d29"))
		for j in range(4): draw_line(Vector2(x-3,top+31*j),Vector2(x+13,top+31*j),Color("101a25"))
		draw_rect(Rect2(x-9,206,29,12), Color("34414c"))
		draw_polyline(PackedVector2Array([Vector2(x+2,top+54),Vector2(x+8,top+62),Vector2(x+3,top+78)]), Color("101822"))
	# Stone stage, fine seams, broken corners, dark foreground.
	draw_rect(Rect2(0,218,480,52), Color("16212b"))
	draw_rect(Rect2(0,218,480,3), Color("63717a"))
	draw_line(Vector2(0,222),Vector2(480,222),Color("2e3d48"))
	for i in range(12):
		var x: float = i*43
		draw_line(Vector2(x,221),Vector2(x-19,241),Color("25343f"))
	draw_line(Vector2(0,242),Vector2(480,242),Color("263640"))
	draw_rect(Rect2(0,251,480,19),Color("0a111a"))
	for x in [8,20,67,401,441,463]:
		draw_rect(Rect2(x,214,8,4),Color("47515a"))
		draw_rect(Rect2(x+3,212,4,2),Color("323e49"))
	for mote in motes:
		var p := Vector2(fposmod(mote.x+clock*mote.z*2,480),mote.y+sin(clock*0.4+mote.x)*5)
		draw_rect(Rect2(p,Vector2.ONE),Color(0.65,0.71,0.79,mote.z*0.3))
	if is_instance_valid(game.boss): draw_telegraph(game.boss)

func mural_figure(p: Vector2, scale_factor: float, color: Color) -> void:
	draw_rect(Rect2(p+Vector2(-2,-25)*scale_factor,Vector2(4,5)*scale_factor),color)
	draw_line(p+Vector2(0,-20)*scale_factor,p+Vector2(0,-8)*scale_factor,color,2)
	for f in [-1,1]:
		draw_line(p+Vector2(0,-8)*scale_factor,p+Vector2(f*5,0)*scale_factor,color,1)
		draw_line(p+Vector2(0,-18)*scale_factor,p+Vector2(f*7,-11)*scale_factor,color,1)

func draw_telegraph(b: FormerVictor) -> void:
	if b.state not in ["startup", "active"]: return
	var parryable: bool = b.attack.get("parryable", true)
	var color := Color("dfbd82") if parryable else Color("cc7eae")
	var progress: float = clampf(b.state_time / float(b.attack.startup),0,1) if b.state == "startup" else 1.0
	var rect := Rect2(b.position + b.hitbox.position - b.attack.size/2, b.attack.size)
	color.a = 0.12 if b.state == "active" else 0.035 + 0.08*progress
	draw_rect(rect,color)
	color.a = 0.7 if progress > 0.75 else 0.25
	draw_line(Vector2(rect.position.x,216),Vector2(rect.end.x,216),color)
	if b.attack.id in ["sweep", "recall"]:
		var length: float = 126 * progress
		if b.attack.id == "recall": length = 126 * (1.0-progress*0.6)
		var start := b.position + Vector2(b.facing*8,-25)
		var end := b.position + Vector2(b.facing*length,-8 if b.attack.id == "sweep" else -23)
		for i in range(16):
			var p := start.lerp(end,float(i)/15)
			p.y += sin(float(i)/15*PI)*6
			draw_rect(Rect2(p,Vector2(2,1)),Color("a399af"))
		draw_line(end-Vector2(b.facing*8,0),end+Vector2(b.facing*10,0),Color("c2bdc7"),3)
	var tell := b.position + Vector2(0,-72)
	color.a = 1.0
	if parryable:
		draw_circle(tell,2 if progress < 0.8 else 3,color)
	else:
		draw_line(tell+Vector2(-3,-3),tell+Vector2(3,3),color,2)
		draw_line(tell+Vector2(3,-3),tell+Vector2(-3,3),color,2)
	draw_line(tell+Vector2(-10,7),tell+Vector2(-10+20*progress,7),color,1)
