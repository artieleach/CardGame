extends Node2D

export (PackedScene) var Card

var screen_size = Vector2(320, 192)
var tile_size = Vector2(16, 32-4)

var held_object = null

var card_positions = []
var empty_board = []

var arr_size = rtg(screen_size)
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
	for i in range(2):
		for j in range(1):
			if randf() < 5:
				create_card(randi() % 4, randi() % 6 + 1, Vector2(i, j))
	for i in range(6):
		for j in range(6):
			create_card(randi() % 4, randi() % 6 + 1, Vector2(i+10, j))

func _process(delta):
	if held_object:
		held_object.position = get_local_mouse_position()
		held_object.shadow_position = Vector2(int((held_object.position.x + tile_size.x / 2) / tile_size.x) * tile_size.x, 
											  int((held_object.position.y + tile_size.y / 2) / tile_size.y) * tile_size.y)
		$shadow.position = held_object.shadow_position
	elif Input.is_action_just_released("ui_accept"):
		print(cur_pos,card_positions[cur_pos.x][cur_pos.y])
		if card_positions[cur_pos.x][cur_pos.y]:
			card_positions[cur_pos.x][cur_pos.y].take_turn(card_positions)
		if cur_pos.x < 5:
			cur_pos.x += 1
		elif cur_pos.y < 5:
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
		self.connect("turn_end", new_card, "_on_end_turn")
		new_card.grid_pos = pos
		new_card.position = pos * tile_size  # do some research on making a bordered game space
		card_positions[pos.x][pos.y] = new_card
		add_child(new_card)
	
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
				held_object.position = held_object.shadow_position
				held_object.grid_pos  =Vector2(int(held_object.position.x / tile_size.x), int(held_object.position.y / tile_size.y))
				var obj_pos = held_object.grid_pos
				$shadow.visible = false
				held_object.drop()
				var old_pos = held_object.last_pos
				if 0 <= obj_pos.y and obj_pos.y < len(card_positions[0]) and 0 <= obj_pos.x and obj_pos.x < len(card_positions) and not card_positions[obj_pos.x][obj_pos.y]:
					card_positions[old_pos.x][old_pos.y] = []
					card_positions[obj_pos.x][obj_pos.y] = held_object
				else:
					held_object.grid_pos = obj_pos
				held_object.update_card()
				held_object = null
		elif event.button_index == BUTTON_RIGHT:
			if event.pressed:
				create_card(randi() % 4, randi() % 6 + 1, rtg(get_global_mouse_position()))


