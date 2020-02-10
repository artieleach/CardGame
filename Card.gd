extends Area2D

enum {SPIRAL, CIRCLE, VECTOR, FACTORY}

signal picked
signal dropped
signal update_board_pos
signal switch_pos
signal draw_card
signal create_card

var arr_size = Vector2(4, 4)

var held = false
var floating = false
var fast_mode = false
# card data
export(int) var symbol              #  0 is spiral, 1 is circle, 2 is vector, 3 is factory
export(int) var value               #  1-6, used in game logic
export(Vector2) var table_pos       #  position on the board
export(bool) var survive = true     #  used in game logic to decide who lives

#local data
var last_pos = null
var card_size = Vector2(32, 44)

var rel_rot = [Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, 1)]

#helper data for coloring purposes
var symbol_colors = [
	Color(0.0, 0.0, 0.533),   # blue
	Color(0.0, .235, 0.0),    # green
	Color(.533, .0, .0),      # red
	Color(.251, .251, .251)]  # grey

func _ready():
	last_pos = table_pos
	$card.animation = str(randi() % 4)  # there are currently five card textures
	update_card('ready')

func _process(_delta):
	if held or floating and symbol != FACTORY:
		z_index = 64


func ps():  # Print String
	return 'Self: %s\nSymbol: %d\tValue: %d\tGrid: %s\tZ: %d' % [self, symbol, value, table_pos, z_index]

func lp():
	return '%d%s' % [value, ['G', 'O', 'V', 'M'][symbol]]

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and symbol != FACTORY:
			if event.pressed:  # when the mouse is pressed, pickup
				emit_signal('picked', self)
				held = true
			else:  # when released, drop
				emit_signal('dropped', self)
		elif event.button_index == BUTTON_RIGHT and event.pressed:
			if symbol < 3:
				symbol += 1
			else:
				symbol = 0
		elif event.button_index == BUTTON_WHEEL_UP and event.pressed:
			if value < 6:
				value += 1
			else:
				value = 1
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			if value > 0:
				value -= 1
			else:
				value = 6

func pickup():
	if not held and symbol != FACTORY:
		last_pos = table_pos
		held = true

func drop():
	$ThumpParticles.emitting = true
	held = false
	update_card('drop')

func update_card(called_from):
	# print_debug(self, lp(), called_from)
	value = clamp(value, 0, 6)
	if value < 1:
		survive = false
	else:
		$card_val/value_0.animation = str(value)
		$card_val/value_1.animation = str(value)
	emit_signal('update_board_pos', self)
	$symbol.animation = str(symbol)
	$card_val.modulate = symbol_colors[symbol]
	z_index = table_pos.y

func target_take_turn(living_neighbors):
	if symbol == CIRCLE:
		emit_signal("draw_card", value)
	if symbol == SPIRAL:
		return
		for neighbor in living_neighbors:
			print(neighbor[1].ps())
			var rel_pos =  table_pos - neighbor[1].table_pos
			print(neighbor[1], 'rp', rel_pos)
			for i in rel_rot:
				var cur = table_pos + i
				printt(neighbor[1], 'rp+i', rel_pos + i)
				if rel_pos + i in [Vector2(0, 1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, -1)]:
					if 0 < cur.x and cur.x < arr_size.x and 0 < cur.y and cur.y < arr_size.y:
						neighbor[1].table_pos = cur
						neighbor[1].update_card('swirly dirly')
	if symbol == VECTOR:
		for neighbor in living_neighbors:
			neighbor[1].value -= value
			neighbor[1].update_card('vector take turn')
		value = 0

func take_turn(target, neighbors, living_neighbors):
	if target and target.symbol == symbol:
		target.value = max(value, target.value)
		survive = false
		update_card('take turn')
		target.update_card('target take turn')
		return true
	elif symbol == SPIRAL and target.symbol in [CIRCLE, VECTOR]:
		table_pos = last_pos
		target.symbol = [0, 2, 1, 3][target.symbol]
		emit_signal("switch_pos", self, target)
		value -= 1
		return true
	elif symbol == CIRCLE and target.symbol in [VECTOR, SPIRAL]:
		table_pos = last_pos
		var old_val = target.value
		target.value = value
		value = old_val
		emit_signal("switch_pos", self, target)
		target.update_card('target take turn')
		return true
	elif symbol == VECTOR and value > target.value and target.symbol in [SPIRAL, CIRCLE]: 
		table_pos = last_pos
		target.value = value - target.value
		emit_signal("switch_pos", self, target)
		return true
	elif symbol == FACTORY:
		for neighbor in neighbors:
			if not neighbor[1]:
				emit_signal("create_card", symbol, 1, neighbor[0])
				break
		for neighbor in living_neighbors:
			if neighbor[1].symbol != symbol:
				neighbor[1].value -= 1
			else:
				neighbor[1].value += 1
			if neighbor[1].symbol == CIRCLE and neighbor[1].value == 0:
				neighbor[1].symbol = FACTORY
				neighbor[1].value = 1
			neighbor[1].update_card('factory take turn')
	update_card('take turn')
	return false
