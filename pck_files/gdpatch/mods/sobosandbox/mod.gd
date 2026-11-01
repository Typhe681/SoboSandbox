extends Node

const TEXT = {
    "en": "  scoring and achievements\n  are disabled within\n  sandbox mode",
    "cs": "  skóre a úspěchy\n  jsou vypnuté v\n  sandboxovém režimu",
    "de": "  Punkte und Erfolge\n  sind im Sandbox-Modus\n  deaktiviert",
    "es": "  puntuación y logros\n  están desactivados en\n  el modo sandbox",
    "it": "  punteggi e obiettivi\n  sono disattivati nella\n  modalità sandbox",
    "ja": "  スコアと実績は\n  サンドボックスモードでは\n  無効になります",
    "pl": "  wyniki i osiągnięcia\n  są wyłączone w\n  trybie sandbox",
    "ru": "  очки и достижения\n  отключены в режиме\n  песочницы",
    "sr": "  rezultati i dostignuća\n  su isključeni u\n  sandbox modu",
    "zh_CN": "  在沙盒模式中\n  计分和成就已被禁用",
    "zh_TW": "  在沙盒模式中\n  計分和成就已被停用",
}

const LABEL_PATH = "Main/Ui/MainHBox/RightSidePanel/ScoringDisabled"
const CFG := "user://sobosandbox.cfg"
var unrestricted_spawn := false
var toggle: SoboMenuButtonBool

var label: Label
var label_text := ""
var label_translate := Node.AUTO_TRANSLATE_MODE_INHERIT
var label_overridden := false
var load_armed := false
var load_timer := 0.0
var save_was_present := false
var achievements_before := false

func _process(dt: float) -> void:
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
    if not is_instance_valid(label):
        label = get_tree().root.get_node_or_null(LABEL_PATH)
        label_overridden = false
        if label == null:
            return
        label_text = label.text
        label_translate = label.auto_translate_mode
    if sandbox:
        if not label_overridden:
            label_overridden = true
            label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
        var loc := TranslationServer.get_locale()
        var txt: String = TEXT.get(loc, TEXT.get(loc.substr(0, 2), TEXT["en"]))
        if label.text != txt:
            label.text = txt
    elif label_overridden:
        label_overridden = false
        label.auto_translate_mode = label_translate
        label.text = label_text

func _ready() -> void:
    process_priority = 100
    var cf := ConfigFile.new()
    if cf.load(CFG) == OK:
        unrestricted_spawn = cf.get_value("sandbox", "unrestricted_spawn", false)
    SignalBus.on_game_mode_start.connect(on_game_mode_start)
    install_toggle()
    install_sandbox_button()
    GameModeManager.mode_names__mode_paths["mode_sandbox"] = "res://game_mode/mode_sandbox/mode_sandbox.tscn"
    Console.add_suggestion("mode_sandbox", "game mode")

func on_game_mode_start(mode) -> void:
    var sandbox: bool = mode != null and mode.scene_file_path.get_file().get_basename() == "mode_sandbox"
    set_online_blocked(sandbox)
    if not sandbox:
        ScoreManager.disable_scoring = false

func _physics_process(_dt: float) -> void:
    if GameModeManager.current_mode_name != "mode_sandbox":
        return
    var mode = GameModeManager.current_mode
    if not is_instance_valid(mode):
        return
    if Dev.pushing_danger_bumper_left:
        Dev.on_cheat.emit()
        mode.left.danger_bumper.rigidbody.apply_central_force(Vector2.LEFT * Dev.danger_bumper_push_force)
    if Dev.pushing_danger_bumper_right:
        Dev.on_cheat.emit()
        mode.right.danger_bumper.rigidbody.apply_central_force(Vector2.RIGHT * Dev.danger_bumper_push_force)

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

func clone_control(model: Control) -> Control:
    var copy: Control = model.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION)
    for prop: Dictionary in model.get_property_list():
        if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
            copy.set(prop.name, value_for_copy(model.get(prop.name), model, copy))
    return copy

func install_sandbox_button() -> void:
    var model: SoboMenuButton = null
    for i in 600:
        model = get_tree().root.find_child("ExtraModes", true, false)
        if model != null and model.is_node_ready():
            break
        await get_tree().process_frame
    if model == null:
        push_warning("sandbox: ExtraModes button not found")
        return
    var button: SoboMenuButton = clone_control(model)
    button.name = "Sandbox"
    button.label.text = "sandbox"
    button.release_press.connect(on_sandbox_pressed)
    model.add_sibling(button)
    button.show()

func on_sandbox_pressed() -> void:
    GameModeManager.start_game_mode_by_name("mode_sandbox")
    Menu._0.try_close()

func install_toggle() -> void:
    var model: SoboMenuButtonBool = null
    for i in 600:
        model = get_tree().root.find_child("LiveFriendScores", true, false)
        if model != null and model.is_node_ready():
            break
        await get_tree().process_frame
    if model == null:
        push_warning("sandbox: LiveFriendScores toggle not found")
        return
    var button: SoboMenuButtonBool = model.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION)
    for prop: Dictionary in model.get_property_list():
        if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
            button.set(prop.name, value_for_copy(model.get(prop.name), model, button))
    button.name = "UnrestrictedSpawn"
    button.label.text = "unrestricted spawn"
    button.tooltip_text = "spawn sobos anywhere, ignoring collisions (within sandbox mode)"
    button.release_press.connect(on_toggle_pressed)
    model.add_sibling(button)
    toggle = button
    toggle.set_value(unrestricted_spawn)

func on_toggle_pressed() -> void:
    unrestricted_spawn = not unrestricted_spawn
    toggle.set_value(unrestricted_spawn)
    var cf := ConfigFile.new()
    cf.set_value("sandbox", "unrestricted_spawn", unrestricted_spawn)
    cf.save(CFG)

func value_for_copy(value: Variant, original: Node, copy: Node) -> Variant:
    if value is Node:
        if value == original:
            return copy
        if original.is_ancestor_of(value):
            return copy.get_node_or_null(original.get_path_to(value))
        return value
    if value is Array:
        var mapped: Array = value.duplicate()
        for i in mapped.size():
            mapped[i] = value_for_copy(mapped[i], original, copy)
        return mapped
    return value

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
