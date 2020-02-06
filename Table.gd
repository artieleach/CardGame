extends TextureRect

export (PackedScene) var Card

var card_size =Vector2(32, 43)  # the tile is _actually_ 36 high, but the bottom 4 are a different face,  so i dont count them
enum {SPIRAL, CIRCLE, VECTOR, FACTORY}
var held_object = null

var card_positions = []
var arr_size = Vector2(4, 4)
var cur_pos = Vector2(3, 3)
var init_mouse_pose = Vector2(0, 0)
var gotten_neighbors = false
var current_neighbors = []

var possible_neighbors = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var deck = [
[1, 'V'], [2, 'V'], [3, 'V'], [4, 'V'],  [5, 'V'], 
[1, 'O'], [2, 'O'], [3, 'O'], [4, 'O'],  [5, 'O'], 
[1, 'G'], [2, 'G'], [3, 'G'], [4, 'G'],  [5, 'G'], 
[6, 'M'], 
]
var deck_copy = deck.duplicate(true)
var deck_symbols = ['G', 'O', 'V', 'M']

func rtg(pos: Vector2):
	return Vector2(int(pos.x / card_size.x), int(pos.y / card_size.y))

func _ready():
	randomize()
	deck.shuffle()
	for x in range(arr_size.x):
		card_positions.append([])
		for y in range(arr_size.y):
			card_positions[x].append([])

func _process(delta):
	if held_object:
		if not gotten_neighbors:
			gotten_neighbors = true
			init_mouse_pose = held_object.get_local_mouse_position()
			current_neighbors = get_neighbors(held_object.table_pos, false)[1]
			for neighbor in current_neighbors:
				if neighbor.symbol == held_object.symbol or held_object.symbol == SPIRAL and neighbor.symbol != FACTORY:
					neighbor.modulate = Color(1.2, 1.2, 1.2)
		held_object.position = get_local_mouse_position() - init_mouse_pose
		$shadow.position =  Vector2(clamp(int((held_object.position.x + card_size.x / 2) / card_size.x), 0, arr_size.x - 1) * card_size.x, 
								   clamp(int((held_object.position.y + card_size.y / 2) / card_size.y), 0, arr_size.y - 1) * card_size.y)

func get_neighbors(spot: Vector2, need_positions:= true) -> Array:
	var neighbors = []
	var living_neighbors = []
	for poss_n in possible_neighbors:
		if 0 <= spot.x + poss_n.x and spot.x + poss_n.x < arr_size.x and 0 <= spot.y + poss_n.y and spot.y + poss_n.y < arr_size.y:
			if need_positions:
				neighbors.append([Vector2(spot.x + poss_n.x, spot.y + poss_n.y), card_positions[spot.x + poss_n.x][spot.y + poss_n.y]])
				if neighbors[-1][1]:
					living_neighbors.append(neighbors[-1])
			else:
				neighbors.append(card_positions[spot.x + poss_n.x][spot.y + poss_n.y])
				if neighbors[-1]:
					living_neighbors.append(neighbors[-1])
	return [neighbors, living_neighbors]

func create_card(symbol: int, value: int, pos: Vector2):
	pos = Vector2(clamp(int(pos.x), 0, arr_size.x-1), clamp(int(pos.y), 0, arr_size.y-1))
	if not card_positions[pos.x][pos.y]:
		var new_card = Card.instance()
		new_card.symbol = symbol
		new_card.value = value
		new_card.table_pos = pos
		new_card.position = pos * card_size
		card_positions[pos.x][pos.y] = new_card
		new_card.connect("picked", self, "_on_pickable_clicked")
		new_card.connect("dropped", self, "_on_pickable_dropped")
		new_card.connect("update_board_pos", self, "_on_update_board_pos")
		new_card.connect("switch_pos", self, "_on_switch_pos")
		new_card.connect("draw_card", self, "draw_card")
		add_child(new_card)
		return new_card

func _on_pickable_clicked(object):
	if not held_object:
		$shadow.visible = true
		held_object = object
		held_object.pickup()

func _on_pickable_dropped(object):
	$shadow.visible = false
	gotten_neighbors = false
	for neighbor in current_neighbors:
		neighbor.modulate = Color(1, 1, 1)
	if held_object and held_object == object:
		card_positions[held_object.table_pos.x][held_object.table_pos.y] = []
		var neighborhood = get_neighbors(held_object.table_pos, true)
		held_object.table_pos = Vector2(clamp(int((held_object.position.x + card_size.x / 2) / card_size.x), 0, arr_size.x - 1), 
										clamp(int((held_object.position.y + card_size.y / 2) / card_size.y), 0, arr_size.y - 1))
		var new_spot = card_positions[held_object.table_pos.x][held_object.table_pos.y]
		if new_spot:
			var turn_is_valid = held_object.take_turn(new_spot, neighborhood[0], neighborhood[1])
			print(turn_is_valid)
			if not turn_is_valid:
				held_object.table_pos = held_object.last_pos
		$Tween.interpolate_property(held_object, "position", held_object.position, held_object.table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
		$Tween.start()
		held_object.drop()
		held_object = null

func _on_update_board_pos(card):
	if card.survive:
		card_positions[card.table_pos.x][card.table_pos.y] = card
	else:
		card_positions[card.table_pos.x][card.table_pos.y] = []
		if card in current_neighbors:
			current_neighbors.remove(current_neighbors.find(card))
		card.queue_free()

func _on_turner_pressed():
	for row in card_positions:
		for card in row:
			if card:
				card.update_card()

func _on_switch_pos(card_a, card_b):
	print('called?')
	var new_pos = card_b.table_pos * card_size
	var old_table_pos = card_a.table_pos
	card_a.table_pos = card_b.table_pos
	card_b.table_pos = old_table_pos
	card_b.symbol = [0, 2, 1, 3][card_b.symbol]  # why? i like one liners.
	card_a.update_card()
	card_b.update_card()
	$Tween.interpolate_property(card_b, "position", card_b.table_pos * card_size, old_table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.start()

func draw_card(where):
	if deck:
		var new_card = create_card(deck_symbols.find(deck[0][1]),  deck[0][0], where)
		new_card.position = Vector2(0, 188)
		$autotimer.start()
		$Tween.interpolate_property(new_card, "position", Vector2(0, 188), new_card.table_pos * card_size, 0.3, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.05)
		$Tween.start()
		deck.pop_front()
	else:
		deck = deck_copy.duplicate(true)
		deck.shuffle()

func _on_deck_pressed():
	$autotimer.wait_time = 0.05
	for x in range(arr_size.x):
		for y in range(arr_size.y):
			if not card_positions[x][y]:
				draw_card(Vector2(x, y))
				yield($autotimer, "timeout")


func _on_autotimer_timeout():
	pass


