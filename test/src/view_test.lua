-- Minesweeper's window as data: the field of buttons, the counters and the
-- face, the right button and Flag mode, how a lost and a won field look, the
-- menu and About, the clock, the layout of every level in cells and pixels,
-- and a shot of a game in progress (test/shots/minesweeper.png) drawn by the
-- shell's own renderer.
local test = require("test")
local gfx = require("gfx")
local fs = require("fs")
local ui = require("ui")
local app = require("app")
local render = require("render")
local rasters = require("rasters")
local game = require("game")
local view = require("view")

local PACK = view.PACK
local CELL = {w = 10, h = 20}

-- A model of the level (Beginner by default) on seed 7, and a context of the
-- size the level needs.
local function open(pixels: boolean?, level: any?): (any, any)
    local spec = level and game.LEVELS[math.tointeger(level) or 1] or nil
    local model = view.init(spec and spec.id or "", 7)
    local w, h = view.need(model, pixels == true)
    local context = app.context({width = w, height = h, native = pixels == true, cell_w = CELL.w, cell_h = CELL.h})
    return model, context
end

local function nodes(tree: any, out: any?): any
    local found: any = out or {}
    if type(tree) ~= "table" then return found end
    if tree.id then found[tree.id] = tree end
    for _, item in ipairs(tree.children or {}) do nodes(item, found) end
    return found
end

