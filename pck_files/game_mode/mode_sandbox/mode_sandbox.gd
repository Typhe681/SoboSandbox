extends GameMode
class_name ModeSandbox

@export var left: ModeClassicSide
@export var right: ModeClassicSide
@export var float_bar: FloatBar
@export var danger_bumper_beam: ColorRect
@export var pre_gameover_timer: Timer
@export var start_clutterer: Clutterer
@export_group("Audio")
@export var select_sfx: AudioStreamPlayer2D
@export var cancel_sfx: AudioStreamPlayer2D
@export var launch_sfx: AudioStreamPlayer2D
@export var loss_of_control_sfx: AudioStreamPlayer2D
@export_group("Settings")
@export var demo_bumper_y: = 15.0
@export var max_launch_velocity: = 850.0
@export var safety_spawn_duration: = 3.0
@export var ticks_between_spawns: = 2

enum State{PLAYING, PREGAMEOVER, GAMEOVER}
var state: = State.PLAYING


var last_spawned_side: ModeClassicSide
var spawn_tick_delay: int = 0
var safety_spawn_timer: float = 0.0
var previously_hovered_sobo: Sobo
var hovered_sobo: Sobo
var launching: = false
var launching_sobo: Sobo
var initial_launch_offset: Vector2 = Vector2.ZERO
var launch_mag_passed_cancellable_threshold: = false
var normalized_launch_vector: Vector2

var sobos_emerging: Array[Sobo] = []
var sobos_selectable: Array[Sobo] = []
var sobos_in_stack: Array[Sobo] = []


func _ready() -> void :
	super ()
	Dev.on_cheat.emit()
	SignalBus.on_sobo_exit_tree.connect(on_sobo_exit_tree)
	SignalBus.on_dev_spawn.connect(enter_stack)
	start_clutterer.spawned.connect(enter_stack)
	connect_input_signals()
	SettingsManager.on_settings_applied.connect(connect_input_signals)
	if OS.has_feature("demo"):
		left.danger_bumpers.position.y = demo_bumper_y
		right.danger_bumpers.position.y = demo_bumper_y
	if SettingsManager.settings.start_clutter:
		start_clutterer.active = true
	last_spawned_side = left

func _exit_tree() -> void :
	SignalBus.on_sobo_exit_tree.disconnect(on_sobo_exit_tree)
	SignalBus.on_dev_spawn.disconnect(enter_stack)
	super ()

func connect_input_signals():
	disconnect_input_signals()

	PlayerInput.on_click_pressed.connect(start_launch_drag)
	PlayerInput.on_click_released.connect(end_launch_drag)
	PlayerInput.on_right_click_pressed.connect(cancel_launch)

	PlayerInput.on_dpad_direction.connect(hover_sobo_in_dir)
	PlayerInput.on_left_trigger_pressed.connect(gamepad_launch)
	PlayerInput.on_right_trigger_pressed.connect(gamepad_launch)
	if SettingsManager.settings.swap_sticks:
		PlayerInput.on_new_right_stick_direction.connect(hover_sobo_in_dir)
	else:
		PlayerInput.on_new_left_stick_direction.connect(hover_sobo_in_dir)
	if SettingsManager.settings.bumpers_select:
		PlayerInput.on_left_shoulder_pressed.connect(hover_sobo_in_dir.bind(Vector2.LEFT))
		PlayerInput.on_right_shoulder_pressed.connect(hover_sobo_in_dir.bind(Vector2.RIGHT))
	else:
		PlayerInput.on_left_shoulder_pressed.connect(gamepad_launch)
		PlayerInput.on_right_shoulder_pressed.connect(gamepad_launch)

