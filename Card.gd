extends Area2D

enum {SPIRAL, CIRCLE, VECTOR, HOLDER_1, HOLDER_2, FACTORY, SHUFFLE, BURN, CAPITALISM, FLOOD, MULLIGAN}

signal picked
signal dropped
signal update_board_pos
signal switch_pos
signal draw_card
signal create_card
signal target_take_turn

var num_of_powerups = 5
var arr_size = Vector2(4, 4)
var card_size = Vector2(32, 43)

# card data
export(int) var symbol              #  0 is spiral, 1 is circle, 2 is vector, 3 is factory, 4 is a power up
export(int) var value               #  1-6, used in game logic
export(Vector2) var table_pos       #  position on the board
export(int) var turn_created
var cheatsheet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
#local data
var last_pos = null
var possible_moves = []
var held = false
var floating = false
var mouse_floating_pos = null
var gotten_mouse_pos = false
var pickable = true
var debug = true

#helper data for coloring
var symbol_colors = [
	Color('000088'),   # blue
	Color('003c00'),   # green
	Color('880000'),   # red
	Color('480078'),   # purple
	Color('480078'),   # also purple
	Color('404040'),   # grey
	Color('002c5c'),   # teal
	]

func _ready():
	last_pos = table_pos
	$card.frame = randi() % 4  # there are currently five card textures
	update_card()

func _process(_delta):
	if held or floating:
		if not gotten_mouse_pos:
			mouse_floating_pos = get_local_mouse_position()
			mouse_floating_pos = Vector2(clamp(mouse_floating_pos.x, 1, card_size.x-2), clamp(mouse_floating_pos.y, 1, card_size.y-2))
			gotten_mouse_pos = true
		z_index = 64
		global_position = get_global_mouse_position() - mouse_floating_pos

func ps():
	return 'Self: %s\nSymbol: %d\tValue: %d\tGrid: %s\tZ: %d' % [self, symbol, value, table_pos, z_index]

func lp():
	return '%s%s' % [str(clamp(value, 0, 9)), cheatsheet[symbol]]


func pickup():
	if not held:
		$Tween.interpolate_property(self, "global_position", global_position, Vector2(global_position.x, global_position.y - 5), 0.05, Tween.EASE_IN, Tween.EASE_OUT)
		$Tween.start()
		$shadow.visible = true
		$Tween.interpolate_property($shadow, "global_position", global_position, global_position + Vector2(0, 5), 0.05, Tween.EASE_IN, Tween.EASE_OUT)
		$Tween.start()
		$highlight.visible = false
		last_pos = table_pos
		yield(get_node("Tween"), "tween_completed")
		held = true

func drop():
	get_in_place()
	$ThumpParticles.z_index = 0
	$ThumpParticles.emitting = true
	$shadow.visible = false
	$highlight.visible = false
	held = false
	update_card('drop')

func update_card(called_from := "null"):
	if called_from != "null":
		printt(self, lp(), called_from)
	emit_signal('update_board_pos', self)
	value = clamp(value, 0, 9)
	if $value.frame != value:
		var diff = abs($value.frame - value)
		$Tween.interpolate_property($value, "frame", $value.frame, value, 0.05 * diff)
		$Tween.start()
	$symbol.frame = symbol
	$value.modulate = symbol_colors[clamp(symbol, 0, 6)]
	z_index = table_pos.y
	$clock.visible = symbol == FACTORY

func get_in_place():
	$Tween.interpolate_property(self, "position", position, table_pos * card_size, 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
	$Tween.start()

func take_turn(target):
	table_pos = last_pos
	match symbol:
		target.symbol:
			target.value = min(9, value + target.value)
			table_pos = target.table_pos
			value = 0
			update_card('take turn')
			emit_signal("target_take_turn", target)
			return true
		SPIRAL:
			if target.symbol in [CIRCLE, VECTOR]:
				target.symbol = [0, 2, 1][target.symbol]
			emit_signal("switch_pos", self, target)
			value -= 1
			return true
		CIRCLE:
			target.value = min(9, value + target.value)
			target.update_card('target take turn')
			value = 0
			table_pos = target.table_pos
			update_card('circle take turn')
			return true
		VECTOR:
			var holder = value
			value -= target.value
			target.value = target.value - holder
			emit_signal("switch_pos", self, target)
			return true
		HOLDER_1:
			if target.symbol != HOLDER_2:
				emit_signal("switch_pos", self, target)
			else:
				pass
			return true
		HOLDER_2:
			if target.symbol != HOLDER_1:
				emit_signal("switch_pos", self, target)
			else:
				pass
			return true
	update_card('turn failed, impossible move')
	return false

func factory_take_turn(neighbors, living_neighbors, turn_counter):
	for neighbor in neighbors:
		if not neighbor[1]:
			emit_signal("create_card", symbol, 1, neighbor[0])
			return
	for neighbor in living_neighbors:
		if neighbor[1].symbol != symbol and neighbor[1].turn_created != turn_counter:
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
				if neighbor[1].symbol in [CIRCLE, VECTOR]:
					neighbor[1].symbol = [0, 2, 1][neighbor[1].symbol]
				neighbor[1].update_card('sworlt')
			emit_signal("create_card", cheatsheet[(randi() % num_of_powerups) + SHUFFLE], 1, table_pos)
		VECTOR:
			for neighbor in living_neighbors:
				neighbor[1].value -= living_val
				neighbor[1].update_card('vector take turn')
		HOLDER_1:
			pass
		HOLDER_2:
			pass

func death_animation():
	pickable = false
	var diff = abs($value.frame - value)
	$Tween.interpolate_property($value, "frame", $value.frame, value, 0.05 * diff)
	$Tween.start()
	yield(get_tree().create_timer(0.05 * diff), "timeout")
	$AnimationPlayer.play('death')

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "death":
		queue_free()

func _on_Card_mouse_entered():
	if symbol != FACTORY:
		$highlight.visible = true

func _on_Card_mouse_exited():
	$highlight.visible = false

func _on_Card_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and symbol != FACTORY and pickable:
			if event.pressed:  # when the mouse is pressed, pickup
				emit_signal('picked', self)
				$CardCollision.shape.extents = Vector2( card_size.x * 10, card_size.y * 10)
			else:  # when released, drop
				emit_signal('dropped', self)
				$CardCollision.shape.extents = Vector2((card_size.x - 0.5) / 2, (card_size.y - 0.5) / 2)
				gotten_mouse_pos = false
		if debug == true:
			if event.button_index == BUTTON_RIGHT and event.pressed:
				if symbol < MULLIGAN:
					symbol += 1
				else:
					symbol = 0
			elif event.button_index == BUTTON_WHEEL_UP and event.pressed:
				if value < 9:
					value += 1
			elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
				if value > 0:
					value -= 1

