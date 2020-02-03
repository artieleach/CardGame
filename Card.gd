extends Area2D

signal picked
signal dropped
signal update_board_pos
signal create_card
signal switch_pos
signal draw_card

var held = false
var floating = false
var fast_mode = false
# card data
export(int) var symbol			  	# 0 is spiral, 1 is circle, 2 is triangle, 3 is factory
export(int) var value  				# 1-6, used in game logic
export(Vector2) var table_pos  		#  position on the board
export(bool) var survive = true  	#  used in game logic to decide who lives

enum {SPIRAL, CIRCLE, VECTOR, FACTORY}
#local data
var last_pos = null
var card_size = Vector2(32, 48-4)

#helper data for coloring purposes

var symbol_colors = [Color(0.0, 0.0, 0.533), Color(0.0, .235, 0.0), Color(.533, .0, .0), Color(.251, .251, .251)]

func _ready():
	last_pos = table_pos
	$card.animation = str(randi() % 5)  # there are currently five card textures
	update_card()

func _process(delta):
	if held or floating:
		z_index = 64


func ps():  # Print String
	return 'Self: %s\nSymbol: %d\tValue: %d\tGrid: %s\tZ: %d' % [self, symbol, value, table_pos, z_index]

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:  # when the mouse is pressed, pickup
				emit_signal('picked', self)
				held = true
			else:  # when released, drop
				emit_signal('dropped', self)
				drop()
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
			if value > 1:
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
	if survive:
		emit_signal("update_board_pos", self, self)
	else:
		emit_signal('update_board_pos', [], self)
		queue_free()
	value = clamp(value, 1, 6)
	$symbol.animation = str(symbol)
	$card_val/value_0.animation = str(value)
	$card_val/value_1.animation = str(value)
	$card_val.modulate = symbol_colors[symbol]
	z_index = table_pos.y

func take_turn(neighbors, living_neighbors):
	if symbol == SPIRAL:
		var has_switched = false
		for neighbor in living_neighbors:
			if neighbor[1].symbol in [CIRCLE, VECTOR] and not has_switched:
				emit_signal("switch_pos", self, neighbor[1])
				has_switched = true
				break
		if not has_switched:
			for neighbor in neighbors:
				if not neighbor[1]:
					emit_signal("draw_card", neighbor[0])
					break
	elif symbol == CIRCLE:  # gains 1 for each circle neighbor, generates one child
		var has_grown = false
		for neighbor in neighbors:
			if neighbor[1]:
				if neighbor[1].symbol == CIRCLE:
					value += 1
			elif not has_grown:
				emit_signal('create_card', 1, 1, neighbor[0])
				has_grown = true
	elif symbol == VECTOR: 
		survive = false
		for neighbor in living_neighbors:
			if not survive:
				# 1
				if value > neighbor[1].value and neighbor[1].symbol in [SPIRAL, CIRCLE]:
					survive = true
					neighbor[1].symbol = VECTOR
					neighbor[1].value = value - neighbor[1].value
					neighbor[1].update_card()
	elif symbol == FACTORY:
		if len(neighbors) == len(living_neighbors):
			survive = false
			for neighbor in living_neighbors:
				if neighbor[1].symbol != living_neighbors[0][1].symbol:
					survive = true
		if survive:
			for neighbor in living_neighbors:
				if neighbor[1].symbol == 1:
					neighbor[1].symbol = 3
					neighbor[1].update_card()
				neighbor[1].value -= 1
	update_card()
