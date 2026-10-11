class_name CharacterAnimations
extends RefCounted

# Artist-facing sheet layouts and fallback policy live in JSON, not combat code.
const MANIFEST := "res://assets/characters/animations.json"
static var cache: Dictionary = {}

static func acquire(character: String) -> Dictionary:
	if cache.has(character): return cache[character]
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var config: Dictionary = manifest[character]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var metadata: Dictionary = {}
	for animation in config.animations:
		var spec: Dictionary = config.animations[animation]
		var path: String = "res://assets/characters/%s/animations/%s" % [character,spec.file]
		if not ResourceLoader.exists(path):
			push_warning("Animation asset missing: " + path)
			continue
		var source: Texture2D = load(path)
		var source_image := source.get_image()
		source_image.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(int(spec.cell[0]),int(spec.cell[1]))
		var columns := source_image.get_width() / cell.x
		var rows := source_image.get_height() / cell.y
		if columns < 1 or rows < 1 or int(spec.count) > columns * rows:
			push_error("Invalid animation layout: " + path)
			continue
		# Solid-color exports use a specified key, never guessed from costume colors.
		if spec.has("color_key"):
			var key := Color(spec.color_key)
			var tolerance: float = float(spec.get("key_tolerance", 12)) / 255.0
			for y in range(source_image.get_height()):
				for x in range(source_image.get_width()):
					var pixel := source_image.get_pixel(x,y)
					if maxf(absf(pixel.r-key.r),maxf(absf(pixel.g-key.g),absf(pixel.b-key.b))) <= tolerance:
						pixel.a = 0
						source_image.set_pixel(x,y,pixel)
		var divisor: int = int(config.pixel_divisor)
		var atlas_texture := ImageTexture.create_from_image(source_image)
		frames.add_animation(animation)
		frames.set_animation_speed(animation,float(spec.fps))
		frames.set_animation_loop(animation,bool(spec.loop))
		var indices: Array = spec.get("indices",range(int(spec.count)))
		for index in indices:
			var region := Rect2i(Vector2i(int(index) % columns, int(index) / columns) * cell,cell)
			var texture: Texture2D
			if divisor == 1:
				var atlas := AtlasTexture.new()
				atlas.atlas = atlas_texture
				atlas.region = region
				texture = atlas
			else:
				# Integer decimation once on first load; node scales stay exactly 1:1.
				var image := source_image.get_region(region)
				image.resize(cell.x / divisor,cell.y / divisor,Image.INTERPOLATE_NEAREST)
				texture = ImageTexture.create_from_image(image)
			frames.add_frame(animation,texture)
		metadata[animation] = spec
	var result := {"frames":frames,"metadata":metadata,"config":config}
	cache[character] = result
	return result

static func resolve(library: Dictionary, requested: String) -> Dictionary:
	if library.frames.has_animation(requested): return {"name":requested,"missing":false,"pose":-1}
	var fallback: Dictionary = library.config.fallbacks.get(requested,{"animation":"idle"})
	var name: String = fallback.animation
	if not library.frames.has_animation(name): name = "idle"
	return {"name":name,"missing":true,"pose":int(fallback.get("pose",0))}
