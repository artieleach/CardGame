extends Node2D

export (PackedScene) var Card

var screen_size = Vector2(320, 192)
var tile_size = Vector2(16, 32-4)

var held_object = null

var card_positions = []
var empty_board = []

var arr_size = Vector2(5, 5)
var cur_pos = Vector2(0, 0)
signal turn_end

func rtg(pos: Vector2):
	return Vector2(int(pos.x / tile_size.x), int(pos.y / tile_size.y))

func _ready():
	randomize()
	for i in range(arr_size.x):
		card_positions.append([])
		for j in range(arr_size.y):
			card_positions[i].append([])
	empty_board = card_positions.duplicate(true)
	create_card(0, randi() % 6 + 1, Vector2(0, 0))
	create_card(1, randi() % 6 + 1, Vector2(1, 0))

func _process(delta):
	if held_object:
		held_object.position = get_local_mouse_position()
		held_object.shadow_position = Vector2(int((held_object.position.x + tile_size.x / 2) / tile_size.x) * tile_size.x, 
											  int((held_object.position.y + tile_size.y / 2) / tile_size.y) * tile_size.y)
		$shadow.position = held_object.shadow_position
	elif Input.is_action_just_released("ui_accept" ):
		print(cur_pos,card_positions[cur_pos.x][cur_pos.y])
		if card_positions[cur_pos.x][cur_pos.y]:
			card_positions[cur_pos.x][cur_pos.y].take_turn(card_positions)
		if cur_pos.x < 4:
			cur_pos.x += 1
		elif cur_pos.y < 4:
			cur_pos.x = 0
			cur_pos.y += 1
		else:
			cur_pos = Vector2(0, 0)
		emit_signal('turn_end')

func create_card(sym_num: int, card_val: int, pos: Vector2):
	pos = Vector2(int(pos.x), int(pos.y))
	if not card_positions[pos.x][pos.y]:
		var new_card = Card.instance()
		new_card.sym_num = sym_num
		new_card.val = card_val
		new_card.add_to_group("pickable")
		new_card.connect("clicked", self, "_on_pickable_clicked")
		new_card.connect("update_board_pos", self, "_on_update_board_pos")
		new_card.connect("create_neighbor", self, "create_card")
		new_card.connect("update_my_z", self, "_update_card_z")
		connect("turn_end", new_card, "_on_end_turn")
		new_card.grid_pos = pos
		new_card.position = pos * tile_size  # do some research on making a bordered game space
		card_positions[pos.x][pos.y] = new_card
		add_child(new_card)

func _update_card_z(card, z):
	card.z_index = z

func _on_pickable_clicked(object):
	if not held_object:
		$shadow.visible = true
		held_object = object
		held_object.pickup()

func _on_update_board_pos(slot_data, card_pos):
	card_positions[card_pos.x][card_pos.y] = slot_data

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if held_object and not event.pressed:
				card_positions[held_object.grid_pos.x][held_object.grid_pos.y] = []
				held_object.grid_pos = Vector2(int(held_object.position.x) / tile_size.x, int(held_object.position.y) / tile_size.y).round()
				if card_positions[held_object.grid_pos.x][held_object.grid_pos.y]:
					held_object.grid_pos = held_object.last_pos
				held_object.position = held_object.grid_pos * tile_size
				held_object.drop()
				held_object = null
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				create_card(randi() % 4, randi() % 6 + 1, rtg(get_local_mouse_position()))