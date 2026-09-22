# Named saves

Menu → Save opens a paused name dialog. Save confirms and closes; Cancel/ESC
returns without writing. Names are trimmed, capped at 64 characters, and may
contain spaces or Unicode. Replacing a different existing slot requires confirmation.

Files live at `user://saves/<SHA-256 of name>.json`. Their contents are the unchanged
v2 gameplay document. `user://saves/slots.cfg` holds display names and the current
slot, outside gameplay saves. Autosave and exit-save target that same slot. An
unnamed game uses Autosave (or Autosave 2, etc. to preserve existing files).

Load lists names, UTC timestamps and colony levels. Unsaved snapshot differences
require confirmation before loading. Invalid saves do not replace the current game.
`user://orbital-save.json` remains listed as Legacy save; loading it uses existing
migration, and subsequent writes target its named slot, preserving the legacy file.

New game requires confirmation and restores a freshly constructed starting state
through the existing validated restore path. It retains the normal starting core,
Materials from `data/new_game.json` (currently 130), and no ships/research/outposts. Existing save files are untouched.
The game starts unnamed. Loaded and new games run; cancelling dialogs restores
the previous pause state. Space types normally inside dialogs rather than resuming.

Verification: `tests/named_saves_playthrough.gd` uses disposable files, exercises
UI clicks, pause, naming, autosave, restart metadata, load confirmation, new-game
isolation, legacy fallback, and v2 compatibility. No delete UI is included.