func disconnect_input_signals():
	if PlayerInput.on_click_pressed.is_connected(start_launch_drag):
		PlayerInput.on_click_pressed.disconnect(start_launch_drag)
	if PlayerInput.on_click_released.is_connected(end_launch_drag):
		PlayerInput.on_click_released.disconnect(end_launch_drag)
	if PlayerInput.on_right_click_pressed.is_connected(cancel_launch):
		PlayerInput.on_right_click_pressed.disconnect(cancel_launch)
	if PlayerInput.on_new_left_stick_direction.is_connected(hover_sobo_in_dir):
		PlayerInput.on_new_left_stick_direction.disconnect(hover_sobo_in_dir)
	if PlayerInput.on_new_right_stick_direction.is_connected(hover_sobo_in_dir):
		PlayerInput.on_new_right_stick_direction.disconnect(hover_sobo_in_dir)
	if PlayerInput.on_dpad_direction.is_connected(hover_sobo_in_dir):
		PlayerInput.on_dpad_direction.disconnect(hover_sobo_in_dir)
	if PlayerInput.on_left_shoulder_pressed.is_connected(hover_sobo_in_dir.bind(Vector2.LEFT)):
		PlayerInput.on_left_shoulder_pressed.disconnect(hover_sobo_in_dir.bind(Vector2.LEFT))
	if PlayerInput.on_right_shoulder_pressed.is_connected(hover_sobo_in_dir.bind(Vector2.RIGHT)):
		PlayerInput.on_right_shoulder_pressed.disconnect(hover_sobo_in_dir.bind(Vector2.RIGHT))
	if PlayerInput.on_left_shoulder_pressed.is_connected(gamepad_launch):
		PlayerInput.on_left_shoulder_pressed.disconnect(gamepad_launch)
	if PlayerInput.on_right_shoulder_pressed.is_connected(gamepad_launch):
		PlayerInput.on_right_shoulder_pressed.disconnect(gamepad_launch)
	if PlayerInput.on_left_trigger_pressed.is_connected(gamepad_launch):
		PlayerInput.on_left_trigger_pressed.disconnect(gamepad_launch)
	if PlayerInput.on_right_trigger_pressed.is_connected(gamepad_launch):
		PlayerInput.on_right_trigger_pressed.disconnect(gamepad_launch)


func _physics_process(dt: float) -> void :
	match state:
		State.PLAYING:
			pp_state_playing(dt)

func pp_state_playing(dt: float):
	match PlayerInput.get_gameplay_input_device():
		PlayerInput.InputDevice.MOUSE: pp_mouse()
		PlayerInput.InputDevice.GAMEPAD: pp_gamepad()
		PlayerInput.InputDevice.TOUCH: pp_touch()
	pp_spawning(dt)
	if pregameover_condition_met():
		enter_state_pregameover()



func pp_gamepad():
	var aim_stick: Vector2 = PlayerInput.left_stick if SettingsManager.settings.swap_sticks else PlayerInput.right_stick
	if launching:
		var v: Vector2 = aim_stick.rotated(Cam._0.rotation)
		v = Kf.clamp_magnitude2(v, 1.0)
		normalized_launch_vector = v
		if v == Vector2.ZERO:
			launching = false
			launching_sobo = null
			Ui._0.mouse_hovering_disabled = false
	else:
		if aim_stick != Vector2.ZERO:
			start_launch_drag()

func pp_mouse():
	if launching:
		pp_pointer_aim()
	else:
		hovered_sobo = SoboManager.get_closest_sobo_center(PlayerInput.cursor_pos, 128.0, sobos_selectable)

func pp_touch():
	if launching:
		pp_pointer_aim()

	hovered_sobo = null

func pp_pointer_aim() -> void :
	var p0: Vector2 = launching_sobo.center
	var p1: Vector2 = PlayerInput.cursor_pos + initial_launch_offset
	var dir: Vector2 = p0.direction_to(p1)
	var pointer_mag: float = p0.distance_to(p1)
	pointer_mag = min(pointer_mag, LaunchArrow._0.max_length)
	var nrm: float = pointer_mag / LaunchArrow._0.max_length
	normalized_launch_vector = nrm * dir
	if launch_mag_passed_cancellable_threshold:
		if normalized_launch_vector.length() < 0.1 && launching_sobo.avg_velocity.length() < 40.0:
			cancel_launch()
			return
	if normalized_launch_vector.length() > 0.25:
		launch_mag_passed_cancellable_threshold = true


func pp_spawning(dt: float):

	spawn_tick_delay -= 1
	if spawn_tick_delay <= 0:

		var preferred_side: ModeClassicSide = other_side(last_spawned_side)
		if preferred_side.can_spawn():
			spawn_sobo_on_side(preferred_side)
		elif last_spawned_side.can_spawn():
			spawn_sobo_on_side(last_spawned_side)

		if safety_spawn_condition():
			safety_spawn_timer += dt
			if safety_spawn_timer >= safety_spawn_duration:
				spawn_sobo_on_side(left, true)
				spawn_sobo_on_side(right, true)

	if safety_spawn_condition() == false:
		safety_spawn_timer = 0.0


