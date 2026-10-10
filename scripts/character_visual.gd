extends Node2D

var clock: float = 0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var a := get_parent() as Fighter
	var b := a.is_boss
	var h: float = 49 if b else 28
	var f := a.facing
	var moving: bool = absf(a.velocity.x) > 12
	var step: float = sin(clock * 13) * (4.0 if moving else 0.4)
	var skin := Color("a9a1b8") if b else Color("b7b3a3")
	var cloth := Color("292c3d") if b else Color("354349")
	var ivory := Color("ddd9be")
	var accent := Color("baa1df") if b else (Color("94d8da") if a.defensive else Color("e6b67b"))
	if a.hurt_flash > 0:
		skin = Color.WHITE
		cloth = Color("c7d5dc")
	var collapse: float = clampf(a.state_time / 0.8, 0, 1) if a.state == "dead" else 0.0
	draw_set_transform(Vector2(0, -2), collapse * f * 1.3, Vector2(1, 1 - collapse * 0.45))
	# Long, separated legs and bare feet give both silhouettes a human rhythm.
	draw_line(Vector2(-3, -h * 0.43), Vector2(-5 + step, -2), skin, 3)
	draw_line(Vector2(3, -h * 0.43), Vector2(5 - step, -2), skin, 3)
	draw_line(Vector2(-6 + step, -1), Vector2(-2 + step, -1), skin, 2)
	draw_line(Vector2(4 - step, -1), Vector2(8 - step, -1), skin, 2)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, -h + 9), Vector2(4, -h + 9), Vector2(5, -h * 0.4), Vector2(-6, -h * 0.37)]), cloth)
	draw_rect(Rect2(-4, -h * 0.48, 9, 3), Color("8a795e"))
	draw_line(Vector2(-3, -h * 0.65), Vector2(-6, -h * 0.27), cloth, 3)
	draw_rect(Rect2(-3, -h, 6, 8), skin)
	if b:
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -h), Vector2(5, -h), Vector2(2, -h+10), Vector2(-2, -h+7)]), ivory)
		draw_line(Vector2(-3, -h), Vector2(-7, -h-8), skin, 2)
		draw_line(Vector2(-7, -h-8), Vector2(-3, -h-13), skin, 2)
		draw_line(Vector2(3, -h), Vector2(8, -h-7), skin, 2)
		draw_line(Vector2(8, -h-7), Vector2(7, -h-11), skin, 2)
		draw_rect(Rect2(f * 1, -h+3, 2, 2), Color("272936"))
	else:
		draw_rect(Rect2(-4, -h-1, 7, 3), ivory)
		draw_line(Vector2(-f * 3, -h+1), Vector2(-f * 8, -h+5), ivory, 2)
		draw_line(Vector2(-f * 8, -h+5), Vector2(-f * 7, -h+10), ivory, 2)
	var hand := Vector2(f * 8, -h * 0.57)
	var tip := hand + Vector2(f * (35 if b else 25), 14)
	if a.state in ["startup", "active", "recovery"]:
		var style: String = a.attack.get("id", "light")
		if a.state == "startup":
			tip = hand + Vector2(-f * 12, -42 if b else -23)
			if style == "thrust": tip = hand + Vector2(f * 29, 0)
			if style == "feint": tip.y += sin(a.state_time * 12) * 5
		else:
			tip = hand + Vector2(f * (52 if b else 31), -2)
			if style in ["overhead", "feint"]: tip = hand + Vector2(f * 30, h * 0.52)
		if a.state == "active":
			draw_arc(hand, 45 if b else 29, -0.8 if f > 0 else 2.3, 0.5 if f > 0 else 3.6, 8, accent, 2)
	if a.state == "parry":
		tip = hand + Vector2(-f * 10, -27)
		draw_arc(Vector2(f * 9, -18), 16, -1.4 if f > 0 else 1.7, 1.4 if f > 0 else 4.5, 8, accent, 1)
	draw_line(Vector2(f * 3, -h+11), hand, skin, 3)
	if b:
		for i in range(7):
			var p := hand.lerp(Vector2(-f * 10, -10), float(i) / 6)
			p.y += sin(float(i) / 6 * PI) * 7
			draw_rect(Rect2(p, Vector2(2, 2)), Color("7b738b"))
	draw_line(hand, tip, Color("565c67"), 5 if b else 2)
	draw_line(hand + Vector2(0,-1), tip + Vector2(0,-1), ivory, 2 if b else 1)
	draw_line(hand + Vector2(0,-4), hand + Vector2(0,4), Color("a79572"), 2)
	for i in range(3):
		var spread: float = 11 if a.defensive else 19
		if b: spread = 22 + (4 if a.phase == 3 else 0)
		var relic := Vector2(cos(clock * 0.7 + i * 2.1) * spread, -h * 0.65 + sin(clock * 1.5+i*2.1) * 12)
		draw_rect(Rect2(relic, Vector2(3, 7)), Color("45475a"))
		draw_rect(Rect2(relic, Vector2(1, 5)), accent)
