class_name SwordHitbox
extends Area2D

var wielder: Fighter
var victims: Dictionary = {}
var data: Dictionary = {}
var active: bool = false
var collider: CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 if wielder.is_boss else 4
	monitorable = false
	collider = CollisionShape2D.new()
	collider.shape = RectangleShape2D.new()
	add_child(collider)

func prepare(spec: Dictionary) -> void:
	active = false
	data = spec
	victims.clear()
	var size: Vector2 = spec.get("size", Vector2(36, 25))
	(collider.shape as RectangleShape2D).size = size
	position = Vector2(wielder.facing * float(spec.get("reach", 23)), float(spec.get("height", -18)))

func sample() -> void:
	if not active: return
	for body in get_overlapping_bodies():
		if body is Fighter and body != wielder and not victims.has(body.get_instance_id()):
			var result: String = body.receive_attack(wielder, data)
			# An avoided swing cannot hit again on its trailing frames.
			victims[body.get_instance_id()] = result
			if not active: break
