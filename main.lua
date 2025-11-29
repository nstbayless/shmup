if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

MUTE = false
math.randomseed(os.time())

require "src/config"
require "src/util"
local weapons = require "src/weapons"
local players = require "src/players"
local enemies = require "src/enemies"
local bullets = require "src/bullets"
local particles = require "src/particles"

local frame_accumulate = 0.5
local canvas
local canvas_width, canvas_height
local debug_draw = false

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

    -- Initialize enemies
    enemies.load()

    -- Initialize bullets
    bullets.load()

    -- Initialize particles
    particles.load()
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

    -- Draw all enemies
    enemies.render()

    -- Draw all bullets
    bullets.render()

    -- Draw all particles
    particles.render()

    -- Draw all players
    players.draw()

    -- Debug drawing
    if debug_draw then
        -- Draw plus shapes for bullets (red)
        love.graphics.setColor(1, 0, 0)
        for _, bullet in ipairs(bullets.list) do
            love.graphics.line(bullet.x - 3, bullet.y, bullet.x + 3, bullet.y)
            love.graphics.line(bullet.x, bullet.y - 3, bullet.x, bullet.y + 3)
        end

        -- Draw plus shapes for enemies (green)
        love.graphics.setColor(0, 1, 0)
        for _, enemy in ipairs(enemies.list) do
            love.graphics.line(enemy.x - 3, enemy.y, enemy.x + 3, enemy.y)
            love.graphics.line(enemy.x, enemy.y - 3, enemy.x, enemy.y + 3)
        end

        -- Draw plus shapes for players (blue)
        love.graphics.setColor(0, 0, 1)
        for _, player in ipairs(players.list) do
            love.graphics.line(player.x - 3, player.y, player.x + 3, player.y)
            love.graphics.line(player.x, player.y - 3, player.x, player.y + 3)
        end

        -- Reset color
        love.graphics.setColor(1, 1, 1)
    end

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
    enemies.update(dt)
    bullets.update(dt)
    particles.update(dt)

    -- Collision detection: enemy bullets vs players
    for _, bullet in ipairs(bullets.list) do
        if bullet.alive and not bullet.owner then  -- Enemy bullet
            for _, player in ipairs(players.list) do
                if player.alive then
                    local dx = player.x - bullet.x
                    local dy = player.y - bullet.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < player.r + bullet.r then
                        player:damage()
                        bullet.alive = false
                        break
                    end
                end
            end
        end
    end

    -- Collision detection: player bullets vs enemies
    for _, bullet in ipairs(bullets.list) do
        if bullet.alive and bullet.owner then  -- Player bullet
            for _, enemy in ipairs(enemies.list) do
                if enemy.alive then
                    local dx = enemy.x - bullet.x
                    local dy = enemy.y - bullet.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < enemy.r + bullet.r then
                        enemy.alive = false
                        bullet.alive = false
                        -- Create explosion particle
                        particles.new(enemy.x, enemy.y, "explosion")
                        break
                    end
                end
            end
        end
    end

    -- Collision detection: enemies vs players
    for _, enemy in ipairs(enemies.list) do
        if enemy.alive then
            for _, player in ipairs(players.list) do
                if player.alive then
                    local dx = player.x - enemy.x
                    local dy = player.y - enemy.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance < player.r + enemy.r then
                        player:damage()
                        enemy.alive = false
                        -- Create explosion particle
                        particles.new(enemy.x, enemy.y, "explosion")
                        break
                    end
                end
            end
        end
    end

    enemies.garbage()
    bullets.garbage()
    particles.garbage()
end

function love.keypressed(key)
    -- TEMPORARY: Press 'x' to damage player for testing
    if key == 'x' then
        if players.list[1] then
            players.list[1]:damage()
        end
    end

    -- TEMPORARY: Press 'e' to spawn an enemy for testing
    if key == 'e' then
        enemies.new(100, 100, "standard")
    end

    -- Press 'd' to toggle debug drawing
    if key == 'd' then
        debug_draw = not debug_draw
    end

    -- Press 'w' to cycle weapons (debugging)
    if key == 'w' then
        if players.list[1] then
            local player = players.list[1]
            -- Find current weapon index
            local current_index = 1
            for i, weapon_name in ipairs(WEAPONS) do
                if weapon_name == player.weapon then
                    current_index = i
                    break
                end
            end
            -- Cycle to next weapon
            local next_index = (current_index % #WEAPONS) + 1
            player:equip_weapon(WEAPONS[next_index])
        end
    end
end

function love.quit()

end