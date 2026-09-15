# chicago/minesweeper — Minesweeper for the Chicago desktop

Minesweeper as the mid-nineties desktops had it, for the Chicago desktop of
[chicago/shell](https://github.com/chicago-desktop/shell): the three
levels, flags, chording, the smiley and the timer. It lies in the Start menu
under **Programs → Games**.

## Playing

| What | How |
|---|---|
| Open a cell | the left button |
| Flag a mine | the right button, at the press, as in Windows |
| Flag without a right button | **F** turns Flag mode on and off; the left button then flags |
| Open the rest around a number | a click on an opened number whose flags are all set (chording) |
| New game | **F2**, the face, or Game → New |
| Level | Game → Beginner (9×9, 10 mines), Intermediate (16×16, 40), Expert (30×16, 99) |

The first click is always safe: the mines are laid after it, never under the
clicked cell or next to it. The left counter is the mines minus the flags (it
goes below zero, as in Windows), the right one the seconds from the first
click, up to 999. The window fits itself to the level: it asks the compositor
for the client the field needs.

## Inside

| Entry | What |
|---|---|
| `chicago.minesweeper:game` | the rules — a pure library: the board, laying the mines, flood opening, chording, flags and flag mode, winning and losing, the counter and the timer. No clock and no randomness of its own: the window hands in a seed (a linear congruential generator, so a seed replays a board) and ticks it once a second |
| `chicago.minesweeper:view` | the window as data — a pure library: the component tree of a game (the menu, the counters, the face, every cell a button, the status bar, About) and what an action does to the model |
| `chicago.minesweeper:window` | the process — runs `view` on the shell's SDK (`chicago.shell.sdk:app`), hands it the first seed from the clock and fits the window to the level |
| `chicago.minesweeper:images` | the pictures — an image pack of the shell (`meta.type: chicago.images`): `mine` at 32 and 16 px, `face_smile`, `face_dead`, `face_cool` at 16 px. The window names them `chicago.minesweeper:images/<name>` |

The module asks nothing of the application: no database, no router, no
environment. It depends on `chicago/shell` (the SDK, the image packs)
and `chicago/tui-desktop` (the compositor it asks for the window's size).

## Requirements

**A build of the runtime fork from its releases is required**
([chicago-desktop/runtime](https://github.com/chicago-desktop/runtime),
`v0.3.40a-chicago.2` or newer), as for the shell itself: it resolves the
shell and the base from GitHub by tag, and the shell declares the `gfx`
module, which the release runtime does not have — `wippy` from PATH does
not load it at all. The Makefile uses
`../runtime/dist/wippy-linux-amd64` (the fork checked out beside this directory); override it with `WIPPY=`.

`chicago/shell` and `chicago/tui-desktop` are resolved from their GitHub
repositories by tag (`component: github.com/chicago-desktop/shell`,
`version: ">=0.2.0"` in `src/_index.yaml`; v0.2.0 is the first tag). No
working copy of either is needed beside the module: `cd test && wippy
update` writes them into `test/wippy.lock`, the first time by cloning them
into `~/.wippy/git`.

## Tests

```bash
make lint     # late locals, then wippy lint of this namespace
make test     # the harness in test/: the rules, the window, a shot
```

`test/` is a standalone harness: it replaces this module with `..`, takes
the shell and the base from GitHub by the tags in `test/wippy.lock`, and runs
`test/src/*_test.lua`: `game_test` (the rules), `view_test` (the window as
data, its layout at every level in cells and pixels) and `window_test` (the
registry entry, the pictures, the process). `view_test` writes
`test/shots/minesweeper.png`, a game in progress drawn by the shell's own
renderer — evidence for the eye.

## Licence

MIT. The pictures are this module's own pixel art.
