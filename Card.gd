extends Area2D

enum {SPIRAL, CIRCLE, VECTOR, FACTORY}

signal picked
signal dropped
signal update_board_pos
signal switch_pos
signal draw_card

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

#helper data for coloring purposes
var symbol_colors = [
	Color(0.0, 0.0, 0.533),   # blue
	Color(0.0, .235, 0.0),    # green
	Color(.533, .0, .0),      # red
	Color(.251, .251, .251)]  # grey

func _ready():
	last_pos = table_pos
	$card.animation = str(randi() % 4)  # there are currently five card textures
	update_card()

func _process(delta):
	if held or floating:
		z_index = 64


func ps():  # Print String
	return 'Self: %s\nSymbol: %d\tValue: %d\tGrid: %s\tZ: %d' % [self, symbol, value, table_pos, z_index]

func lp():
	return '%d%d' % [value, symbol]

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
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
		update_card() 

func pickup():
	if not held:
		last_pos = table_pos
		held = true

func drop():
	$ThumpParticles.emitting = true
	held = false
	update_card()

func update_card():
	if value < 1:
		survive = false
	emit_signal('update_board_pos', self)
	$symbol.animation = str(symbol)
	$card_val/value_0.animation = str(value)
	$card_val/value_1.animation = str(value)
	$card_val.modulate = symbol_colors[symbol]
	z_index = table_pos.y


func take_turn(target, neighbors, living_neighbors):
	print('S:', self, '\nT: ', target, '\nN: ',neighbors,'\nLN: ' ,living_neighbors)
	if target.symbol == symbol:
		target.value = max(value, target.value)
		target.update_card()
		survive = false
		update_card()
		return true
	elif symbol == SPIRAL and target.symbol in [CIRCLE, VECTOR]:
		table_pos = last_pos
		emit_signal("switch_pos", self, target)
		value -= 1
		return true
	elif symbol == CIRCLE and target.symbol in [VECTOR, SPIRAL]:
		for neighbor in living_neighbors:
			neighbor.value += 1
		var old_val = target.value
		target.value = value
		value = old_val
		target.table_pos = table_pos
		table_pos = last_pos
		target.update_card()
		return true
	elif symbol == VECTOR and value > target.value and target.symbol in [SPIRAL, CIRCLE]: 
		target.value = value - target.value
		target.symbol = symbol
		table_pos = last_pos
		target.update_card()
		table_pos = last_pos
		return true
	elif symbol == FACTORY:
		if len(neighbors) == len(living_neighbors):
			survive = false
			for neighbor in living_neighbors:
				if neighbor[1].symbol != living_neighbors[0][1].symbol:
					survive = true
		if survive:
			for neighbor in living_neighbors:
				if neighbor[1].symbol == CIRCLE:
					neighbor[1].symbol = FACTORY
					neighbor[1].update_card()
				neighbor[1].value -= 1
		return survive
	update_card()
	return false