local function status(model: any, context: any): string
    local tree = view.tree(model, context)
    return tostring(tree.children[#tree.children].fields[1].text)
end

-- The first closed cell with (or without) a mine.
local function find(g: any, mine: boolean): integer
    for index, cell in ipairs(g.cells) do
        if cell.mine == mine and not cell.open and not cell.flag then return index end
    end
    return 0
end

local function face_font(): any
    local files = assert(fs.get("app:system_fonts"))
    return assert(gfx.font(assert(files:readfile("LiberationSans-Regular.ttf")), {size = 13, smooth = true}))
end

local LEAVES: any = {button = true, field = true, statusbar = true}

-- The first pair of laid out controls that overlap or leave the client.
local function clash(plan: any, width: integer, height: integer): string
    local items: any = {}
    for _, item in ipairs(plan.items) do
        if LEAVES[item.node.kind] and item.rect.w > 0 and item.rect.h > 0 then items[#items + 1] = item end
    end
    for index, a in ipairs(items) do
        local r = a.rect
        if r.x < 1 or r.y < 1 or r.x + r.w > width + 1 or r.y + r.h > height + 1 then
            return tostring(a.node.id or a.node.kind) .. " leaves the client"
        end
        for other = index + 1, #items do
            local s = items[other].rect
            if r.x < s.x + s.w and s.x < r.x + r.w and r.y < s.y + s.h and s.y < r.y + r.h then
                return tostring(a.node.id or a.node.kind) .. " overlaps " .. tostring(items[other].node.id or items[other].node.kind)
            end
        end
    end
    return "none"
end

local function define_tests()
    test.describe("Minesweeper view", function()
        test.it("starts the level its argument names, Beginner otherwise", function()
            test.eq(view.init("intermediate", 1).game.level, 2)
            test.eq(view.init("  expert ", 1).game.level, 3, "the argument is trimmed")
            test.eq(view.init("nightmare", 1).game.level, 1)
            test.eq(view.init(nil, 1).game.level, 1)
            test.is_false(view.init("", 1).about)
        end)

        test.it("shows a button per cell, raised while closed and pressed when opened with its number in colour; the counters and the face", function()
            local model, context = open(false)
            local found = nodes(view.tree(model, context))
            test.not_nil(found.c1)
            test.not_nil(found.c81)
            test.is_nil(found.c82, "Beginner is 81 cells")
            test.is_nil(found.c41.pressed, "closed: raised")
            test.eq(found.face.text .. "|" .. found.face.image, ":)|" .. PACK .. "face_smile")
            test.is_true(view.update(model, {type = "activate", id = "c41"}, context))
            local g = model.game
            test.eq(g.state, "playing")
            found = nodes(view.tree(model, context))
            test.is_true(found.c41.pressed, "opened: pressed")
            local numbered: any = nil
            for index, cell in ipairs(g.cells) do
                if cell.open and cell.n > 0 and not numbered then numbered = index end
            end
            test.not_nil(numbered, "the space ends in numbers")
            local number = found["c" .. tostring(numbered)]
            local n = math.tointeger(g.cells[numbered].n) or 0
            test.eq(number.text .. "|" .. number.ink, tostring(n) .. "|" .. view.INK[n])
            test.eq(view.INK[1] .. view.INK[2] .. view.INK[3], "#0000ff#008000#ff0000", "1 blue, 2 green, 3 red, as Windows 95")
            local counters = view.tree(model, context).children[2].children
            test.eq(counters[2].text .. "|" .. counters[6].text, "010|001", "mines left and the seconds")
            test.eq(status(model, context), "Beginner")
            test.is_false(view.update(model, {type = "activate", id = "cx"}, context), "not a cell: nothing")
        end)

        test.it("the right button flags at the press, F is Flag mode, F2 and the face start again with Flag mode kept", function()
            local model, context = open(false)
            test.eq(status(model, context), "Right button: flag")
            test.is_true(view.update(model, {type = "context", id = "c5"}, context))
            local found = nodes(view.tree(model, context))
            test.eq(found.c5.text .. "|" .. found.c5.ink, "►|#ff0000")
            test.eq(view.tree(model, context).children[2].children[2].text, "009")
            test.is_false(view.update(model, {type = "context", id = "face"}, context), "a right press elsewhere does nothing")
            test.is_true(view.update(model, {type = "key", key_type = "runes", key = "f"}, context))
            test.eq(status(model, context), "Flag mode: a click marks a mine (F)")
            view.update(model, {type = "activate", id = "c6"}, context)
            test.is_true(model.game.cells[6].flag, "in Flag mode the left button flags")
            view.update(model, {type = "key", key_type = "f2"}, context)
            test.eq(model.game.state .. "|" .. model.game.flags, "ready|0", "F2: a new board")
            test.is_true(model.game.flagmode, "Flag mode kept")
            view.update(model, {type = "key", key_type = "runes", key = "F"}, context)
            test.is_false(model.game.flagmode)
            view.update(model, {type = "activate", id = "c41"}, context)
            test.eq(model.game.state, "playing")
            view.update(model, {type = "activate", id = "face"}, context)
            test.eq(model.game.state, "ready", "the face starts again too")
            test.is_false(view.update(model, {type = "key", key_type = "runes", key = "x"}, context))
        end)

        test.it("a lost field shows every mine, the one that went off in red, and a wrong flag crossed; won: the cool face and the time", function()
            local model, context = open(false)
            view.update(model, {type = "activate", id = "c41"}, context)
            local g = model.game
            local wrong = find(g, false)
            view.update(model, {type = "context", id = "c" .. tostring(wrong)}, context)
            local mine = find(g, true)
            view.update(model, {type = "activate", id = "c" .. tostring(mine)}, context)
            local found = nodes(view.tree(model, context))
            test.eq(found.face.text .. "|" .. found.face.image, "X(|" .. PACK .. "face_dead")
            local boom = found["c" .. tostring(mine)]
            test.eq(boom.text .. "|" .. boom.ink .. "|" .. tostring(boom.pressed), "●|#ff0000|true", "the one that went off")
            local other = 0
            for index, cell in ipairs(g.cells) do
                if cell.mine and index ~= mine then other = index end
            end
            test.eq(found["c" .. tostring(other)].text .. "|" .. found["c" .. tostring(other)].ink, "●|#000000", "the others in black")
            test.eq(found["c" .. tostring(wrong)].text .. "|" .. found["c" .. tostring(wrong)].ink, "X|#ff0000", "a flag where no mine was")
            test.eq(status(model, context), "Boom! F2: new game")
            local won, wctx = open(false)
            view.update(won, {type = "activate", id = "c41"}, wctx)
            for _ = 1, 3 do view.update(won, {type = "tick"}, wctx) end
            local free = find(won.game, false)
            while free > 0 and won.game.state == "playing" do
                game.click(won.game, free)
                free = find(won.game, false)
            end
            test.eq(won.game.state, "won")
            found = nodes(view.tree(won, wctx))
            test.eq(found.face.image, PACK .. "face_cool")
            test.eq(status(won, wctx), "Cleared in 4 s")
        end)

        test.it("the menu: New keeps the level, the levels ask the window to fit, About, Exit", function()
            local model, context = open(false)
            local fits: any = {count = 0}
            local function fit(asked: any, _: any)
                fits.count = fits.count + 1
                fits.cols = asked.game.cols
            end
            view.update(model, {type = "activate", id = "intermediate", menu = "bar"}, context, fit)
            test.eq(model.game.cols .. "x" .. model.game.rows .. "/" .. model.game.mines, "16x16/40")
            test.eq(fits.count .. "|" .. tostring(fits.cols), "1|16", "the window is asked to fit the new level")
            test.not_nil(nodes(view.tree(model, context)).c256)
            view.update(model, {type = "activate", id = "expert", menu = "bar"}, context, fit)
            test.eq(model.game.level, 3)
            view.update(model, {type = "activate", id = "c200"}, context, fit)
            view.update(model, {type = "activate", id = "new", menu = "bar"}, context, fit)
            test.eq(model.game.state .. "|" .. model.game.level .. "|" .. fits.count, "ready|3|2", "New keeps the level and the size")
            view.update(model, {type = "activate", id = "about", menu = "bar"}, context)
            local sheet = view.tree(model, context)
            test.is_nil(ui.problem(sheet))
            test.eq(sheet.children[1].children[2].text, "Minesweeper")
            test.is_false(view.update(model, {type = "activate", id = "c1"}, context), "the field is not there under About")
            test.is_true(view.update(model, {type = "key", key_type = "esc"}, context))
            test.is_false(model.about, "Esc closes About")
            view.update(model, {type = "activate", id = "about", menu = "bar"}, context)
            view.update(model, {type = "activate", id = "about_ok"}, context)
            test.is_false(model.about, "so does OK")
            test.is_false(context.closing)
            view.update(model, {type = "activate", id = "exit", menu = "bar"}, context)
            test.is_true(context.closing, "Exit closes the window")
        end)

        test.it("the clock counts only while playing, and under About without redrawing", function()
            local model, context = open(false)
            test.is_false(view.update(model, {type = "tick"}, context), "before the first click")
            view.update(model, {type = "activate", id = "c41"}, context)
            test.is_true(view.update(model, {type = "tick"}, context))
            test.eq(model.game.seconds, 2)
            view.update(model, {type = "activate", id = "about", menu = "bar"}, context)
            test.is_false(view.update(model, {type = "tick"}, context), "under About nothing to redraw")
            test.eq(model.game.seconds, 3, "but the clock runs")
        end)

        test.it("lays out every level at its own size without overlaps, in cells and in pixels", function()
            for level = 1, #game.LEVELS do
                for _, pixels in ipairs({false, true}) do
                    local model, context = open(pixels, level)
                    local w, h = view.need(model, pixels)
                    local tree = view.tree(model, context)
                    test.is_nil(ui.problem(tree))
                    local plan = ui.plan(tree, w, h, context.interaction, pixels and {cell = CELL} or nil)
                    local where = game.LEVELS[level].name .. (pixels and " in pixels" or " in cells")
                    test.eq(clash(plan, w, h), "none", where)
                    local first = plan.by_id.c1.rect
                    local last = plan.by_id["c" .. tostring(#model.game.cells)].rect
                    test.eq(first.w .. "x" .. first.h, (pixels and "2" or "3") .. "x1", where .. ": a cell's size")
                    test.eq(last.x - first.x, (model.game.cols - 1) * first.w, where .. ": the row stands together")
                    test.eq(last.y - first.y, model.game.rows - 1, where .. ": a row per line")
                    test.eq(plan.by_id.face.rect.w, 4, where .. ": the face whole")
                end
            end
        end)

        test.it("draws a game in progress into test/shots/minesweeper.png", function()
            local model, context = open(true)
            view.update(model, {type = "activate", id = "c41"}, context)
            local mine = find(model.game, true)
            view.update(model, {type = "context", id = "c" .. tostring(mine)}, context)
            view.update(model, {type = "tick"}, context)
            local tree = view.tree(model, context)
            test.is_nil(ui.problem(tree))
            local store = rasters.store()
            store.begin()
            local placed = assert(render.placement({id = "minesweeper", state_revision = 1, content_state = {sdk = 1, revision = 1,
                ui = tree, interaction = context.interaction}}, {x = 1, y = 1, cols = context.width, rows = context.height},
                CELL, {face = face_font()}, store))
            assert(assert(fs.get("app:shots")):writefile("minesweeper.png", assert(placed.raster:encode("png"))))
            test.eq(placed.cols .. "x" .. placed.rows, tostring(context.width) .. "x" .. tostring(context.height))
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return {run = function(options) return run_cases(options) end}
