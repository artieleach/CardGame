extends TextureRect

export (PackedScene) var Card

signal game_over

var card_size =Vector2(32, 43)  # the tile is _actually_ 36 high, but the bottom 4 are a different face,  so i dont count them
enum {SPIRAL, CIRCLE, VECTOR, FACTORY, POWER_UP}
var held_object = null

var card_positions = []
var arr_size = Vector2(4, 4)
var init_mouse_pose = Vector2(0, 0)
var gotten_neighbors = false
var current_neighbors = []

var debug = false

var turn_counter = 0
var mouse_on_hand = false
var cur_turn = 0

var symbol_colors = [
	Color(0.0, 0.0, 0.533),   # blue
	Color(0.0, .235, 0.0),    # green
	Color(.533, .0, .0),      # red
	Color(.3, .3, .3),        # grey
	Color(.0, .173, .361)]    # power_up blue

onready var tween = get_node("Tween")
onready var shadow = get_node("Shadow")


var possible_neighbors = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var gamedeck = []

var draw_size = 12
var deck_string = '11213121111020302010122232221293'.bigrams()
var deck = []
var deck_copy = []

func _ready():
	for card in range(len(deck_string)):
		if card % 2 == 0:
			deck.append(deck_string[card])
			deck_copy.append(deck_string[card])
	randomize()
	deck.shuffle()
	for x in range(arr_size.x):
		card_positions.append([])
		for y in range(arr_size.y):
			card_positions[x].append([])
	load_game()
	calculate_possible_moves()

func save_game():
	var output = ['', '']
	for i in range(len(card_positions)):
		for j in range(len(card_positions[i])):
			if card_positions[i][j]: 
				output[0] += card_positions[i][j].lp()
			else:
				output[0] += '00'
	for card in deck:
		output[1] += card
	var save_file = File.new()
	# save_file.open("user://savegame.save", File.WRITE)
	save_file.open("user://savegame.save", File.WRITE)
	for i in output:
		save_file.store_line(i)
	save_file.close()

func load_game():
	var f = File.new()
	if not f.file_exists("user://savegame.save"):
		draw_card(16)
		save_game()
		return
	var loaded_data = []
	f.open("user://savegame.save", File.READ)
	loaded_data.append(f.get_line().bigrams())
	loaded_data.append(f.get_line().bigrams())
	f.close()
	for card in range(len(loaded_data[0])):
		if card % 2 == 0:
			deck.append(loaded_data[0][card])
	draw_card(len(deck))
	for card in range(len(loaded_data[1])):
		if card % 2 == 0:
			deck.append(loaded_data[1][card])

func _process(_delta):
	if held_object:
		if not gotten_neighbors:
			gotten_neighbors = true
			init_mouse_pose = held_object.get_local_mouse_position()
			init_mouse_pose = Vector2(clamp(init_mouse_pose.x, 2, card_size.x-2), clamp(init_mouse_pose.y, 2, card_size.y-2))
			current_neighbors = get_neighbors(held_object)[1]
			for neighbor in current_neighbors:
				if neighbor[1].table_pos in held_object.possible_moves:
					neighbor[1].modulate = Color(1.2, 1.2, 1.2)
		held_object.position = get_local_mouse_position() - init_mouse_pose
		shadow.position =  Vector2(clamp(int((held_object.position.x + card_size.x / 2) / card_size.x), 0, arr_size.x - 1) * card_size.x, 
									clamp(int((held_object.position.y + card_size.y / 2) / card_size.y), 0, arr_size.y - 1) * card_size.y)
func _draw():
	if debug:
		for i in range(len(card_positions)):
			for j in range(len(card_positions[i])):
				if card_positions[i][j]:
					draw_rect( Rect2(Vector2((i*draw_size)+38, (j*draw_size)+183), Vector2(draw_size, draw_size)), symbol_colors[ card_positions[i][j].symbol])
				else:
					draw_rect( Rect2(Vector2((i*draw_size)+38, (j*draw_size)+183), Vector2(draw_size, draw_size)), Color(0, 0, 0))

func _on_pickable_clicked(object):
	save_game()
	if not held_object and object.symbol in [SPIRAL, CIRCLE, VECTOR, POWER_UP]:
		shadow.visible = true
		held_object = object
		card_positions[held_object.table_pos.x][held_object.table_pos.y] = []
		held_object.pickup()

func deck_to_game_deck():
	var card_strings = []

