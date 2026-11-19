extends Node

const TEXT = {
	"en": "scoring and achievements\nare disabled within\nsandbox mode",
	"cs": "skóre a úspěchy\njsou vypnuté v\nsandboxovém režimu",
	"de": "Punkte und Erfolge\nsind im Sandbox-Modus\ndeaktiviert",
	"es": "puntuación y logros\nestán desactivados en\nel modo sandbox",
	"fr": "le score et les succès\nsont désactivés en\nmode bac à sable",
	"hu": "a pontszámítás és a\nteljesítmények le vannak\ntiltva a sandbox módban",
	"id": "skor dan pencapaian\ndinonaktifkan dalam\nmode sandbox",
	"it": "punteggi e obiettivi\nsono disattivati nella\nmodalità sandbox",
	"ja": "スコアと実績は\nサンドボックス\nモードでは\n無効になります",
	"ko": "스코어와 업적은\n샌드박스 모드에서\n비활성화됩니다",
	"nl": "scores en prestaties\nzijn uitgeschakeld in\nde sandbox-modus",
	"pl": "wyniki i osiągnięcia\nsą wyłączone w\ntrybie sandbox",
	"pt_BR": "pontuação e conquistas\nestão desativadas no\nmodo sandbox",
	"ro": "punctajul și realizările\nsunt dezactivate în\nmodul sandbox",
	"ru": "очки и достижения\nотключены в режиме\nпесочницы",
	"sr": "rezultati i dostignuća\nsu isključeni u\nsandbox modu",
	"tr": "puanlama ve başarımlar\nsandbox modunda\ndevre dışı bırakıldı",
	"uk": "оцінка та досягнення\nвимкнені в режимі\nпісочниці",
	"vi": "điểm số và thành tựu\nbị vô hiệu hóa trong\nchế độ sandbox",
	"zh_CN": "在沙盒模式中\n计分和成就已被禁用",
	"zh_TW": "在沙盒模式中\n計分和成就已被停用",
}

const CFG := "user://sobosandbox.cfg"
var unrestricted_spawn := false
var broadcaster_connected := false

var label: Label
var label_text := ""
var label_translate := Node.AUTO_TRANSLATE_MODE_INHERIT
var label_overridden := false
var load_armed := false
var load_timer := 0.0
var save_was_present := false
var achievements_before := false
var panel_label: Label
var logo_patched := false

func get_right_panel() -> Node:
	return get_tree().root.find_child("RightSidePanel", true, false)

func update_sandbox_label(sandbox: bool) -> void:
	if sandbox:
		if not is_instance_valid(panel_label):
			var panel := get_right_panel()
			if panel == null:
				return
			panel_label = Label.new()
			panel_label.name = "SandboxScoringDisabled"
			panel_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			panel_label.theme = panel.theme
			
			panel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			panel_label.offset_left = 40
			panel_label.offset_right = -20
			panel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			panel_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			
			panel_label.add_theme_color_override("font_color", Color("#ff0000"))
			panel.add_child(panel_label)
			
		var loc := TranslationServer.get_locale()
		var txt: String = TEXT.get(loc, TEXT.get(loc.substr(0, 2), TEXT["en"]))
		
		if panel_label.text != txt:
			panel_label.text = txt
			
	elif is_instance_valid(panel_label):
		panel_label.queue_free()
		panel_label = null

func patch_mode_logo() -> void:
	if logo_patched:
		return

	for screen in get_tree().root.find_children("*", "GameModesScreen", true, false):
		for i in screen.mode_names.size():
			if screen.mode_names[i] == "sandbox":
				screen.mode_buttons[i].logo.mark = ModeLogo.Mark.CUSTOM
				logo_patched = true
				return

func _process(dt: float) -> void:
	try_connect_broadcaster()
	var present: bool = SaveLoadManager.has_save()
	if load_armed:
		load_timer += dt
		if not present:
			load_armed = false
			SaveLoadManager.save()
		elif load_timer > 10:
			load_armed = false
	save_was_present = present
	var sandbox: bool = GameModeManager.current_mode_name == "mode_sandbox"
	if sandbox and unrestricted_spawn and Dev.spawning_sobo:
		Dev.spawn_sobo_data = SoboManager.get_closest_sobo_data_to_radius(Dev.spawn_sobo_target_radius)
	Dev.debug_keys_enabled = sandbox
	update_sandbox_label(sandbox)
	patch_mode_logo()

var mode_res: GameMode

func register_mode() -> void:
	mode_res = GameMode.new()
	mode_res.scene_path = "res://game_mode/game_modes/sandbox/scene_sandbox.tscn"
	mode_res.description = "Classic, but with dev hotkeys, no scores, and no achievements!"
	mode_res.horizontal = true
	mode_res.allows_start_clutter = true
	mode_res.take_over_path("res://game_mode/game_modes/sandbox/%s.tres" % "mode_sandbox")
	GameModeManager.game_modes.append(mode_res)
	GameModeManager.game_modes_by_name["mode_sandbox"] = mode_res
	Console.add_suggestion("mode_sandbox", "game mode")

func _ready() -> void:
	process_priority = 100
	load_config()
	try_connect_broadcaster()
	SignalBus.on_game_mode_start.connect(on_game_mode_start)
	register_mode()

func load_config() -> void:
	var cf := ConfigFile.new()
	cf.load(CFG)
	unrestricted_spawn = cf.get_value("unrestricted_spawn", "value", false)
	write_config()

func write_config() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "name", "SoboSandbox")
	cf.set_value("meta", "description", "Configure SoboSandbox")
	cf.set_value("unrestricted_spawn", "type", "bool")
	cf.set_value("unrestricted_spawn", "label", "unrestricted spawn")
	cf.set_value("unrestricted_spawn", "description", "spawn sobos anywhere, ignoring collisions (within sandbox mode)")
	cf.set_value("unrestricted_spawn", "value", unrestricted_spawn)
	cf.save(CFG)

func try_connect_broadcaster() -> void:
	if broadcaster_connected:
		return
	var broadcaster = get_tree().root.get_meta("modsettings_broadcaster", null)
	if broadcaster:
		broadcaster.config_changed.connect(on_config_changed)
		broadcaster_connected = true

func on_config_changed(path: String, section: String, value: Variant) -> void:
	if path.get_file() != CFG.get_file():
		return
	match section:
		"unrestricted_spawn":
			unrestricted_spawn = value

func on_game_mode_start(_scene) -> void:
	var sandbox: bool = GameModeManager.current_mode_name == "mode_sandbox"
	set_online_blocked(sandbox)
	if not sandbox:
		ScoreManager.disable_scoring = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.pressed:
		if not Dev.debug_keys_enabled or Console.is_open():
			return
		match event.keycode:
			KEY_KP_SUBTRACT:
				load_armed = save_was_present
				load_timer = 0.0
			KEY_KP_MULTIPLY:
				load_armed = false

func set_online_blocked(blocked: bool) -> void:
	var connected: bool = SignalBus.on_game_over.is_connected(ScoreManager.on_game_over)
	if blocked:
		achievements_before = AchievementTracker.disable_achievements
		AchievementTracker.disable_achievements = true
		if connected:
			SignalBus.on_game_over.disconnect(ScoreManager.on_game_over)
	else:
		AchievementTracker.disable_achievements = achievements_before
		if not connected:
			var others: Array = SignalBus.on_game_over.get_connections()
			for c: Dictionary in others:
				SignalBus.on_game_over.disconnect(c.callable)
			SignalBus.on_game_over.connect(ScoreManager.on_game_over)
			for c: Dictionary in others:
				SignalBus.on_game_over.connect(c.callable, c.flags)

