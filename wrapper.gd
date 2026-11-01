extends Node

func _ready() -> void:
    var base: String = (get_script() as Script).resource_path.get_base_dir()
    ProjectSettings.load_resource_pack(base.path_join("sandbox.pck"))
    var mod: Node = load("res://sandbox.gd").new()
    mod.name = "SoboSandbox"
    get_tree().root.add_child.call_deferred(mod)
