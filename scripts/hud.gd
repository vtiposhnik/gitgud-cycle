extends Node2D

var game: Node2D
var font: Font = ThemeDB.fallback_font
var ink := Color("d5d9d7")
var quiet := Color("81939f")
var gold := Color("d8b983")

func _process(_delta: float) -> void: queue_redraw()

func text(value: String, p: Vector2, size: int = 9, color: Color = ink) -> void:
	draw_string(font,p,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(value: String, y: float, size: int = 12, color: Color = ink) -> void:
	var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text(value,Vector2((480-width)/2,y),size,color)

func bar(p: Vector2, size: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(p-Vector2.ONE,size+Vector2(2,2)),Color("0b1119"))
	draw_rect(Rect2(p,size),Color("2b3540"))
	draw_rect(Rect2(p,Vector2(size.x*clampf(ratio,0,1),size.y)),color)

func _draw() -> void:
	if not is_instance_valid(game.player): return
	var p: Challenger = game.player
	var b: FormerVictor = game.boss
	for particle in game.particles:
		draw_rect(Rect2(particle.position + game.world.position, Vector2(2,1)),particle.color)
	if game.flash_time > 0:
		var center: Vector2 = game.flash_position + game.world.position
		var flash_color := Color("d5fff7") if game.flash_kind == "parry" else Color("f5d3a2")
		var radius: float = 13 if game.flash_kind == "parry" else (20 if game.flash_kind == "break" else 7)
		flash_color.a = minf(1,game.flash_time*14)
		draw_line(center-Vector2(radius,0),center+Vector2(radius,0),flash_color,2)
		draw_line(center-Vector2(0,radius),center+Vector2(0,radius),flash_color,1)
		if game.flash_kind in ["parry","break"]: draw_arc(center,radius,0,TAU,12,flash_color,1)
	if game.hitstop > 0 and game.shake > 2:
		draw_rect(Rect2(0,0,480,270),Color(0.75,0.9,1.0,0.09))
	if game.mode in ["fight","death"]:
		draw_rect(Rect2(0,0,480,43),Color(0.03,0.05,0.08,0.88))
		text("THE CHALLENGER",Vector2(16,14),8,quiet)
		bar(Vector2(16,19),Vector2(122,4),p.health/p.max_health,Color("a4c5c6"))
		bar(Vector2(16,27),Vector2(122,2),p.posture/p.max_posture,gold)
		text("II  GUARD" if p.defensive else "I  ASSAULT",Vector2(16,40),8,Color("94d8da") if p.defensive else gold)
		text("Q",Vector2(123,40),8,quiet)
		text("THE FORMER VICTOR",Vector2(265,14),8,ink)
		bar(Vector2(265,19),Vector2(199,4),b.health/b.max_health,Color("afa0c2"))
		bar(Vector2(265,27),Vector2(199,2),b.posture/b.max_posture,gold)
		text(["I / THE DUEL", "II / RECOGNITION", "III / INHERITANCE"][b.phase-1],Vector2(265,40),8,quiet)
		text("DEATHS %02d" % game.deaths,Vector2(170,14),8,quiet)
		if b.state == "startup":
			centered(b.attack.name + ("  /  PARRY" if b.attack.parryable else "  /  EVADE"),60,8,gold if b.attack.parryable else Color("d994be"))
		elif b.state == "staggered" and b.stun_duration == b.stagger_duration:
			centered("POSTURE BROKEN  /  STRIKE",60,8,gold)
		if game.banner_time > 0: centered(game.banner,83,12,ink)
		text("A D  MOVE    SPACE  JUMP    J K  STRIKE    L  PARRY    SHIFT  DODGE",Vector2(15,264),8,quiet)
		if game.fight_time < 9:
			centered("Gold can be parried. Violet must be evaded. Watch the tell fill.",239,8,quiet)
	if game.mode == "title":
		draw_rect(Rect2(0,0,480,270),Color(0.025,0.04,0.06,0.68))
		centered("A   D U E L   W I T H O U T   A N   E N D",57,8,quiet)
		centered("GITGUD",102,42,ink)
		centered("C  Y  C  L  E",125,19,gold)
		draw_line(Vector2(211,140),Vector2(269,140),Color("5d6971"))
		centered("One hall. One victor. Another challenger.",161,9,quiet)
		centered("[ ENTER ]  CHALLENGE THE VICTOR",188,10,ink)
		centered("A D  move   /   SPACE  jump   /   J K  light · heavy",217,8,quiet)
		centered("L  parry   /   SHIFT  dodge   /   Q  stance",231,8,quiet)
		text("PLAYABLE PROTOTYPE  /  v0.2",Vector2(16,259),7,quiet)
		text("F3  LABELS    ESC  PAUSE",Vector2(348,259),7,quiet)
	if game.mode == "intro":
		draw_rect(Rect2(0,0,480,29),Color("080f17"))
		draw_rect(Rect2(0,229,480,41),Color("080f17"))
		centered(game.dialogue,250,12,ink)
		text("TAB  SKIP",Vector2(420,19),8,quiet)
	if game.mode == "death":
		draw_rect(Rect2(0,75,480,115),Color(0.03,0.035,0.05,0.85))
		centered("THE CYCLE CONTINUES",113,22,Color("c6a3ae"))
		centered("Death %02d. The lesson remains." % game.deaths,137,9,quiet)
		centered("[ R ]  RISE AGAIN",164,11,ink)
	if game.mode == "ending":
		var fade := clampf((game.mode_time-5.5)/2,0,1)
		draw_rect(Rect2(0,0,480,270),Color(0.015,0.02,0.03,fade))
		if game.mode_time > 7.5:
			centered("CYCLE COMPLETE",122,26,ink)
			centered("A victor remains.",146,10,quiet)
			centered("[ R ]  BEGIN AGAIN",192,9,gold)
	if game.paused:
		draw_rect(Rect2(0,0,480,270),Color(0.02,0.03,0.05,0.91))
		centered("PAUSED",84,26,ink)
		centered("A D  move    SPACE  jump    SHIFT  dodge",115,10,quiet)
		centered("J  light    K  heavy    L  parry    Q  stance",135,10,quiet)
		centered("Gold tells: parry. Violet tells: jump or dodge.",159,9,gold)
		centered("M  sound    F3  animation labels    ESC  return",186,10,ink)
		centered("Assault: speed and damage. Guard: forgiving parries.",215,9,quiet)
