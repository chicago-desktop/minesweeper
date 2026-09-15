-- Minesweeper's window process: the registry entry the Start menu reads, the
-- module's pictures found by the shell, and the process running `view` — the
-- level from its argument, a seed per board, the fit timer.
local test = require("test")
local registry = require("registry")
local app = require("app")
local images = require("images")
local view = require("view")
local window = require("window")

local definition = window.definition

local function define_tests()
    test.describe("Minesweeper window", function()
        test.it("is a Programs/Games window on the shell SDK with the pack's mine; every picture of the pack is found", function()
            local entry = assert(registry.get("windows.minesweeper:window"))
            local meta: any = entry.meta
            test.eq(table.concat({meta.type, meta.title, meta.group, meta.image, meta.pixel_render, meta.pixel_state}, "|"),
                "tui_desktop.window|Minesweeper|Programs/Games|windows.minesweeper:images/mine|butschster.windows.sdk:render|windows.minesweeper:window")
            test.eq(view.PACK, "windows.minesweeper:images/")
            local big, why = images.get(view.PACK .. "mine", 32)
            test.not_nil(big, "mine@32: " .. tostring(why))
            for _, name in ipairs({"mine", "face_smile", "face_dead", "face_cool"}) do
                local small, reason = images.get(view.PACK .. name, 16)
                test.not_nil(small, name .. "@16: " .. tostring(reason))
            end
        end)

        test.it("runs the view: the level from its argument, a seed per window, the fit timer, the view's answers", function()
            local seeds: any = {count = 0}
            local original = definition.seed
            definition.seed = function(): any
                seeds.count = seeds.count + 1
                return 7
            end
            local context = app.context({width = 32, height = 15})
            local model = definition.init("intermediate", context)
            definition.seed = original
            test.eq(model.game.level .. "|" .. seeds.count, "2|1", "the argument's level, one seed")
            test.eq(#context.timers .. "|" .. tostring(context.timers[1] and context.timers[1].tag), "1|fit",
                "the window asks to fit itself once it is up")
            test.is_false(definition.update(model, {type = "timer", tag = "fit"}, context),
                "in cells there is nothing to fit, and nothing to redraw")
            test.eq(definition.view(model, context).children[1].id, "bar", "the view's tree")
            test.is_true(definition.update(model, {type = "activate", id = "c120"}, context))
            test.eq(model.game.state, "playing")
            definition.update(model, {type = "activate", id = "expert", menu = "bar"}, context)
            test.eq(model.game.level, 3)
            test.is_true(math.tointeger(original()) ~= nil, "the clock gives an integer seed")
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return {run = function(options) return run_cases(options) end}
