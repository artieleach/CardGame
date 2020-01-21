extends Area2D

signal clicked

var held = false
var tile_size = Vector2(16, 32 - 4)

export(int) var sym_num

func _ready():
	z_index = int(position.y)
	$card.texture = load('res://blank_card_' +str(randi() % 4) + '.png')
	$symbol.texture = load('res://symbol_' + str(sym_num) + '.png')

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			emit_signal('clicked', self)
			held = true

func _process(delta):
	if held:
		position = get_global_mouse_position()
		$shadow.visible = true
		z_index = 4000
		$shadow.global_position = Vector2(int(position.x/ tile_size.x) * tile_size.x + tile_size.x / 2, int(position.y / tile_size.y) * tile_size.y + tile_size.y / 2)

func pickup():
	if held:
		return
	held = true

func drop():
	if held:
		$ThumpParticles.emitting = true
		position = $shadow.global_position
		z_index = int(position.y)
		$shadow.visible = false
		held = false


func kill():
	if is_instance_valid(self):
		queue_free()