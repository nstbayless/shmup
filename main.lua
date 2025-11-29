if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

MUTE = false
math.randomseed(os.time())

require "src/config"
require "src/util"
local players = require "src/players"

local frame_accumulate = 0.5
local canvas
local canvas_width, canvas_height

function love.load(args)
    love.window.setTitle("Shmup")

    -- Set up pixel-perfect scaling
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Calculate canvas size based on pixel scale
    canvas_width = math.floor(WINDOW_W / PIXEL_SCALE)
    canvas_height = math.floor(WINDOW_H / PIXEL_SCALE)
    canvas = love.graphics.newCanvas(canvas_width, canvas_height)

    -- Initialize players
    players.load()
    players.ensure_players(1)
end

function love.draw()
    -- Draw to canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear()

    -- Calculate margin offsets (scaled)
    local margin_l = MARGIN_L / PIXEL_SCALE
    local margin_t = MARGIN_T / PIXEL_SCALE
    local margin_r = MARGIN_R / PIXEL_SCALE
    local margin_b = MARGIN_B / PIXEL_SCALE
    local game_w = GAME_WIDTH / PIXEL_SCALE
    local game_h = GAME_HEIGHT / PIXEL_SCALE

    -- Draw dark green background everywhere
    love.graphics.setColor(0, 0.2, 0)
    love.graphics.rectangle("fill", 0, 0, canvas_width, canvas_height)

    -- Set scissor rectangle for game area and draw black background
    love.graphics.setScissor(margin_l, margin_t, game_w, game_h)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", margin_l, margin_t, game_w, game_h)
    love.graphics.setColor(1, 1, 1)

    -- Apply translation for game area offset
    love.graphics.push()
    love.graphics.translate(margin_l, margin_t)

    -- Draw all players
    players.draw()

    -- Remove translation
    love.graphics.pop()

    -- Clear scissor
    love.graphics.setScissor()

    -- Draw canvas to screen with scaling
    love.graphics.setCanvas()
    love.graphics.draw(canvas, 0, 0, 0, PIXEL_SCALE, PIXEL_SCALE)
end

function love.update(dt)
    players.input()
    players.update(dt)
end

function love.keypressed(key)
    -- TEMPORARY: Press 'x' to damage player for testing
    if key == 'x' then
        if players.list[1] then
            players.list[1]:damage()
        end
    end
end

function love.quit()

end