extends Area2D

signal clicked
signal update_board_pos
signal update_my_z

signal create_neighbor

var held = false

export(int) var sym_num
export(int) var val
export(Vector2) var grid_pos
export(bool) var sleeping

var survive = true
var board_state = null
var neighbors = []
var last_pos = null

var shadow_position = Vector2(0, 0)

var possible_neighbors = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]

var symbol_colors = [Color(0.0, 0.0, 0.533), Color(0.0, .235, 0.0), Color(.533, .0, .0), Color(.251, .251, .251)]

func _ready():
	last_pos = grid_pos
	emit_signal("update_my_z", self, grid_pos.y)
	$card.animation = str(randi() % 4)
	update_card()
	sleeping = true

func _process(delta):
	if sleeping:
		modulate.a = 0.5
	else:
		modulate.a = 1
	if held:
		z_index = 64
		#emit_signal("update_my_z", self, 64)

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			emit_signal('clicked', self)
			held = true
		elif event.button_index == BUTTON_RIGHT and event.pressed:
			if sym_num < 3:
				self.sym_num += 1
			else:
				sym_num = 0
		if event.button_index == BUTTON_WHEEL_UP and event.pressed:
			if self.val < 6:
				self.val += 1
			else:
				self.val = 1
		elif event.button_index == BUTTON_WHEEL_DOWN and event.pressed:
			if self.val > 1:
				self.val -= 1
			else:
				self.val = 6
		update_card() 

func pickup():
	if not held:
		last_pos = grid_pos
		held = true

func drop():
	$ThumpParticles.emitting = true
	update_card()
	held = false

func update_card():
	sleeping = false
	$symbol.animation = str(sym_num)
	$value.animation = str(val)
	$value.modulate = symbol_colors[sym_num]
	z_index = grid_pos.y
	emit_signal("update_board_pos", self, grid_pos)

func take_turn(card_positions):
	# inital set up, finding neighbors
	board_state = card_positions
	neighbors = []
	print('self:', self)
	for poss_n in possible_neighbors:
		if 0 <= grid_pos.x + poss_n.x and grid_pos.x + poss_n.x < 5 and 0 <= grid_pos.y + poss_n.y and grid_pos.y + poss_n.y < 5:
			neighbors.append([Vector2(grid_pos.x + poss_n.x, grid_pos.y + poss_n.y), board_state[grid_pos.x + poss_n.x][grid_pos.y + poss_n.y]])
	print('neighbors: ',neighbors)
	#do game logic 
	sleeping = false
	if not sleeping:
		if sym_num == 0:
			var has_switched = false
			var has_grown = false
			for neighbor in neighbors:
				if neighbor[1]:
					if neighbor[1].sym_num in [1, 2] and not has_switched:
						switch_pos(neighbor[1], true, null)
						var old_grid_pos = grid_pos
						grid_pos = neighbor[1].grid_pos
						neighbor[1].grid_pos = old_grid_pos
						if neighbor[1].sym_num == 1:
							neighbor[1].sym_num = 2
						elif neighbor[1].sym_num == 2:
							neighbor[1].sym_num = 1
						neighbor[1].update_card()
						neighbor[1].z_index = -100
						neighbor[1].sleeping = true
						has_switched = true
			if not has_switched:
				for neighbor in neighbors:
					if not neighbor[1] and not has_grown:
						emit_signal("create_neighbor", 0, 1, neighbor[0])
						has_grown = true
			if not has_grown and not has_switched:
				sym_num = 3
		elif sym_num == 1:
			var has_grown = false
			for neighbor in neighbors:
				if neighbor[1]:
					if neighbor[1].sym_num == 1:
							val += 1
							print('here', neighbor)
				elif not has_grown:
					emit_signal("create_neighbor", 1, 1, neighbor[0])
					has_grown = true
		elif sym_num == 2:
			survive = false
			for neighbor in neighbors:
				if neighbor[1]:
					if val > neighbor[1].val:
						survive = true
						neighbor[1].sym_num = 2
						neighbor[1].val = val - neighbor[1].val
						neighbor[1].update_card()
		elif sym_num == 3:
			survive = false
			var met_needs = false
			var expanded = false
			var living_neighbors = []
			for neighbor in neighbors:
				if neighbor[1]:
					if neighbor[1].sym_num == 1 and not expanded:
						met_needs = true
						expanded = true
						neighbor[1].sym_num = 3
						neighbor[1].update_card()
						neighbor[1].sleeping = true
					living_neighbors.append(neighbor)
			if not living_neighbors or len(living_neighbors) != len(neighbors):
				met_needs = true
			if not expanded:
				for item in living_neighbors:
					if item[1].val != living_neighbors[0][1].val:
						met_needs = true
				if not expanded:
					if living_neighbors:
						met_needs = true
						living_neighbors[0][1].survive = false
			survive = met_needs
		update_card()

func switch_pos(other_card, is_active, new_pos):
	#other card is the card this card is switching with, is_active determines who is moving and who is being moved
	var tween = $Tween
	var target_pos = other_card.position
	var my_pos = position
	if is_active:
		z_index = 64
		tween.interpolate_property(self, "position", position, Vector2(position.x, position.y - 8), 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
		tween.start()
		yield(tween, "tween_completed")
		tween.interpolate_property(self, "position", position, Vector2(target_pos.x, target_pos.y - 8), 0.4, Tween.TRANS_EXPO, Tween.EASE_IN_OUT)
		tween.start()
		yield(tween, "tween_completed")
		other_card.switch_pos(self, false, my_pos)
		tween.interpolate_property(self, "position", position, Vector2(target_pos.x, target_pos.y), 0.2, Tween.TRANS_EXPO, Tween.EASE_OUT)
		tween.start()
		drop()
	else:
		tween.interpolate_property(self, "position", position, new_pos, 0.2, Tween.TRANS_EXPO, Tween.EASE_IN_OUT)
		tween.start()
		update_card()

func _on_end_turn():
	if not survive:
		emit_signal("update_board_pos", [], grid_pos)
		queue_free()
	else:
		emit_signal("update_board_pos", self, grid_pos)
