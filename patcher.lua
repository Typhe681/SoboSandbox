print("Patcher loaded")

GDPatch.patch_script_as_text("ui/menu/screens/main_menu_screen/main_menu_screen.gdc", function(ctx, src)
    do
        local pat = "start_game_btn%.show%(%)"
        local s, e = src:find(pat)
        print("Extra modes patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. '\n\tbutton_container.get_node("ExtraModes").show()'
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("ui/menu/screens/extra_modes_screen/extra_modes_screen.gdc", function(ctx, src)
    do
        local pat = "$"
        local s, e = src:find(pat)
        print("Sandbox button patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. "\n" ..
                "func _ready() -> void:\n" ..
                "\tvar sandbox_button = preload(\"res://ui/button/sobo_menu_button.tscn\").instantiate()\n" ..
                "\tsandbox_button.name = \"sandbox\"\n" ..
                "\tsandbox_button.label.text = \"sandbox\"\n" ..
                "\t$VBoxContainer.add_child(sandbox_button)\n" ..
                "\tsandbox_button.release_press.connect(_on_sandbox_release_press)\n" ..
                "\n" ..
                "func _on_sandbox_release_press() -> void:\n" ..
                "\tGameModeManager.start_game_mode_by_name(\"mode_sandbox\")\n" ..
                "\tMenu._0.try_close()\n"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("main/dev.gdc", function(ctx, src)
    do
        local pat = "if debug_keys_enabled == false || Console%.is_open%(%):"
        local s, e = src:find(pat)
        print("Debug keys patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = 'debug_keys_enabled = GameModeManager.current_mode_name == "mode_sandbox"\n\t' .. m
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "var spawning_sobo: = false"
        local s, e = src:find(pat)
        print("Spawn var patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. "\nvar sandbox_unrestricted_spawn: = false"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "func start_spawn_drag%(%):"
        local s, e = src:find(pat)
        print("Spawn drag patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. '\n\tsandbox_unrestricted_spawn = GameModeManager.current_mode_name == "mode_sandbox" and SettingsManager.settings.unrestricted_spawn'
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "spawn_sobo_data = null"
        local s, e = src:find(pat)
        print("Spawn reset patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. "\n\tsandbox_unrestricted_spawn = false"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "mode_classic%.right%.danger_bumper%.rigidbody%.apply_central_force%(Vector2%.RIGHT %* danger_bumper_push_force%)"
        local s, e = src:find(pat)
        print("Bumper patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. "\n" ..
                '\tif GameModeManager.current_mode_name == "mode_sandbox":\n' ..
                "\t\tvar mode_sandbox = GameModeManager.current_mode\n" ..
                "\t\tif pushing_danger_bumper_left:\n" ..
                "\t\t\ton_cheat.emit()\n" ..
                "\t\t\tmode_sandbox.left.danger_bumper.rigidbody.apply_central_force(Vector2.LEFT * danger_bumper_push_force)\n" ..
                "\t\tif pushing_danger_bumper_right:\n" ..
                "\t\t\ton_cheat.emit()\n" ..
                "\t\t\tmode_sandbox.right.danger_bumper.rigidbody.apply_central_force(Vector2.RIGHT * danger_bumper_push_force)\n"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "SaveLoadManager%.load%(%)"
        local s, e = src:find(pat)
        print("Keep save on load patch: " .. (s and 1 or 0))
        if s then
            local new = "if SaveLoadManager.has_save(): await SaveLoadManager.load(); SaveLoadManager.save()"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("game_elements/sobo/sobo_manager.gdc", function(ctx, src)
    do
        local pat = "if point_is_inside_any%(pos%):"
        local s, e = src:find(pat)
        print("Inside check patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = "if not Dev.sandbox_unrestricted_spawn and point_is_inside_any(pos):"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "if Main%._0%.dss%.intersect_shape%(fitting_query_params, 1%)%.is_empty%(%)"
        local s, e = src:find(pat)
        print("Collision check patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = "if Dev.sandbox_unrestricted_spawn or Main._0.dss.intersect_shape(fitting_query_params, 1).is_empty()"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("settings.gdc", function(ctx, src)
    do
        local pat = '@export var language: String = ""'
        local s, e = src:find(pat)
        print("Unrestricted spawn setting patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. "\n@export var unrestricted_spawn: bool = false"
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("ui/menu/screens/settings_screen/settings_screen.gdc", function(ctx, src)
    do
        local pat = "fullscreen_control%.set_value%(SettingsManager%.settings%.fullscreen%)"
        local s, e = src:find(pat)
        print("Settings refresh patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. "\n" ..
                '\tif not has_node("MainControlList/UnrestrictedSpawn"):\n' ..
                '\t\tvar spawn_btn = preload("res://ui/button/bool/sobo_menu_button_bool.tscn").instantiate()\n' ..
                '\t\tspawn_btn.name = "UnrestrictedSpawn"\n' ..
                '\t\tspawn_btn.tooltip_text = "spawn sobos anywhere, ignoring collisions (within sandbox mode)"\n' ..
                '\t\tvar list = get_node("MainControlList")\n' ..
                "\t\tlist.add_child(spawn_btn)\n" ..
                '\t\tlist.move_child(spawn_btn, list.get_node("LiveFriendScores").get_index() + 1)\n' ..
                '\t\tspawn_btn.get_node("MarginContainer/HBoxContainer/Label").text = "unrestricted spawn"\n' ..
                "\t\tspawn_btn.release_press.connect(_on_unrestricted_spawn_release_press)\n" ..
                '\tget_node("MainControlList/UnrestrictedSpawn").set_value(SettingsManager.settings.unrestricted_spawn)'
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "func _on_game_release_press%(%)"
        local s, e = src:find(pat)
        print("Settings handler patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = "func _on_unrestricted_spawn_release_press() -> void:\n" ..
                "\tSettingsManager.settings.unrestricted_spawn = not SettingsManager.settings.unrestricted_spawn\n" ..
                '\tvar control = get_node("MainControlList/UnrestrictedSpawn")\n' ..
                "\tcontrol.set_value(SettingsManager.settings.unrestricted_spawn)\n" ..
                "\tSettingsManager.apply_settings()\n" ..
                "\n" .. m
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("game_mode/game_mode_manager.gdc", function(ctx, src)
    do
        local pat = '\t\tConsole%.add_suggestion%(mode_name, "game mode"%)'
        local s, e = src:find(pat)
        print("GameModeManager registration patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. "\n" ..
                '\tmode_names__mode_paths["mode_sandbox"] = "res://game_mode/mode_sandbox/mode_sandbox.tscn"\n' ..
                '\tConsole.add_suggestion("mode_sandbox", "game mode")'
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    do
        local pat = "current_mode_name = mode_path%.get_file%(%)%.get_basename%(%)"
        local s, e = src:find(pat)
        print("Scoring reset patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. '\n\t\tif current_mode_name != "mode_sandbox":\n\t\t\tScoreManager.disable_scoring = false'
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("score_manager.gdc", function(ctx, src)
    do
        local pat = "func upload_steam_score%([^)]*%)%s*:%s*\n"
        local s, e = src:find(pat)
        print("Steam score patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. '\tif GameModeManager.current_mode_name == "mode_sandbox":\n\t\treturn\n'
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)

GDPatch.patch_script_as_text("achievement_tracker.gdc", function(ctx, src)
    do
        local pat = "func unlock%([^)]*%)%s*:%s*\n"
        local s, e = src:find(pat)
        print("Achievement unlock patch: " .. (s and 1 or 0))
        if s then
            local m = src:sub(s, e)
            local new = m .. '\tif GameModeManager.current_mode_name == "mode_sandbox":\n\t\treturn\n'
            src = src:sub(1, s - 1) .. new .. src:sub(e + 1)
        end
    end
    return src
end)