func spawn_sobo_on_side(side: ModeClassicSide, safety_spawn: = false) -> Sobo:
	last_spawned_side = side
	spawn_tick_delay = ticks_between_spawns
	var new_sobo_size_tier: int = spawn_pool.get_size_tier(side.ray_detector.get_collided_size_tiers())
	if new_sobo_size_tier == -1:
		return null
	var new_sobo: Sobo = SoboManager.create(new_sobo_size_tier, side.ray_detector.global_position)
	enter_emerging(new_sobo)
	if safety_spawn:
		SignalBus.on_safety_spawn.emit(new_sobo)
	new_sobo.set_collision_mask_value(Layer.STRUCTURE, false)
	new_sobo.set_collision_layer_value(Layer.ENTERING_SUBA, true)
	if safety_spawn:
		side.ray_gauge.trigger_danger()
	else:
		side.ray_gauge.trigger_flash()
	var velocity_direction: Vector2 = side.ray_detector.global_position.direction_to(float_bar.global_position)
	new_sobo.set_velocity(velocity_direction * 400.0)
	return new_sobo


func enter_state_pregameover():
	SaveLoadManager.delete()
	danger_bumper_beam.show()
	cancel_launch()
	LaunchArrow._0.enabled = false
	Pauser._0.add_pause_request(Main._0)
	state = State.PREGAMEOVER
	if instructions:
		instructions.queue_free()
	loss_of_control_sfx.play()
	Ui._0.negative.modulate.a = 1.0
	Cam._0.vibrate(20.0)
	MobileManager.haptic(1.0, 0.2)
	left.danger_bumper.lock_in_and_disable()
	right.danger_bumper.lock_in_and_disable()
	pre_gameover_timer.start()

	pre_gameover_timer.timeout.connect(on_pre_gameover_timer_timeout)
	SignalBus.on_pre_game_over.emit()

func on_pre_gameover_timer_timeout():
	SignalBus.on_game_over.emit()
	state = State.GAMEOVER


func _process(_dt: float):
	if hovered_sobo:
		if previously_hovered_sobo != hovered_sobo:
			previously_hovered_sobo = hovered_sobo
			Ui._0.play_hover_sound(true)
	else:
		previously_hovered_sobo = null
	var cs: Style = StyleManager.current_style
	if launching:
		SoboOutline._0.outline(launching_sobo, cs.sobo_marker_color, cs.sobo_select_outline_thickness)
		Cam._0.push( - normalized_launch_vector * 1.0 * launching_sobo.data.total_mass, launching_sobo.center)
		var smoothing: bool = PlayerInput.input_device == PlayerInput.InputDevice.GAMEPAD
		LaunchArrow._0.set_arrow(launching_sobo.center, normalized_launch_vector * LaunchArrow._0.max_length, smoothing)
	else:

		SoboOutline._0.outline(hovered_sobo, cs.sobo_marker_color, cs.sobo_hover_outline_thickness)
		LaunchArrow._0.enabled = false
	left.ray_gauge.set_line_progress(safety_spawn_timer / safety_spawn_duration, left.ray_gauge.special)
	right.ray_gauge.set_line_progress(safety_spawn_timer / safety_spawn_duration, right.ray_gauge.special)



func hover_sobo_in_dir(dir: Vector2) -> void :
	if PlayerInput.get_gameplay_input_device() != PlayerInput.InputDevice.GAMEPAD:
		return
	if dir == Vector2.ZERO:
		return
	dir = dir.rotated(Cam._0.rotation)
	if launching_sobo:
		launching_sobo = SoboManager.get_nearest_other_sobo_in_dir(launching_sobo, Vector2(dir), sobos_selectable)
		hovered_sobo = launching_sobo
	else:
		if hovered_sobo:
			hovered_sobo = SoboManager.get_nearest_other_sobo_in_dir(hovered_sobo, Vector2(dir), sobos_selectable)
		else:
			hovered_sobo = SoboManager.get_furthest_sobo_in_dir(dir, sobos_selectable)

func start_launch_drag() -> void :

	var sobo: Sobo
	if PlayerInput.get_gameplay_input_device() == PlayerInput.InputDevice.TOUCH:
		sobo = SoboManager.get_closest_sobo_center(PlayerInput.cursor_pos, 128.0, sobos_selectable)
	else:
		sobo = hovered_sobo
	if sobo == null:
		return
	launching = true
	launching_sobo = sobo
	initial_launch_offset = launching_sobo.center - PlayerInput.cursor_pos
	Ui._0.mouse_hovering_disabled = true

	if PlayerInput.get_gameplay_input_device() != PlayerInput.InputDevice.GAMEPAD:
		select_sfx.global_position = sobo.center
		select_sfx.pitch_scale = 5000.0 / sobo.data.outer_circle.area
		select_sfx.volume_db = 0.0 - 3.0 * log(select_sfx.pitch_scale) / log(2.0)
		select_sfx.play()
		MobileManager.haptic(0.5)

