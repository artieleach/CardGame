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

var turn_counter = 0
var cur_turn = 0

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

func _process(_delta):
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
		
		$highlight.position = $shadow.position
		
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
		new_card.connect("create_card", self, "create_card")
		add_child(new_card)
		return new_card

func _on_pickable_clicked(object):
	if not held_object and object.symbol != FACTORY:
		$shadow.visible = true
		held_object = object
		held_object.pickup()

func _on_pickable_dropped(object):
	var turn_is_valid = false
	$shadow.visible = false
	gotten_neighbors = false
	for neighbor in current_neighbors:
		neighbor.modulate = Color(1, 1, 1)
	if held_object and held_object == object:
		card_positions[held_object.table_pos.x][held_object.table_pos.y] = []
		var neighborhood = get_neighbors(held_object.table_pos, true)
		var neighbors = get_neighbors(held_object.table_pos, false)
		held_object.table_pos = Vector2(clamp(int((held_object.position.x + card_size.x / 2) / card_size.x), 0, arr_size.x - 1), 
										clamp(int((held_object.position.y + card_size.y / 2) / card_size.y), 0, arr_size.y - 1))
		var new_spot = card_positions[held_object.table_pos.x][held_object.table_pos.y]
		if new_spot:
			if  new_spot in neighbors[0]:
				turn_is_valid = held_object.take_turn(new_spot, neighborhood[0], neighborhood[1])
				if turn_is_valid:
					if new_spot.symbol == held_object.symbol:
						neighborhood = get_neighbors(new_spot.table_pos, true)
						new_spot.target_take_turn(neighborhood[1])
				else:
					held_object.table_pos = held_object.last_pos
			else:
				held_object.table_pos = held_object.last_pos
		elif held_object.table_pos != held_object.last_pos:
			if held_object.table_pos.distance_to(held_object.last_pos) == 1:
				turn_is_valid = true
			else:
				held_object.table_pos = held_object.last_pos
		$Tween.interpolate_property(held_object, "position", held_object.position, held_object.table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
		$Tween.start()
		held_object.drop()
		if new_spot:
			new_spot.update_card('pickable dropped new spot')
		held_object = null
		if turn_is_valid:
			turn_counter += 1
		if turn_counter % 2 == 0 and cur_turn != turn_counter:
			cur_turn = turn_counter
			for row in card_positions:
				for card in row:
					if card and card.symbol == FACTORY and card.value > 1:
						neighborhood = get_neighbors(card.table_pos, true)
						card.take_turn(null, neighborhood[0], neighborhood[1])

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
				card.update_card('turner pressed')

func _on_switch_pos(card_a, card_b):
	var new_pos = card_b.table_pos * card_size
	var old_table_pos = card_a.table_pos
	card_a.table_pos = card_b.table_pos
	card_b.table_pos = old_table_pos
	card_a.update_card('switch pos a')
	card_b.update_card('switch pos b')
	$Tween.interpolate_property(card_b, "position", card_b.table_pos * card_size, old_table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.start()

func draw_card(num_to_draw):
	for y in range(arr_size.y):
		for x in range(arr_size.x):
			if not card_positions[x][y] and num_to_draw > 0:
				if deck:
					var new_card = create_card(deck_symbols.find(deck[0][1]),  deck[0][0], Vector2(x, y))
					new_card.position = Vector2(0, 188)
					num_to_draw -= 1
					$Tween.interpolate_property(new_card, "position", Vector2(0, 188), new_card.table_pos * card_size, 0.3, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.05)
					$Tween.start()
					deck.pop_front()
				else:
					deck = deck_copy.duplicate(true)
					deck.shuffle()
					draw_card(num_to_draw)
	num_to_draw = 0

func _on_deck_pressed():
	$autotimer.wait_time = 0.05
	for i in range(arr_size.x * arr_size.y):
		draw_card(1)
		yield(get_tree().create_timer(0.05), "timeout")


func _on_autotimer_timeout():
	pass


