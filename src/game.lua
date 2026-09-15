-- Minesweeper's rules without a window: the board, the mines laid at the
-- first click and never under it or next to it, the flood that opens empty
-- ground, chording on a satisfied number, flags and the flag mode, the win
-- and the loss, the mine counter and the timer.
--
-- Pure: no module, no process, no clock. The window hands it a seed, and the
-- same seed lays the same mines, so a test replays a board exactly. All the
-- state of a game is one table (`g`), never locals shared with closures.
local game = {}

game.LEVELS = {
    {id = "beginner", name = "Beginner", cols = 9, rows = 9, mines = 10},
    {id = "intermediate", name = "Intermediate", cols = 16, rows = 16, mines = 40},
    {id = "expert", name = "Expert", cols = 30, rows = 16, mines = 99},
}
game.LEVEL_IDS = {beginner = 1, intermediate = 2, expert = 3}
game.MAX_SECONDS = 999

local MODULUS = 2147483648

local function whole(value: any): integer
    return math.tointeger(tonumber(value) or 0) or 0
end

-- A linear congruential generator on integers: the result does not depend on
-- whether math.random is seeded in this VM. The seed lives in the game.
local function random(g: any, n: integer): integer
    g.seed = (g.seed * 1103515245 + 12345) % MODULUS
    return whole((g.seed // 65536) % n + 1)
end

-- new(level, seed) -> a closed board of the level (1…3; the first when the
-- level is unknown).
function game.new(level: any, seed: any): any
    local index = whole(level)
    if not game.LEVELS[index] then index = 1 end
    local spec = game.LEVELS[index]
    local g: any = {level = index, cols = spec.cols, rows = spec.rows, mines = spec.mines, cells = {},
        state = "ready", opened = 0, flags = 0, seconds = 0, boom = nil, flagmode = false,
        seed = whole(seed) % MODULUS}
    for cell = 1, spec.cols * spec.rows do
        g.cells[cell] = {mine = false, open = false, flag = false, n = 0}
    end
    return g
end

-- again(g, level) -> a new board of `level` (or of the same level), the
-- generator carried on and the flag mode kept: F2 and the face start anew,
-- the Game menu changes the level.
function game.again(g: any, level: any?): any
    local fresh = game.new(level or g.level, g.seed)
    fresh.flagmode = g.flagmode
    return fresh
end

-- neighbors(g, index) -> the indices of the up to eight cells around.
function game.neighbors(g: any, index: integer): any
    local out: any = {}
    local row, col = (index - 1) // g.cols, (index - 1) % g.cols
    for dr = -1, 1 do
        for dc = -1, 1 do
            local r, c = row + dr, col + dc
            if (dr ~= 0 or dc ~= 0) and r >= 0 and r < g.rows and c >= 0 and c < g.cols then
                out[#out + 1] = r * g.cols + c + 1
            end
        end
    end
    return out
end

-- plant(g, mines) — mines on exactly these cells, the numbers counted, the
-- game running and its clock at one second, as Windows shows it after the
-- first click. The random laying ends here; a test plants a board of its own.
function game.plant(g: any, mines: any)
    local count = 0
    for _, cell in ipairs(g.cells) do cell.mine = false end
    for _, index in ipairs(mines) do
        local cell = g.cells[index]
        if cell and not cell.mine then
            cell.mine = true
            count = count + 1
        end
    end
    g.mines = count
    for index, cell in ipairs(g.cells) do
        local around = 0
        for _, near in ipairs(game.neighbors(g, index)) do
            if g.cells[near].mine then around = around + 1 end
        end
        cell.n = around
    end
    g.state = "playing"
    if g.seconds == 0 then g.seconds = 1 end
end

-- The first click: the level's mines anywhere but on the clicked cell and
-- the cells around it — a partial Fisher-Yates shuffle of the rest.
local function lay(g: any, safe: integer)
    local keep: any = {[safe] = true}
    for _, near in ipairs(game.neighbors(g, safe)) do keep[near] = true end
    local pool: any = {}
    for index = 1, #g.cells do
        if not keep[index] then pool[#pool + 1] = index end
    end
    local count = math.min(whole(g.mines), #pool)
    for k = 1, count do
        local pick = random(g, #pool - k + 1) + k - 1
        pool[k], pool[pick] = pool[pick], pool[k]
    end
    local mines: any = {}
    for k = 1, count do mines[k] = pool[k] end
    game.plant(g, mines)
end

-- Every safe cell open: won, and every mine shows its flag.
local function win(g: any)
    g.state = "won"
    for _, cell in ipairs(g.cells) do
        if cell.mine then cell.flag = true end
    end
    g.flags = g.mines
end

-- Open a cell: a mine loses the game; empty ground floods to the numbers
-- around it. Flagged cells are never opened.
local function open(g: any, index: integer)
    local cell = g.cells[index]
    if cell.open or cell.flag then return end
    if cell.mine then
        g.state, g.boom = "lost", index
        return
    end
    local stack: {integer} = {index}
    while #stack > 0 do
        local current = whole(table.remove(stack))
        local here = g.cells[current]
        if not here.open and not here.flag then
            here.open = true
            g.opened = g.opened + 1
            if here.n == 0 then
                for _, near in ipairs(game.neighbors(g, current)) do
                    if not g.cells[near].open then stack[#stack + 1] = near end
                end
            end
        end
    end
    if g.opened == #g.cells - g.mines then win(g) end
end

-- flag(g, index) -> changed? The right button: a flag on a closed cell, or
-- off it. Nothing after the game is over, nothing on an opened cell.
function game.flag(g: any, index: any): boolean
    if g.state == "won" or g.state == "lost" then return false end
    local cell = g.cells[index]
    if not cell or cell.open then return false end
    cell.flag = not cell.flag
    g.flags = g.flags + (cell.flag and 1 or -1)
    return true
end

-- click(g, index) -> changed? The left button. In the flag mode a closed cell
-- is flagged instead. The first click lays the mines. A closed cell opens; an
-- opened number whose flags are all set opens the rest of its neighbours
-- (chording) — a wrong flag there costs the game, as in Windows.
function game.click(g: any, index: any): boolean
    if g.state == "won" or g.state == "lost" then return false end
    local cell = g.cells[index]
    if not cell then return false end
    if g.flagmode and not cell.open then
        local flagged = game.flag(g, index)
        return flagged
    end
    if cell.flag then return false end
    local spot = whole(index)
    if g.state == "ready" then lay(g, spot) end
    if not cell.open then
        open(g, spot)
        return true
    end
    if cell.n == 0 then return false end
    local around, flags = game.neighbors(g, spot), 0
    for _, near in ipairs(around) do
        if g.cells[near].flag then flags = flags + 1 end
    end
    if flags ~= cell.n then return false end
    for _, near in ipairs(around) do
        if g.state == "playing" then open(g, whole(near)) end
    end
    return true
end

-- toggle_mode(g) — F: the flag mode on or off, for a mouse without a right
-- button.
function game.toggle_mode(g: any)
    g.flagmode = not g.flagmode
end

-- tick(g) -> changed? A second of a running game; the clock stops at 999 and
-- when the game ends.
function game.tick(g: any): boolean
    if g.state ~= "playing" or g.seconds >= game.MAX_SECONDS then return false end
    g.seconds = g.seconds + 1
    return true
end

-- left(g) -> the mines not flagged yet; below zero with too many flags.
function game.left(g: any): integer
    return whole(g.mines - g.flags)
end

-- counter(value) -> the three digits of an LED counter: "010", "-05";
-- 999 and -99 at most.
function game.counter(value: any): string
    local n = whole(value)
    if n < 0 then return "-" .. string.format("%02d", math.min(99, -n)) end
    return string.format("%03d", math.min(999, n))
end

-- face(g) -> "smile", "dead" or "cool" — the button between the counters.
function game.face(g: any): string
    if g.state == "lost" then return "dead" end
    if g.state == "won" then return "cool" end
    return "smile"
end

-- status(g) -> the status bar's text.
function game.status(g: any): string
    if g.state == "lost" then return "Boom! F2: new game" end
    if g.state == "won" then return "Cleared in " .. tostring(g.seconds) .. " s" end
    if g.flagmode then return "Flag mode: a click marks a mine (F)" end
    if g.state == "ready" then return "Right button: flag" end
    for index, level in ipairs(game.LEVELS) do
        if index == g.level then return level.name end
    end
    return ""
end

return game