func gamepad_launch() -> void :

	var sobo: Sobo = launching_sobo
	if sobo == null:
		sobo = hovered_sobo
	if sobo:
		launch_sobo(sobo, normalized_launch_vector)
		launching = false
		if PlayerInput.get_gameplay_input_device() == PlayerInput.InputDevice.TOUCH:
			hovered_sobo = null
		else:
			hovered_sobo = SoboManager.get_closest_sobo_center(sobo.center, 512.0, sobos_selectable)
		launching_sobo = null
		Ui._0.mouse_hovering_disabled = false

func end_launch_drag() -> void :
	launch_mag_passed_cancellable_threshold = false
	var sobo: Sobo = launching_sobo
	if sobo:
		launch_sobo(sobo, normalized_launch_vector)
		launching = false
		if PlayerInput.get_gameplay_input_device() == PlayerInput.InputDevice.TOUCH:
			hovered_sobo = null
		else:
			hovered_sobo = SoboManager.get_closest_sobo_center(sobo.center, 512.0, sobos_selectable)
		launching_sobo = null
		Ui._0.mouse_hovering_disabled = false

func cancel_launch() -> void :
	launch_mag_passed_cancellable_threshold = false
	if launching:
		cancel_sfx.global_position = launching_sobo.center
		cancel_sfx.play()
		launching = false
		launching_sobo = null
		Ui._0.mouse_hovering_disabled = false

func launch_sobo(sobo: Sobo, nrm_vel: Vector2):
	enter_stack(sobo)
	SignalBus.on_sobo_launch.emit(sobo, nrm_vel)
	sobo.add_velocity(nrm_vel * max_launch_velocity)
	launch_sfx.global_position = sobo.center
	launch_sfx.pitch_scale = 0.5 + nrm_vel.length() * 2.0
	launch_sfx.volume_linear = 0.2 + nrm_vel.length() * 0.5
	launch_sfx.play()
	Cam._0.push(normalized_launch_vector * 8.0 * sobo.data.total_mass, sobo.center)

func on_sobo_merge(old_sobo0: Sobo, old_sobo1: Sobo, new_sobo: Sobo):
	if launching_sobo == old_sobo0 || launching_sobo == old_sobo1:
		launching_sobo = new_sobo
	if hovered_sobo == old_sobo0 || hovered_sobo == old_sobo1:
		hovered_sobo = new_sobo
	var either_on_bar: = is_on_bar(old_sobo0) || is_on_bar(old_sobo1)
	remove_from_role_lists(old_sobo0)
	remove_from_role_lists(old_sobo1)
	if either_on_bar:
		enter_selectable(new_sobo)
	else:
		enter_stack(new_sobo)
	var new_score: = calculate_score()
	if new_score != ScoreManager.current_score:
		SignalBus.on_gain_score.emit(new_score - ScoreManager.current_score)

func enter_emerging(sobo: Sobo):
	remove_from_role_lists(sobo)
	sobos_emerging.append(sobo)
	float_bar.sobos.append(sobo)
	sobo.allow_merges = false
	sobo.set_collision_layer_value(Layer.BAR_SUBA, true)
	SignalBus.on_sobo_join_bar.emit(sobo)

func enter_selectable(sobo: Sobo):
	var was_on_bar: = is_on_bar(sobo)
	remove_from_role_lists(sobo)
	sobos_selectable.append(sobo)
	float_bar.sobos.append(sobo)
	sobo.allow_merges = true
	sobo.set_collision_layer_value(Layer.BAR_SUBA, true)
	if was_on_bar == false:
		SignalBus.on_sobo_join_bar.emit(sobo)

func enter_stack(sobo: Sobo):
	var was_on_bar: = is_on_bar(sobo)
	remove_from_role_lists(sobo)
	sobos_in_stack.append(sobo)
	sobo.set_collision_layer_value(Layer.BAR_SUBA, false)
	if was_on_bar:
		SignalBus.on_sobo_leave_bar.emit(sobo)

func remove_from_role_lists(sobo: Sobo):
	sobos_emerging.erase(sobo)
	sobos_selectable.erase(sobo)
	sobos_in_stack.erase(sobo)
	float_bar.sobos.erase(sobo)

func on_sobo_exit_tree(sobo: Sobo):
	if sobo == hovered_sobo:
		hovered_sobo = null
	if sobo == launching_sobo:
		launching_sobo = null
		launching = false
	remove_from_role_lists(sobo)

