# SoboSandbox
A Sobosuba mod which adds a sandbox gamemode that:
- unlocks developer hotkeys
- prevents gameover
- locks achievements + scores

Tested on Sobosuba v1.2.3


## Installation:

Extract `sobosandbox.zip` from the [latest release](https://github.com/Typhe681/SoboSandbox/releases/latest) next to `sobosuba.exe`

It should look like this:
```
├── sobosuba.exe
├── override.cfg
└── mods
    └── sobosandbox
        ├── wrapper.gd
        └── sandbox.pck
```
If `override.cfg` already exists due to another mod, add `SoboSandbox="mods/sobosandbox/wrapper.gd"` to the `[autoload]` section


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
| Numpad+ | Save game |
| Numpad- | Load game |
| Numpad* | Clear save |

¹collision check can be disabled in settings with the 'unrestricted spawn' toggle
