extends Area2D

enum {SPIRAL, CIRCLE, VECTOR, FACTORY, POWER_UP}

signal picked
signal dropped
signal update_board_pos
signal switch_pos
signal draw_card
signal create_card
signal target_take_turn

var arr_size = Vector2(4, 4)

var held = false
var floating = false
var mouse_floating_pos = null
# card data
export(int) var symbol              #  0 is spiral, 1 is circle, 2 is vector, 3 is factory, 4 is a power up
export(int) var value               #  1-6, used in game logic
export(Vector2) var table_pos       #  position on the board
export(int) var turn_created
#local data
var last_pos = null
var card_size = Vector2(32, 44)
var possible_moves = []
#helper data for coloring purposes
var symbol_colors = [
	Color(0.0, 0.0, 0.533),   # blue
	Color(0.0, .235, 0.0),    # green
	Color(.533, .0, .0),      # red
	Color(.251, .251, .251),  # grey
	Color(.0, .173, .361)]  # power_up blue


func _ready():
	if symbol == FACTORY:
		$Clock.visible = true
	last_pos = table_pos
	$card.animation = str(randi() % 4)  # there are currently five card textures
	update_card()

func _process(_delta):
	if held or floating:
		z_index = 64

func ps():  # Print String
	return 'Self: %s\nSymbol: %d\tValue: %d\tGrid: %s\tZ: %d' % [self, symbol, value, table_pos, z_index]

func lp():
	return '%d%s' % [value, ['G', 'O', 'V', 'M', 'P'][symbol]]

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and symbol in [SPIRAL, CIRCLE, VECTOR, POWER_UP]:
			if event.pressed:  # when the mouse is pressed, pickup
				$CollisionShape2D.shape.extents = Vector2(160, 215)
				emit_signal('picked', self)
				held = true
			else:  # when released, drop
				$CollisionShape2D.shape.extents = Vector2(16, 21.5)
				emit_signal('dropped', self)
		elif event.button_index == BUTTON_RIGHT and event.pressed:
			if symbol < 4:
				symbol += 1
			else:
				symbol = 0
		elif event.button_index == BUTTON_WHEEL_UP and event.pressed:
			if value < 9:
				value += 1
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			if value > 0:
				value -= 1

func pickup():
	if not held:
		last_pos = table_pos
		held = true

func drop():
	$ThumpParticles.emitting = true
	held = false
	update_card('drop')

func update_card(called_from := "null"):
	if called_from != "null":
		printt(self, lp(), called_from)
	if value > 0 and 10 > value:
		$card_val/value_0.animation = str(value)
		$card_val/value_1.animation = str(value)
	emit_signal('update_board_pos', self)
	$symbol.animation = str(symbol)
	$card_val.modulate = symbol_colors[symbol]
	z_index = table_pos.y
	$Clock.visible = symbol == FACTORY

func take_turn(target):
	table_pos = last_pos
	if target and target.symbol == symbol:
		target.value += value
		value = 0
		update_card('take turn')
		emit_signal("target_take_turn", target)
		return true
	elif symbol == SPIRAL:
		target.symbol = [0, 2, 1, 3][target.symbol]
		emit_signal("switch_pos", self, target)
		value -= 1
		return true
	elif symbol == CIRCLE:
		target.value = min(9, value + target.value)
		target.update_card('target take turn')
		value = 0
		update_card('circle take turn')
		return true
	elif symbol == VECTOR and value < target.value: 
		target.value = target.value - value
		emit_signal("switch_pos", self, target)
		return true
	update_card('turn failed, impossible move')
	return false

func factory_take_turn(neighbors, living_neighbors):
	for neighbor in neighbors:
		if not neighbor[1]:
			emit_signal("create_card", symbol, 1, neighbor[0])
			return
	for neighbor in living_neighbors:
		if neighbor[1].symbol != symbol:
			neighbor[1].value -= 1
		else:
			value += 1
		neighbor[1].update_card('factory take turn')

func power_up_take_turn(target, card_positions):
	if $symbol.frame == 0:
		var possible_spots = []
		for x in range(arr_size.x):
			for y in range(arr_size.y):
				possible_spots.append(Vector2(x, y))
		possible_spots.shuffle()
		for row in card_positions:
			for card in row:
				if card:
					card.table_pos = possible_spots[0]
					possible_spots.pop_front()
					card.update_card()

func target_take_turn(living_neighbors):
	var living_val = value
	value = 0
	emit_signal('update_board_pos', self)
	if symbol == CIRCLE:
		emit_signal("draw_card", living_val)
	if symbol == SPIRAL:
		for neighbor in living_neighbors:
			neighbor[1].symbol = [0, 2, 1, 3, 4][neighbor[1].symbol]
			neighbor[1].update_card('sworlt')
			emit_signal("create_card", 4, 1, table_pos)
	if symbol == VECTOR:
		for neighbor in living_neighbors:
			neighbor[1].value -= living_val
			neighbor[1].update_card('vector take turn')