func msg_sobo_arrays():
	Msg.corner("sobos_on_bar", "sobos_on_bar: " + get_sobo_array_string(float_bar.sobos))
	Msg.corner("sobos_emerging", "sobos_emerging: " + get_sobo_array_string(sobos_emerging))
	Msg.corner("sobos_selectable", "sobos_selectable: " + get_sobo_array_string(sobos_selectable))
	Msg.corner("sobos_in_stack", "sobos_in_stack: " + get_sobo_array_string(sobos_in_stack))


func pregameover_condition_met():
	# return left.danger_bumper.holding && right.danger_bumper.holding
	return false

func calculate_score() -> int:
	var sum: = 0
	for s: Sobo in SoboManager.all_sobos:
		if s.merged == false: continue
		if s.merged_this_frame: continue
		sum += s.data.doubling_tier
	return sum

func _on_collision_reenabler_body_exited(body: Node2D) -> void :
	if body is Suba:
		var suba: Suba = body
		var sobo: Sobo = suba.sobo
		if sobo in sobos_selectable:
			return
		if get_reenabled_suba_count(suba.sobo) > suba.sobo.subas.size() / 2:
			enter_selectable(suba.sobo)

func get_reenabled_suba_count(sobo: Sobo) -> int:
	var count: = 0
	for suba: Suba in sobo.subas:
		if suba.get_collision_mask_value(Layer.STRUCTURE) == false:
			count += 1
	return count

func safety_spawn_condition():
	return left.can_spawn() == false\
	&& right.can_spawn() == false\
	&& float_bar.sobos.size() == 0

func other_side(side: ModeClassicSide) -> ModeClassicSide:
	return left if side == right else right

func is_on_bar(sobo: Sobo) -> bool:
	return sobos_emerging.has(sobo) || sobos_selectable.has(sobo)

func get_sobo_array_string(array: Array[Sobo]) -> String:
	var s: = ""
	for sobo: Sobo in array:
		s += str(sobo.data.doubling_tier) + " "
	return s


func capture_game_state() -> GameState:
	var gs: = ModeClassicGameState.new()
	gs.score = ScoreManager.current_score
	gs.last_spawned_side_left = last_spawned_side == left
	gs.spawn_tick_delay = spawn_tick_delay
	gs.safety_spawn_timer = safety_spawn_timer
	gs.left_danger_bumper = left.danger_bumper.capture_danger_bumper_state()
	gs.right_danger_bumper = right.danger_bumper.capture_danger_bumper_state()
	gs.spawn_pool = spawn_pool.capture_spawn_pool_state()
	gs.instructions = instructions.capture_instructions_state()
	gs.sobos_emerging = capture_sobo_array(sobos_emerging)
	gs.sobos_selectable = capture_sobo_array(sobos_selectable)
	gs.sobos_in_stack = capture_sobo_array(sobos_in_stack)
	return gs

func can_save_game_state() -> bool:
	return state == State.PLAYING

func apply_game_state(state: GameState) -> void :
	var gs: = state as ModeClassicGameState
	start_clutterer.active = false
	SoboManager.free_all()
	ScoreManager.set_score(gs.score)
	last_spawned_side = left if gs.last_spawned_side_left else right
	spawn_tick_delay = gs.spawn_tick_delay
	safety_spawn_timer = gs.safety_spawn_timer
	left.danger_bumper.apply_danger_bumper_state(gs.left_danger_bumper)
	right.danger_bumper.apply_danger_bumper_state(gs.right_danger_bumper)
	spawn_pool.apply_spawn_pool_state(gs.spawn_pool)
	instructions.apply_instructions_state(gs.instructions)
	sobos_emerging = spawn_from_states(gs.sobos_emerging)
	sobos_selectable = spawn_from_states(gs.sobos_selectable)
	sobos_in_stack = spawn_from_states(gs.sobos_in_stack)
	float_bar.sobos.clear()
	float_bar.sobos.append_array(sobos_emerging)
	float_bar.sobos.append_array(sobos_selectable)

func capture_sobo_array(sobos: Array[Sobo]) -> Array[SoboState]:
	var states: Array[SoboState] = []
	for sobo: Sobo in sobos:
		states.append(sobo.capture_sobo_state())
	return states

func spawn_from_states(states: Array[SoboState]) -> Array[Sobo]:
	var created: Array[Sobo] = []
	for sobo_state: SoboState in states:
		var sobo: Sobo = SoboManager.create(sobo_state.size_tier, sobo_state.get_center())
		sobo.apply_sobo_state(sobo_state)
		created.append(sobo)
	return created
