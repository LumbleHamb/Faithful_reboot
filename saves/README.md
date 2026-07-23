# saves/

This folder is **not** the runtime save location.

`SaveManager` writes to `user://saves/` — Godot's platform-specific writable
directory (e.g. `%APPDATA%/Godot/app_userdata/...` on Windows) — never
`res://saves/`. Once a game is exported, `res://` is packed read-only, so a
manager writing here would work in the editor and silently fail in a real
build.

This folder exists only to reserve the path in the project structure
requested for Phase 1. It stays empty unless a future phase deliberately
ships bundled example/starter save data. See
`docs/IMPLEMENTATION_STATUS.md` for the full reasoning.
