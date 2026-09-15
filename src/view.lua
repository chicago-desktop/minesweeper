-- Minesweeper's window as data: the component tree of the current game and
-- what an action does to it. Pure over the model; the window process
-- (window.lua) runs it, hands it a seed and fits its size.
--
-- Every cell of the field is an SDK button: a closed cell is raised, an
-- opened one pressed. The right button on a closed cell is the SDK's
-- `context` action, at the press, as in Windows.
local ui = require("ui")
local game = require("game")

local view = {}

-- The module's own image pack (`<pack entry>/<file>`).
view.PACK = "butschster.windows.minesweeper:images/"
view.INK = {"#0000ff", "#008000", "#ff0000", "#000080", "#800000", "#008080", "#000000", "#808080"}
view.RED, view.BLACK = "#ff0000", "#000000"
view.MINE, view.FLAG, view.WRONG = "●", "►", "X"
-- The face in cells, where there is no picture.
view.FACES = {smile = ":)", dead = "X(", cool = "B)"}

view.MENU = {
    {title = "Game", accel = 1, items = {
        {id = "new", text = "New"},
        {separator = true},
        {id = "beginner", text = "Beginner"},
        {id = "intermediate", text = "Intermediate"},
        {id = "expert", text = "Expert"},
        {separator = true},
        {id = "exit", text = "Exit"},
    }},
    {title = "Help", accel = 1, items = {{id = "about", text = "About Minesweeper"}}},
}

local function trim(value: any): string
    return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

-- init(args, seed) -> the model: a game of the level the argument names
-- ("beginner", "intermediate", "expert"; Beginner otherwise).
function view.init(args: any, seed: any): any
    return {game = game.new(game.LEVEL_IDS[trim(args)] or 1, seed), about = false}
end

-- need(model, pixels) -> the client size in cells the level's field needs: a
-- cell is two columns in pixels and three in cells, and the head row with the
-- face is two rows high in pixels.
function view.need(model: any, pixels: any): (integer, integer)
    local g = model.game
    local cell_w, head = pixels and 2 or 3, pixels and 2 or 1
    local cols = math.tointeger(math.max(g.cols * cell_w, 18) + 2) or 0
    local rows = math.tointeger(g.rows + head + 4) or 0
    return cols, rows
end

local function spacer(size: integer): any
    return {kind = "label", size = size, text = ""}
end

local function flex(): any
    return {kind = "label", text = ""}
end

-- cell(g, index, width) -> the cell's button. Over a lost game every mine
-- shows (the one that went off in red), and a flag on ground is crossed out.
function view.cell(g: any, index: integer, width: integer): any
    local cell = g.cells[index]
    local node: any = {kind = "button", id = "c" .. tostring(index), size = width, fill = true, inset = 0,
        bold = true, text = ""}
    local over = g.state == "lost"
    if cell.open then
        node.pressed = true
        if cell.n > 0 then node.text, node.ink = tostring(cell.n), view.INK[cell.n] end
    elseif over and cell.mine and not cell.flag then
        node.pressed, node.text, node.ink = true, view.MINE, index == g.boom and view.RED or view.BLACK
    elseif over and cell.flag and not cell.mine then
        node.pressed, node.text, node.ink = true, view.WRONG, view.RED
    elseif cell.flag then
        node.text, node.ink = view.FLAG, view.RED
    end
    return node
end

-- tree(model, context) -> the window's tree: the About sheet while it is up;
-- otherwise the menu, the mine counter, the face and the clock, the field and
-- the status bar.
function view.tree(model: any, context: any): any
    local g = model.game
    if model.about then
        return ui.message({title = "Minesweeper", image = view.PACK .. "mine", icon = view.MINE, ok = "about_ok",
            lines = {"Clear the field of mines.", "The right button flags a mine; F turns on the flag mode.",
                "A number with all its flags set opens the rest around it."}})
    end
    local pixels = type(context) == "table" and context.native == true
    local width, head = pixels and 2 or 3, pixels and 2 or 1
    local face = game.face(g)
    local rows: any = {
        {kind = "menu", id = "bar", size = 1, entries = view.MENU},
        {kind = "row", size = head, children = {
            spacer(1), {kind = "field", size = 5, text = game.counter(game.left(g)), align = "right"},
            flex(), {kind = "button", id = "face", size = 4, text = view.FACES[face], image = view.PACK .. "face_" .. face,
                bold = true}, flex(),
            {kind = "field", size = 5, text = game.counter(g.seconds), align = "right"}, spacer(1),
        }},
        spacer(1),
    }
    for r = 1, g.rows do
        local line: any = {flex()}
        for c = 1, g.cols do line[#line + 1] = view.cell(g, math.tointeger((r - 1) * g.cols + c) or 0, width) end
        line[#line + 1] = flex()
        rows[#rows + 1] = {kind = "row", size = 1, children = line}
    end
    rows[#rows + 1] = spacer(1)
    rows[#rows + 1] = flex()
    rows[#rows + 1] = {kind = "statusbar", size = 1, fields = {{text = game.status(g)}}}
    return {kind = "column", children = rows}
end

-- The cell a control's id names, nil for any other control. `tonumber(nil)`
-- raises, and the face and the menu are not cells: without the check a right
-- press on the face would turn the window into its error screen.
local function index_of(id: any): any
    local digits = string.match(tostring(id or ""), "^c(%d+)$")
    if not digits then return nil end
    return math.tointeger(tonumber(digits))
end

-- update(model, action, context, fit) -> redraw? `fit(model, context)` asks the
-- compositor for the size a new level needs; the window passes it in.
function view.update(model: any, action: any, context: any, fit: any?): boolean
    if type(action) ~= "table" then return false end
    local g = model.game
    if action.type == "tick" then
        -- The clock runs under the About sheet too; only the redraw waits.
        return game.tick(g) and not model.about
    end
    if action.type == "activate" and action.id == "about_ok" then
        model.about = false
        return true
    end
    if model.about then
        if action.type == "key" and action.key_type == "esc" then
            model.about = false
            return true
        end
        return false
    end
    if action.type == "activate" then
        local id = tostring(action.id or "")
        if id == "face" or id == "new" then
            model.game = game.again(g)
        elseif game.LEVEL_IDS[id] then
            model.game = game.again(g, game.LEVEL_IDS[id])
            if fit then fit(model, context) end
        elseif id == "about" then
            model.about = true
        elseif id == "exit" then
            context.close()
        else
            local index = index_of(id)
            if not index then return false end
            local changed = game.click(g, index)
            return changed
        end
        return true
    end
    if action.type == "context" then
        local index = index_of(action.id)
        if not index then return false end
        local changed = game.flag(g, index)
        return changed
    end
    if action.type == "key" then
        if action.key_type == "f2" then
            model.game = game.again(g)
            return true
        end
        if action.key_type == "runes" and (action.key == "f" or action.key == "F") then
            game.toggle_mode(g)
            return true
        end
    end
    return false
end

return view
