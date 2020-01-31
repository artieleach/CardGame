extends TextureRect

export (PackedScene) var Card

var card_size = Vector2(32, 48-4)  # the tile is _actually_ 36 high, but the bottom 4 are a different face,  so i dont count them

var held_object = null

var card_positions = []
var next_turn_ready = true
var arr_size = Vector2(4, 4)
var cur_pos = Vector2(3, 3)

var gotten_neighbors = false
var current_neighbors = []

var possible_neighbors = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var deck = [
[1, 'V'], [2, 'V'], [3, 'V'], [4, 'V'], [5, 'V'], [6, 'V'], 
[1, 'V'], [2, 'V'], [3, 'V'], [4, 'V'], [5, 'V'], [6, 'V'],
[1, 'O'], [2, 'O'], [3, 'O'], [4, 'O'], [5, 'O'], [6, 'O'], 
[1, 'O'], [2, 'O'], [3, 'O'], [4, 'O'], [5, 'O'], [6, 'O'],
[1, 'Q'], [2, 'Q'], [3, 'Q'], [4, 'Q'], [5, 'Q'], [6, 'Q'], 
[1, 'Q'], [2, 'Q'], [3, 'Q'], [4, 'Q'], [5, 'Q'], [6, 'Q'],
[1, 'M'], [2, 'M'], [3, 'M'], [4, 'M'], [5, 'M'], [6, 'M']
]
var deck_symbols = ['Q', 'O', 'V', 'M']

func rtg(pos: Vector2):
	return Vector2(int(pos.x / card_size.x), int(pos.y / card_size.y))

class SortByVal:
	static func sort_descending(a,b):
		if a[1].value > b[1].value:
			return true
		return false

func _ready():
	randomize()
	deck.shuffle()
	for i in range(arr_size.x):
		card_positions.append([])
		for j in range(arr_size.y):
			card_positions[i].append([])

func increment_pos():
	if cur_pos.x < (arr_size.x - 1):
		cur_pos.x += 1
	elif cur_pos.y < (arr_size.y - 1):
		cur_pos.x = 0
		cur_pos.y += 1
	else:
		cur_pos = Vector2(0, 0)

# warning-ignore:unused_argument
func _process(delta):
	if held_object:
		if not gotten_neighbors:
			gotten_neighbors = true
			current_neighbors = get_neighbors(held_object.table_pos, false)[1]
			print(current_neighbors)
			for neighbor in current_neighbors:
				neighbor.modulate = Color(1.2, 1.2, 1.2)
		held_object.position = get_local_mouse_position() - (card_size / Vector2(2, 2))
		$shadow.position = Vector2(clamp(int((held_object.position.x + card_size.x / 2) / card_size.x), 0, arr_size.x - 1) * card_size.x, 
								   clamp(int((held_object.position.y + card_size.y / 2) / card_size.y), 0, arr_size.y - 1) * card_size.y)

func get_neighbors(spot, need_positions):
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

func _on_turn_step():
	if next_turn_ready:
		if card_positions[cur_pos.x][cur_pos.y]:
			var new_neighbors = get_neighbors(cur_pos, true)
			card_positions[cur_pos.x][cur_pos.y].take_turn(new_neighbors[0], new_neighbors[1])
			next_turn_ready = false
			$Timer.start()
		else:
			next_turn_ready = true
		increment_pos()
		$Highlight.position = cur_pos * card_size

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
		new_card.connect("create_card", self, "create_card")
		new_card.connect("switch_pos", self, "_on_switch_pos")
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
		var new_spot_neighbors = get_neighbors(held_object.table_pos, false)[1]
		held_object.table_pos = Vector2(clamp(int((held_object.position.x + card_size.x / 2) / card_size.x), 0, arr_size.x - 1), 
										clamp(int((held_object.position.y + card_size.y / 2) / card_size.y), 0, arr_size.y - 1))
		var new_spot = card_positions[held_object.table_pos.x][held_object.table_pos.y]
		if new_spot:
			if new_spot.symbol == held_object.symbol and new_spot.value + held_object.value <= 6 and new_spot in new_spot_neighbors:
				print('here')
				new_spot.value += held_object.value
				new_spot.update_card()
				held_object.survive = false
			held_object.table_pos = held_object.last_pos
		held_object.position = held_object.table_pos * card_size
		held_object.drop()
		held_object = null

func _on_update_board_pos(slot_data, card):
	card_positions[card.table_pos.x][card.table_pos.y] = slot_data

func _on_Stepper_pressed():
	_on_turn_step()

func _on_Turner_pressed():
	pass

func _on_Timer_timeout():
	next_turn_ready = true


func _on_autotimer_timeout():
	if cur_pos != Vector2(0, 0):
		next_turn_ready = true
		_on_turn_step()

func _on_switch_pos(card_a, card_b):
	var new_pos = card_b.table_pos * card_size
	var old_table_pos = card_a.table_pos
	card_a.table_pos = card_b.table_pos
	card_b.table_pos = old_table_pos
	card_b.symbol = [0, 2, 1, 3][card_b.symbol]  # why? i like one liners.
	card_a.update_card()
	card_b.update_card()
	$Tween.interpolate_property(card_a, "position", old_table_pos * card_size, Vector2(old_table_pos.x * card_size.x, old_table_pos.y * card_size.y - 8), 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.start()
	$Tween.interpolate_property(card_a, "position", Vector2(old_table_pos.x * card_size.x, old_table_pos.y * card_size.y - 8), Vector2(new_pos.x, new_pos.y - 8), 0.3, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.1)
	$Tween.start()
	$Tween.interpolate_property(card_a, "position", Vector2(new_pos.x, new_pos.y - 8), Vector2(new_pos.x, new_pos.y), 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.4)
	$Tween.start()
	$Tween.interpolate_property(card_b, "position", card_b.table_pos * card_size, old_table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.4)
	$Tween.start()
	$Tween.interpolate_property(card_a, "z_index", 32, card_a.table_pos.y, 0.5, Tween.TRANS_LINEAR, Tween.EASE_OUT)
	

func _on_deck_pressed():
	$autotimer.wait_time = 0.4
	for i in range(arr_size.x):
		for j in range(arr_size.y):
			if not card_positions[j][i]:
				var new_card = create_card(deck_symbols.find(deck[0][1]),  deck[0][0], Vector2(j, i))
				new_card.position = Vector2(56, 188)
				$autotimer.start()
				yield($autotimer, "timeout")
				$Tween.interpolate_property(new_card, "position", Vector2(56, 188), new_card.table_pos * card_size, 0.3, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.1)
				$Tween.start()
				deck.pop_front()
