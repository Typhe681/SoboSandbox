# SoboSandbox
A Sobosuba mod which adds a sandbox gamemode that:
- unlocks developer hotkeys
- prevents gameover
- locks achievements + scores

Tested on Sobosuba v1.2.3


## Installation:

Extract `sobosandbox.zip` from the [latest release](https://github.com/Typhe681/SoboSandbox/releases/latest) into Sobosuba's userdata folder

* **Windows:** `%APPDATA%\Godot\app_userdata\sobosuba`
* **Linux:** `~/.local/share/godot/app_userdata/sobosuba`


It should look like this:
```
├── styles
|   └── sandbox_bootstrap.tres
└── sobosandbox
    ├── sandbox.gd
    ├── scene_sandbox.gd
    └── scene_sandbox.tscn
```


## Hotkeys:
| Key | Description |
| --- | --- |
| S | Spawn sobo¹ |
| Shift + S | Fill board with sobos |
| X | Delete sobo |
| Shift + X | Delete all sobos |
| D | Drag sobo |
| V | Toggle debug sobo rendering |
| Q / E | Press bumpers in |
| C | Shockwave |
| L | Cycle language |
| P | Load replay² |
| Numpad+ | Save game |
| Numpad- | Load game |
| Numpad* | Clear save |

¹collision check can be disabled in settings with the 'unrestricted spawn' toggle
²there's currently no way to resume after loading a replay, so just quit the game then resume