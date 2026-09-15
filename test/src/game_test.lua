-- Minesweeper's rules on fixed seeds and on boards drawn in the test: the
-- first click's safe zone and a seed replaying a board, a new board keeping
-- the generator and Flag mode, flood opening, loss and win, chording, flags
-- and Flag mode, the timer, the levels, the counter, the face and the status.
local test = require("test")
local game = require("game")

-- A board from a picture — "*" a mine, "." a free cell, rows of one length —
-- planted, so the game is past its first click and the picture is the board.
local function board(picture: any): any
    local g: any = game.new(1, 1)
    g.rows, g.cols, g.cells = #picture, #picture[1], {}
    local mines: any = {}
    for r, line in ipairs(picture) do
        for c = 1, #line do
            local index = (r - 1) * g.cols + c
            g.cells[index] = {mine = false, open = false, flag = false, n = 0}
            if line:sub(c, c) == "*" then mines[#mines + 1] = index end
        end
    end
    game.plant(g, mines)
    return g
end

local function at(g: any, row: any, col: any): integer
    return math.tointeger((row - 1) * g.cols + col) or 0
end

-- The board's state, a row per "|": "#" closed, "F" a flag, "." an empty
-- opened cell, a digit, "!" the mine that went off, and after a loss "*" a
-- mine nobody flagged. How a cell LOOKS is the view's business and its test's.
local function shown(g: any): string
    local rows: any = {}
    for r = 1, g.rows do
        local line = ""
        for c = 1, g.cols do
            local index = at(g, r, c)
            local cell = g.cells[index]
            local sign: string
            if cell.open then sign = cell.n > 0 and tostring(cell.n) or "."
            elseif g.boom == index then sign = "!"
            elseif cell.flag then sign = "F"
            elseif g.state == "lost" and cell.mine then sign = "*"
            else sign = "#" end
            line = line .. sign
        end
        rows[#rows + 1] = line
    end
    return table.concat(rows, "|")
end

local function mines_of(g: any): any
    local out: any = {}
    for index, cell in ipairs(g.cells) do
        if cell.mine then out[#out + 1] = index end
    end
    return out
end

local WALL = {"..*..", "..*..", "..*.."}

local function define_tests()
    test.describe("Minesweeper rules", function()
        test.it("lays the mines on the first click, never under it or next to it; a seed replays its board", function()
            for level, spec in ipairs(game.LEVELS) do
                for _, seed in ipairs({1, 7, 20260915, 2147483647}) do
                    local g = game.new(level, seed)
                    test.eq(g.state .. "|" .. #mines_of(g), "ready|0", "no mine before the first click")
                    local safe = at(g, math.max(1, g.rows // 2), math.max(1, g.cols // 2))
                    test.is_true(game.click(g, safe))
                    test.eq(#mines_of(g), spec.mines, spec.name .. ": all its mines")
                    test.is_false(g.cells[safe].mine, "not under the click")
                    for _, near in ipairs(game.neighbors(g, safe)) do
                        test.is_false(g.cells[near].mine, "not next to it")
                    end
                    test.eq(g.cells[safe].n, 0, "so the first click opens a space")
                    test.eq(g.state .. "|" .. g.seconds, "playing|1")
                end
            end
            local corner = game.new(1, 7)
            game.click(corner, 1)
            test.eq(#mines_of(corner), 10, "a corner's safe zone is smaller, the mines are all there")
            local again = game.new(1, 7)
            game.click(again, 1)
            test.eq(table.concat(mines_of(again), ","), table.concat(mines_of(corner), ","), "one seed, one board")
            local other = game.new(1, 8)
            game.click(other, 1)
            test.is_false(table.concat(mines_of(other), ",") == table.concat(mines_of(corner), ","), "another seed, another board")
        end)

        test.it("a new board keeps the level unless told, carries the generator on and keeps Flag mode", function()
            local g = game.new(1, 7)
            game.click(g, 41)
            game.toggle_mode(g)
            local fresh = game.again(g)
            test.eq(fresh.level .. "|" .. fresh.state .. "|" .. fresh.seconds .. "|" .. fresh.flags, "1|ready|0|0")
            test.is_true(fresh.flagmode, "Flag mode stays on")
            game.toggle_mode(fresh)
            game.click(fresh, 41)
            test.is_false(table.concat(mines_of(fresh), ",") == table.concat(mines_of(g), ","),
                "the generator went on: not the same board again")
            local expert = game.again(g, 3)
            test.eq(expert.level .. "|" .. expert.cols .. "x" .. expert.rows, "3|30x16")
        end)

        test.it("a zero opens its neighbourhood up to the numbers; the last free cell wins and flags every mine", function()
            local g = board(WALL)
            test.eq(g.state .. "|" .. g.seconds .. "|" .. g.mines, "playing|1|3", "a planted board is under way")
            test.is_true(game.click(g, at(g, 2, 1)))
            test.eq(shown(g), ".2###|.3###|.2###", "the left side opens, up to the wall's numbers")
            test.eq(g.opened .. "|" .. g.state, "6|playing")
            test.is_true(game.click(g, at(g, 2, 5)))
            test.eq(g.state, "won")
            test.eq(shown(g), ".2F2.|.3F3.|.2F2.", "every mine gets its flag")
            test.eq(game.counter(game.left(g)), "000")
            test.is_false(game.click(g, at(g, 1, 3)), "an ended game takes no click")
            test.is_false(game.flag(g, at(g, 1, 1)), "nor a flag")
        end)

        test.it("a mine loses and remembers which went off; nothing moves after", function()
            local g = board(WALL)
            game.flag(g, at(g, 1, 3))
            game.flag(g, at(g, 1, 4))
            test.is_true(game.click(g, at(g, 2, 3)))
            test.eq(g.state .. "|" .. tostring(g.boom), "lost|" .. tostring(at(g, 2, 3)))
            test.eq(shown(g), "##FF#|##!##|##*##")
            test.is_false(game.click(g, at(g, 1, 1)))
            test.is_false(game.tick(g), "the clock stands")
            test.eq(shown(g), "##FF#|##!##|##*##")
        end)

        test.it("chording: a number with all its flags set opens its other neighbours; too few does nothing; a wrong flag loses", function()
            local g = board({"*...", "....", "...."})
            test.is_true(game.click(g, at(g, 1, 2)))
            test.eq(shown(g), "#1##|####|####")
            test.is_false(game.click(g, at(g, 1, 2)), "no flag around the 1: nothing opens")
            test.eq(g.opened, 1)
            game.flag(g, at(g, 1, 1))
            test.is_true(game.click(g, at(g, 1, 2)))
            test.eq(g.state, "won", "the rest opened, and the space behind it")
            test.eq(shown(g), "F1..|11..|....")
            local wrong = board({"*...", "....", "...."})
            game.click(wrong, at(wrong, 1, 2))
            game.flag(wrong, at(wrong, 2, 2))
            test.is_true(game.click(wrong, at(wrong, 1, 2)))
            test.eq(wrong.state, "lost", "the flag was wrong, the mine went off")
            test.eq(shown(wrong), "!1##|#F##|####")
            local empty = board({"*...", "....", "...."})
            game.click(empty, at(empty, 3, 4))
            test.is_false(game.click(empty, at(empty, 3, 4)), "an opened empty cell does nothing")
        end)

        test.it("flags: on closed cells only, the counter goes down and below zero; Flag mode makes the left button flag", function()
            local g = game.new(1, 7)
            test.is_true(game.flag(g, 1))
            test.eq(g.flags .. "|" .. game.counter(game.left(g)), "1|009")
            test.eq(g.state .. "|" .. g.seconds, "ready|0", "a flag does not start the game")
            test.is_true(game.flag(g, 1))
            test.eq(g.flags, 0, "a second flag takes it off")
            for index = 1, 12 do game.flag(g, index) end
            test.eq(game.counter(game.left(g)), "-02", "more flags than mines: below zero")
            test.is_false(game.click(g, 1), "a flagged cell does not open")
            test.is_false(g.cells[1].open)
            local mode = game.new(1, 7)
            game.toggle_mode(mode)
            test.is_true(game.click(mode, 5))
            test.is_true(mode.cells[5].flag, "in Flag mode the left button flags")
            test.eq(mode.state, "ready", "and does not start the game")
            game.toggle_mode(mode)
            test.is_false(game.click(mode, 5), "out of it, the flagged cell stays shut")
            test.is_true(game.click(mode, 41))
            test.eq(mode.state, "playing")
            test.is_false(game.flag(mode, 41), "an opened cell takes no flag")
        end)

        test.it("the clock: 1 at the first click, a second a tick while playing, up to 999, standing before and after", function()
            local g = game.new(1, 7)
            test.is_false(game.tick(g), "before the first click the clock stands")
            test.eq(g.seconds, 0)
            game.click(g, 41)
            test.eq(g.seconds, 1)
            test.is_true(game.tick(g))
            test.eq(g.seconds, 2)
            g.seconds = 998
            test.is_true(game.tick(g))
            test.is_false(game.tick(g), "999 is the most")
            test.eq(g.seconds, 999)
        end)

        test.it("the levels, the counter, the face and the status bar", function()
            test.eq(tostring(game.LEVEL_IDS.beginner) .. tostring(game.LEVEL_IDS.intermediate) .. tostring(game.LEVEL_IDS.expert), "123")
            local expert = game.new(3, 1)
            test.eq(expert.cols .. "x" .. expert.rows .. "/" .. expert.mines .. "/" .. #expert.cells, "30x16/99/480")
            test.eq(game.new(9, 1).level, 1, "a level that is not one is Beginner")
            test.eq(game.new(nil, 1).cols, 9)
            test.eq(table.concat({game.counter(0), game.counter(10), game.counter(1234), game.counter(-1),
                game.counter(-150), game.counter(nil)}, " "), "000 010 999 -01 -99 000")
            test.eq(#game.neighbors(expert, 1) .. "/" .. #game.neighbors(expert, 32) .. "/" .. #game.neighbors(expert, 480), "3/8/3",
                "a corner has three neighbours, the inside eight")
            local g = board(WALL)
            test.eq(game.face(g) .. "|" .. game.status(g), "smile|Beginner", "under way: the level's name")
            game.toggle_mode(g)
            test.eq(game.status(g), "Flag mode: a click marks a mine (F)")
            game.toggle_mode(g)
            game.click(g, at(g, 2, 3))
            test.eq(game.face(g) .. "|" .. game.status(g), "dead|Boom! F2: new game")
            local won = board(WALL)
            game.click(won, at(won, 2, 1))
            game.tick(won)
            game.click(won, at(won, 2, 5))
            test.eq(game.face(won) .. "|" .. game.status(won), "cool|Cleared in 2 s")
            test.eq(game.status(game.new(1, 1)), "Right button: flag")
        end)
    end)
end

local run_cases = test.run_cases(define_tests)
return {run = function(options) return run_cases(options) end}
