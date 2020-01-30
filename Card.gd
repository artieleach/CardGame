extends Area2D

signal picked
signal dropped
signal update_board_pos
signal create_card

var held = false
var floating = false
var fast_mode = false
# card data
export(int) var symbol			  	# 0 is spiral, 1 is circle, 2 is triangle, 3 is factory
export(int) var value  				# 1-6, used in game logic
export(Vector2) var table_pos  		#  position on the board
export(bool) var survive = true  	#  used in game logic to decide who lives

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
	value = clamp(value, 0, 6)
	$symbol.animation = str(symbol)
	$card_val/value_0.animation = str(value)
	$card_val/value_1.animation = str(value)
	$card_val.modulate = symbol_colors[symbol]
	z_index = table_pos.y
	if value == 0:
		survive = false
	if survive:
		emit_signal("update_board_pos", self, self)
	else:
		emit_signal('update_board_pos', [], self)
		queue_free()

func take_turn(neighbors, living_neighbors):
	if symbol == 0:
		var has_switched = false
		for neighbor in living_neighbors:
			if neighbor[1].symbol in [1, 2] and not has_switched:
				switch_pos(neighbor[1])
				has_switched = true
				break
		if not has_switched:
			for neighbor in neighbors:
				if not neighbor[1]:
					emit_signal("create_card", 0, 1, neighbor[0])
					break
	elif symbol == 1:  # gains 1 for each circle neighbor, generates one child
		var has_grown = false
		for neighbor in neighbors:
			if neighbor[1]:
				if neighbor[1].symbol == 1:
					value += 1
			elif not has_grown:
				emit_signal('create_card', 1, 1, neighbor[0])
				has_grown = true
	elif symbol == 2: 
		survive = false
		for neighbor in living_neighbors:
			if not survive:
				# 1
				if value > neighbor[1].value and neighbor[1].symbol in [0, 1]:
					survive = true
					neighbor[1].symbol = 2
					neighbor[1].value = value - neighbor[1].value
					neighbor[1].update_card()
	elif symbol == 3:
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


func deal(start):
	position = start
	$Timer.wait_time = 0.1
	$Timer.start()
	yield($Timer, "timeout")
	$Tween.interpolate_property(self, "position", start, table_pos * card_size, 0.3, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.1)
	$Tween.start()

func switch_pos(other_card):  # im avoiding using the actual position of the card as much as possible, thus all of the * card_size
	var new_pos = other_card.table_pos * card_size
	floating = true
	var old_table_pos = table_pos
	table_pos = other_card.table_pos
	other_card.table_pos = old_table_pos
	other_card.symbol = [0, 2, 1, 3][other_card.symbol]  # why? i like one liners.
	$Tween.interpolate_property(self, "position", old_table_pos * card_size, Vector2(old_table_pos.x * card_size.x, old_table_pos.y * card_size.y - 8), 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.start()
	$Tween.interpolate_property(self, "position", Vector2(old_table_pos.x * card_size.x, old_table_pos.y * card_size.y - 8), Vector2(new_pos.x, new_pos.y - 8), 0.3, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.1)
	$Tween.start()
	$Tween.interpolate_property(self, "position", Vector2(new_pos.x, new_pos.y - 8), Vector2(new_pos.x, new_pos.y), 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.4)
	$Tween.start()
	$Tween.interpolate_property(other_card, "position", other_card.table_pos * card_size, old_table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT, 0.4)
	$Tween.start()
	other_card.update_card()
	yield($Tween, "tween_completed")
	floating = false
	update_card()
	
