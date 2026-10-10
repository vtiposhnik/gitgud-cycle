class_name Fighter
extends CharacterBody2D

signal feedback(kind: String, where: Vector2)
signal died

@export var max_health: float = 100.0
@export var max_posture: float = 100.0
var health: float = 100.0
var posture: float = 0.0
var facing: float = 1.0
var state: String = "idle"
var state_time: float = 0.0
var defensive: bool = false
var is_boss: bool = false
var enabled: bool = true
var hurt_flash: float = 0.0
var immunity: float = 0.0
var posture_delay: float = 0.0
var visual: Node2D
var hitbox: Area2D
var attack: Dictionary = {}
var phase: int = 1

func _ready() -> void:
	health = max_health
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 50) if is_boss else Vector2(9, 28)
	shape.shape = rect
	shape.position.y = -rect.size.y / 2.0
	add_child(shape)
	collision_layer = 4 if is_boss else 2
	collision_mask = 1
	visual = Node2D.new()
	visual.set_script(load("res://scripts/character_visual.gd"))
	add_child(visual)

func tick_common(delta: float) -> void:
	state_time += delta
	hurt_flash = maxf(0, hurt_flash - delta)
	immunity = maxf(0, immunity - delta)
	posture_delay = maxf(0, posture_delay - delta)
	if posture_delay <= 0 and state in ["idle", "approach", "recovery"]:
		posture = maxf(0, posture - delta * (22.0 if defensive else 12.0))
	visual.queue_redraw()

func change_state(next: String) -> void:
	state = next
	state_time = 0

func receive_attack(_source: Fighter, data: Dictionary) -> String:
	if health <= 0 or immunity > 0:
		return "immune"
	health = maxf(0, health - float(data.get("damage", 10)))
	hurt_flash = 0.16
	posture_delay = 1.6
	feedback.emit("hit", global_position + Vector2(0, -20))
	if health <= 0:
		change_state("dead")
		died.emit()
	return "hit"
