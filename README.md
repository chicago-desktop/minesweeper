# butschster/windows-minesweeper — Minesweeper for the Windows 95 shell

Minesweeper as Windows 95 had it, for the terminal desktop of
[butschster/windows](https://github.com/wippy-windows/windows): the three
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
| `butschster.windows.minesweeper:game` | the rules — a pure library: the board, laying the mines, flood opening, chording, flags and flag mode, winning and losing, the counter and the timer. No clock and no randomness of its own: the window hands in a seed (a linear congruential generator, so a seed replays a board) and ticks it once a second |
| `butschster.windows.minesweeper:view` | the window as data — a pure library: the component tree of a game (the menu, the counters, the face, every cell a button, the status bar, About) and what an action does to the model |
| `butschster.windows.minesweeper:window` | the process — runs `view` on the shell's SDK (`butschster.windows.sdk:app`), hands it the first seed from the clock and fits the window to the level |
| `butschster.windows.minesweeper:images` | the pictures — an image pack of the shell (`meta.type: windows.images`): `mine` at 32 and 16 px, `face_smile`, `face_dead`, `face_cool` at 16 px. The window names them `butschster.windows.minesweeper:images/<name>` |

The module asks nothing of the application: no database, no router, no
environment. It depends on `butschster/windows` (the SDK, the image packs)
and `butschster/tui-desktop` (the compositor it asks for the window's size).

## Requirements

**A local runtime build is required**, as for the shell itself: the shell
declares the `gfx` module, which the release runtime does not have, and
`wippy` from PATH does not load it at all. The Makefile uses
`~/repos/wippy/runtime/dist/wippy-linux-amd64`; override it with `WIPPY=`.

Until the shell and its base are in the Hub, `.wippy.yaml` takes them from
the neighbouring working copies `../windows-module` and `../kickside-module`.

## Tests

```bash
make lint     # late locals, then wippy lint of this namespace
make test     # the harness in test/: the rules, the window, a shot
```

`test/` is a standalone harness: it replaces this module with `..` and the
shell and the base with their working copies, and runs
`test/src/*_test.lua`: `game_test` (the rules), `view_test` (the window as
data, its layout at every level in cells and pixels) and `window_test` (the
registry entry, the pictures, the process). `view_test` writes
`test/shots/minesweeper.png`, a game in progress drawn by the shell's own
renderer — evidence for the eye.

## Licence

MIT. The pictures are this module's own pixel art.
