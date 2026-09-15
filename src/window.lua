-- Minesweeper's window process: the SDK's loop over the pure `view`, a seed
-- from the clock for every new board, and the size. The window fits itself to
-- the field: it asks the compositor for its outer size, subtracts the client
-- size it knows, and asks for the client the level needs.

local app = require("app")
local desktop = require("desktop")
local time = require("time")
local view = require("view")

local definition = {}
definition.interval = "1s"
definition.close_on_escape = true

-- seed() -> the seed of the first board: the clock. The game carries its
-- generator on from there, so F2 and a new level need no new seed.
function definition.seed(): any
    return math.tointeger(time.now():unix_nano() % 2147483647) or 20260911
end

-- fit(model, context) — ask the compositor for the client the level needs.
-- In cells, and before the compositor answers, the window keeps its size.
local function fit(model: any, context: any)
    if not context.native or not context.window_id or not desktop.ask then return end
    local listing = desktop.list()
    if type(listing) ~= "table" then return end
    for _, window in ipairs(listing.windows or {}) do
        if window.id == context.window_id then
            local outer_w = tonumber(window.width or window.w)
            local outer_h = tonumber(window.height or window.h)
            if not outer_w or not outer_h then return end
            local w, h = view.need(model, true)
            desktop.ask("desktop.resize", {id = context.window_id,
                w = w + outer_w - context.width, h = h + outer_h - context.height})
            return
        end
    end
end

function definition.init(args: any, context: any): any
    local model = view.init(args, definition.seed())
    context.after("100ms", "fit")
    return model
end

function definition.view(model: any, context: any): any
    local tree = view.tree(model, context)
    return tree
end

function definition.update(model: any, action: any, context: any): boolean
    if action.type == "timer" then
        if action.tag == "fit" then fit(model, context) end
        return false
    end
    local changed = view.update(model, action, context, fit)
    return changed
end

local function main(first: any, id: any, args: any, viewport: any)
    app.run(definition, first, id, args, viewport)
end

return {main = main, definition = definition}
