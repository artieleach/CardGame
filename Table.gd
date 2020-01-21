extends Node2D
var screen_size = Vector2(320, 192)

var tile_size = Vector2(16, 32 - 4)

var held_object = null
var card_node = preload("res://Card.tscn")
var card_positions = []
var empty_array = []
var last_card_pos
var arr_w = 0
var arr_h = 0

signal game_step

func rtg(pos:Vector2):
	# Revert To Grid
	# helper function which returns a grid coord for a given XY pair
	return Vector2(int(pos.x / tile_size.x), int(pos.y / tile_size.y))

func _ready():
	for i in range(rtg(screen_size).y):
		card_positions.append([])
		for j in range(rtg(screen_size).x):
			card_positions[i].append([])
	arr_w = len(card_positions)
	arr_h = len(card_positions[0])
	empty_array = card_positions.duplicate(true)
	for i in range(rtg(screen_size).y):
		for j in range(rtg(screen_size).x):
			if randf() < 0.6:
				create_card(randi() % 3, Vector2(j, i))

func create_card(card_number:int, pos:Vector2):
	pos = Vector2(int(pos.x), int(pos.y))
	if not card_positions[pos.y][pos.x]:
		var new_card = card_node.instance()
		new_card.sym_num = card_number
		new_card.add_to_group('pickable')
		new_card.connect('clicked', self, '_on_pickable_clicked')
		new_card.position = Vector2(pos.x * tile_size.x + tile_size.x / 2, pos.y * tile_size.y + tile_size.y / 2)
		card_positions[pos.y][pos.x] = new_card
		add_child(new_card)

func _on_pickable_clicked(object):
	if not held_object:
		held_object = object
		last_card_pos = held_object.position
		held_object.pickup()

func _process(delta):
	if Input.is_action_just_released("ui_accept"):
		empty_array = card_positions.duplicate(true)
		for row in range(arr_w):
			for col in range(arr_h):
				if empty_array[row][col]:
					var cur_card = card_positions[row][col]
					for hor in [-1, 0, 1]:
						for ver in [-1, 0, 1]:
							if 0 <= (row + hor) and (row + hor) < arr_w and 0 <= (col + ver) and (col + ver) < arr_h:
								if cur_card.sym_num == 0:
									if not empty_array[row + hor][ver + col]:
										if hor == 0 or ver == 0:
											create_card(0, Vector2(ver + col, row + hor))
								elif cur_card.sym_num == 2:
									if card_positions[row + hor][ver + col] and card_positions[row + hor][ver + col].sym_num == 0: 
										empty_array[row + hor][ver + col] = []

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if held_object and not event.pressed:
				held_object.drop()
				var obj_pos = rtg(held_object.position)
				var old_pos = rtg(last_card_pos)
				if 0 <= obj_pos.y and obj_pos.y < len(card_positions) and 0 <= obj_pos.x and obj_pos.x < len(card_positions[0]) and not card_positions[obj_pos.y][obj_pos.x]:
					card_positions[old_pos.y][old_pos.x] = []
					card_positions[obj_pos.y][obj_pos.x] = held_object
				else:
					held_object.position = last_card_pos  # todo: switch this to a function which moves the card into place
					held_object.z_index = held_object.position.y
				held_object = null
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				create_card(randi() % 3, Vector2(get_global_mouse_position().x / tile_size.x, get_global_mouse_position().y / tile_size.y))
		