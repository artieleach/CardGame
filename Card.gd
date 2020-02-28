extends Area2D

enum {SPIRAL, CIRCLE, VECTOR, FACTORY, POWER_UP}

signal picked
signal dropped
signal update_board_pos
signal switch_pos
signal draw_card
signal create_card
signal target_take_turn

var num_of_powerups = 5
var arr_size = Vector2(4, 4)
var card_size = Vector2(33, 44)

# card data
export(int) var symbol              #  0 is spiral, 1 is circle, 2 is vector, 3 is factory, 4 is a power up
export(int) var value               #  1-6, used in game logic
export(Vector2) var table_pos       #  position on the board
export(int) var power_up_value      #  
export(int) var turn_created

#local data
var last_pos = null
var possible_moves = []
var held = false
var floating = false
var mouse_floating_pos = null

#helper data for coloring
var symbol_colors = [
	Color(0.0, 0.0, 0.533),   # blue
	Color(0.0, .235, 0.0),    # green
	Color(.533, .0, .0),      # red
	Color(.251, .251, .251),  # grey
	Color(.0, .173, .361),    # teal
	]


func _ready():
	last_pos = table_pos
	$card.animation = str(randi() % 4)  # there are currently five card textures
	update_card()
	if symbol == POWER_UP:
		$symbol.frame = power_up_value

func _process(_delta):
	if held or floating:
		z_index = 64

func ps():  # Print String
	return 'Self: %s\nSymbol: %d\tValue: %d\tGrid: %s\tZ: %d' % [self, symbol, value, table_pos, z_index]

func lp():
	return '%d%d' % [clamp(value, 0, 9), clamp(symbol+power_up_value, 0, 9)]

func _input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and symbol in [SPIRAL, CIRCLE, VECTOR, POWER_UP]:
			if event.pressed:  # when the mouse is pressed, pickup
				$CollisionShape2D.shape.extents = Vector2(card_size.x *5, card_size.y * 5)
				emit_signal('picked', self)
				held = true
			else:  # when released, drop
				$CollisionShape2D.shape.extents = Vector2(card_size.x / 2, card_size.y / 2)
				emit_signal('dropped', self)

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
	value = clamp(value, 0, 9)
	$value.animation = str(value)
	emit_signal('update_board_pos', self)
	$symbol.animation = str(symbol)
	$value.modulate = symbol_colors[symbol]
	z_index = table_pos.y
	$Clock.visible = symbol == FACTORY
	if symbol == POWER_UP:
		$symbol.frame = power_up_value
	else:
		power_up_value = 0

func highlight_card(turn_on):
	$symbol.frame = int(turn_on)
	$card.frame = int(turn_on)

func get_in_place():
	$Tween.interpolate_property(self, "position", position, table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.start()
	
func take_turn(target):
	table_pos = last_pos
	match symbol:
		target.symbol:
			target.value = min(9, value + target.value)
			value = 0
			update_card('take turn')
			emit_signal("target_take_turn", target)
			return true
		SPIRAL:
			target.symbol = [0, 2, 1, 3, 4][target.symbol]
			emit_signal("switch_pos", self, target)
			value -= 1
			return true
		CIRCLE:
			target.value = min(9, value + target.value)
			target.update_card('target take turn')
			value = 0
			update_card('circle take turn')
			return true
		VECTOR:
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

func target_take_turn(living_neighbors):
	var living_val = value
	value = 0
	emit_signal('update_board_pos', self)
	match symbol:
		CIRCLE:
			emit_signal("draw_card", living_val)
		SPIRAL:
			for neighbor in living_neighbors:
				neighbor[1].symbol = [0, 2, 1, 3, 4][neighbor[1].symbol]
				neighbor[1].update_card('sworlt')
				emit_signal("create_card", 4, 1, table_pos, randi() % num_of_powerups)
		VECTOR:
			for neighbor in living_neighbors:
				neighbor[1].value -= living_val
				neighbor[1].update_card('vector take turn')
				var flame_dir = table_pos - neighbor[1].table_pos
				$FlameParticles.emitting = true
				$FlameParticles.direction = flame_dir
				