func _on_pickable_dropped(object):
	var turn_is_valid = false
	shadow.visible = false
	gotten_neighbors = false
	if held_object and held_object == object:
		current_neighbors = get_neighbors(held_object, held_object.last_pos)[1]
		for neighbor in current_neighbors:
			neighbor[1].modulate = Color(1, 1, 1)
		var neighbors = get_neighbors(held_object)
		held_object.table_pos = Vector2(clamp(int((held_object.position.x + card_size.x / 2) / card_size.x), 0, arr_size.x - 1), 
										clamp(int((held_object.position.y + card_size.y / 2) / card_size.y), 0, arr_size.y - 1))
		var new_spot = card_positions[held_object.table_pos.x][held_object.table_pos.y]
		if new_spot:
			if new_spot.table_pos in held_object.possible_moves:
				if held_object.symbol != POWER_UP:
					turn_is_valid = held_object.take_turn(new_spot)
				else:
					turn_is_valid = power_up_take_turn(held_object, new_spot)
			else:
				held_object.table_pos = held_object.last_pos
		elif held_object.table_pos != held_object.last_pos:
			if held_object.table_pos.distance_to(held_object.last_pos) == 1:
				turn_is_valid = true
			else:
				held_object.table_pos = held_object.last_pos
		tween.interpolate_property(held_object, "position", held_object.position, held_object.table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
		tween.start()
		held_object.drop()
		held_object = null
		if turn_is_valid:
			turn_counter += 1
		if turn_counter != cur_turn:
			cur_turn = turn_counter
			for row in card_positions:
				for card in row:
					if card and card.symbol == FACTORY and turn_counter > card.turn_created + 1 and (turn_counter + card.turn_created) % 3 == 0:
						var neighborhood = get_neighbors(card)
						card.factory_take_turn(neighborhood[0], neighborhood[1])
	calculate_possible_moves()

func get_in_place(card):
	tween.interpolate_property(card, "position", card.position, card.table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	tween.start()

func create_card(symbol: int, value: int, pos: Vector2, power_up_value: = 0):
	pos = Vector2(clamp(int(pos.x), 0, arr_size.x-1), clamp(int(pos.y), 0, arr_size.y-1))
	if not card_positions[pos.x][pos.y]:
		var new_card = Card.instance()
		new_card.symbol = symbol
		new_card.value = value
		new_card.table_pos = pos
		new_card.position = pos * card_size
		new_card.turn_created = turn_counter
		card_positions[pos.x][pos.y] = new_card
		new_card.power_up_value = power_up_value
		new_card.connect("picked", self, "_on_pickable_clicked")
		new_card.connect("dropped", self, "_on_pickable_dropped")
		new_card.connect("update_board_pos", self, "_on_update_board_pos")
		new_card.connect("switch_pos", self, "_on_switch_pos")
		new_card.connect("draw_card", self, "draw_card")
		new_card.connect("create_card", self, "create_card")
		new_card.connect("target_take_turn", self, "target_take_turn")
		add_child(new_card)
		return new_card

func get_neighbors(card, spot:=Vector2(0, 0)) -> Array:
	if spot == Vector2(0, 0):
		spot = card.table_pos
	var neighbors = []
	var living_neighbors = []
	for poss_n in possible_neighbors:
		if 0 <= spot.x + poss_n.x and spot.x + poss_n.x < arr_size.x and 0 <= spot.y + poss_n.y and spot.y + poss_n.y < arr_size.y:
			neighbors.append([Vector2(spot.x + poss_n.x, spot.y + poss_n.y), card_positions[spot.x + poss_n.x][spot.y + poss_n.y]])
			if neighbors[-1][1]:
				living_neighbors.append(neighbors[-1])
	return [neighbors, living_neighbors]

func calculate_possible_moves():
	for row in card_positions:
		for card in row:
			if card:
				card.update_card()
				if card.symbol in [SPIRAL, CIRCLE, VECTOR, POWER_UP]:
					var cur_n = get_neighbors(card)
					card.possible_moves = []
					for neighbor in cur_n[1]:
						if neighbor[1].symbol == card.symbol:
							card.possible_moves.append(neighbor[1].table_pos)
						elif card.symbol == SPIRAL:
							if card.symbol in [CIRCLE, VECTOR, SPIRAL]:
								card.possible_moves.append(neighbor[1].table_pos)
						elif card.symbol == CIRCLE:
							card.possible_moves.append(neighbor[1].table_pos)
						elif card.symbol == VECTOR:
							if card.value < neighbor[1].value and neighbor[1].symbol in [SPIRAL, CIRCLE, VECTOR]:
								card.possible_moves.append(neighbor[1].table_pos)
						elif card.symbol == POWER_UP:
							if card.get_node('symbol').frame == 0:
								card.possible_moves.append(neighbor[1].table_pos)
							if card.get_node('symbol').frame == 1:
								if neighbor[1].symbol == CIRCLE:
									card.possible_moves.append(neighbor[1].table_pos)
							if card.get_node('symbol').frame == 2:
								if neighbor[1].symbol == FACTORY:
									card.possible_moves.append(neighbor[1].table_pos)
							if card.get_node('symbol').frame == 3:
								if neighbor[1].symbol == SPIRAL:
									card.possible_moves.append(neighbor[1].table_pos)
				else:
					card.get_node('Clock').animation = str((turn_counter) % 3)

func _on_update_board_pos(card):
	if card.value > 0:
		card_positions[card.table_pos.x][card.table_pos.y] = card
	else:
		if card in [card_positions[card.table_pos.x][card.table_pos.y]]:
			card_positions[card.table_pos.x][card.table_pos.y] = []
		if card in current_neighbors:
			current_neighbors.remove(current_neighbors.find(card))
		
		card.queue_free()

func _on_switch_pos(card_a, card_b):
	var new_pos = card_b.table_pos * card_size
	var old_table_pos = card_a.table_pos
	card_a.table_pos = card_b.table_pos
	card_b.table_pos = old_table_pos
	card_a.update_card('switch pos a')
	card_b.update_card('switch pos b')
	get_in_place(card_b)

func draw_card(num_to_draw, delay:= 0):
	var total_to_draw = num_to_draw + delay
	for x in range(arr_size.x):
		for y in range(arr_size.y):
			if not card_positions[x][y]:
				if num_to_draw > 0:
					if deck:
						var new_card = create_card(int(deck[0][1]), int(deck[0][0]), Vector2(x, y))
						new_card.position = Vector2(0, 183)
						num_to_draw -= 1
						tween.interpolate_property(new_card, "position", Vector2(0, 188), new_card.table_pos * card_size, 0.3, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.1 * (total_to_draw - num_to_draw))
						tween.start()
						tween.interpolate_property(new_card, "z_index", num_to_draw*10, new_card.table_pos.y, 0.3, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.1 * (total_to_draw - num_to_draw))
						tween.start()
						deck.pop_front()
					else:
						deck = deck_copy.duplicate(true)
						deck.shuffle()
						draw_card(num_to_draw, total_to_draw-num_to_draw)
			else:
				card_positions[x][y].update_card('card drawn')
	num_to_draw = 0

func power_up_take_turn(power_up_card, target):
	var card_arr = card_positions.duplicate(true)
	var power_up_value = power_up_card.value
	var cur_power = power_up_card.get_node('symbol').frame
	power_up_card.value = 0
	if cur_power == 0:
		var possible_spots = []
		for x in range(arr_size.x):
			for y in range(arr_size.y):
				possible_spots.append(Vector2(x, y))
				card_positions[x][y] = []
		possible_spots.shuffle()
		for row in card_arr:
			for card in row:
				if card and card != self:
					card.table_pos = possible_spots[0]
					get_in_place(card)
					card.update_card()
					possible_spots.pop_front()
		draw_card(power_up_value)
		return true
	elif cur_power == 1:
		for row in card_positions:
			for card in row:
				if card and card.symbol == CIRCLE:
					card.symbol = VECTOR
					card.value = power_up_value
		return true
	elif cur_power == 2:
		for row in card_positions:
			for card in row:
				if card and card.symbol == FACTORY:
					var factory_neighbors = get_neighbors(card)
					for fac_neighbor in factory_neighbors[1]:
						if fac_neighbor[1].symbol == FACTORY:
							fac_neighbor[1].value -= power_up_value
		return true
	elif cur_power == 3:
		for row in card_positions:
			for card in row:
				if card and card.symbol == SPIRAL:
					var spi_neighbors = get_neighbors(card)[0]
					for spot in spi_neighbors:
						if not spot[1]:
							create_card(SPIRAL, power_up_value, spot[0]) 
							break
	elif cur_power == 4:
		pass
	return false

func target_take_turn(card):
	card.target_take_turn(get_neighbors(card)[1])

func _on_deck_pressed():
	var can_draw = true
	for row in card_positions:
		for card in row:
			if card:
				can_draw = false
	if can_draw:
		draw_card(16)
		calculate_possible_moves()


func _on_tween_completed(_object, key):
	if key == ":position":
		pass  # put audio here
