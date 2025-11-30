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
local powerups = require "src/powerups"
local waves = require "src/waves"
local music = require "src/music"

local frame_accumulate = 0.5
local canvas
local canvas_width, canvas_height
local debug_draw = false
local debug_mode = false  -- Only true if --debug is passed as CLI arg

-- Initialize game state
local function init()
    players.init()
    enemies.init()
    bullets.init()
    particles.init()
    powerups.init()
    waves.init()
    players.ensure_players(1)

    -- Start first wave
    local firstWave = waves.getNextWave()
    waves.start(firstWave)

    -- Initialize music (plays intro then loops main)
    music.init()
end

function love.load(args)
    -- Check for --debug flag in command-line arguments
    if args then
        for _, arg in ipairs(args) do
            if arg == "--debug" then
                debug_mode = true
                break
            end
        end
    end

    love.window.setTitle("Shmup")

    -- Set up pixel-perfect scaling
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Calculate canvas size based on pixel scale
    canvas_width = math.floor(WINDOW_W / PIXEL_SCALE)
    canvas_height = math.floor(WINDOW_H / PIXEL_SCALE)
    canvas = love.graphics.newCanvas(canvas_width, canvas_height)

    -- Load assets
    players.load()
    enemies.load()
    bullets.load()
    particles.load()
    powerups.load()
    music.load()

    -- Initialize game state
    init()
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
    love.graphics.setColor(1, 1, 1)

    -- Draw weapon stack UI (before scissor is enabled)
    players.draw_ui()

    -- Draw kill counter at top right
    local killText = "Kills: " .. enemies.killCount
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(killText)

    -- Position at top right with small margin
    local x = canvas_width - textWidth - 5
    local y = 5

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(killText, x, y)

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

    -- Draw all powerups
    powerups.render()

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

        -- Draw angle info for snake heads (white text)
        love.graphics.setColor(1, 1, 1)
        for _, enemy in ipairs(enemies.list) do
            if enemy.type == "snakeHead" and enemy.alive then
                local text = string.format("%.1f/%.1f", enemy.targetDir, enemy.currentDir)
                love.graphics.print(text, enemy.x - 15, enemy.y - 10)
            end
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
    -- Check for true death reset
    if players.list[1] and players.list[1].true_death and players.list[1].explodeTime >= 4 then
        if players.list[1].firing then
            -- Reset game
            init()
            return
        end
    end

    -- Check for player true death and stop music
    if players.list[1] then
        music.check_player_death(players.list[1])
    end

    -- Update music (transitions from intro to main loop)
    music.update()

    players.input()
    players.update(dt)
    enemies.update(dt)
    bullets.update(dt)
    particles.update(dt)
    powerups.update(dt)

    -- Update waves and handle wave completion
    local remainingTime = waves.update(dt)
    if remainingTime then
        -- Wave completed, reduce powerup spawn timer by 30% of remaining time
        powerups.spawn_timer = powerups.spawn_timer - (remainingTime * 0.3)

        -- Start next wave
        local nextWave = waves.getNextWave()
        waves.start(nextWave)
    end

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
                        -- Reduce enemy HP
                        enemy.hp = enemy.hp - bullet.damage
                        enemy.damageFlashTimer = 0.06  -- Flash white for 0.1 seconds
                        bullet.alive = false

                        -- Play hit sound
                        enemies.playHitSound()

                        -- Check if enemy is dead
                        if enemy.hp <= 0 then
                            enemy.alive = false
                            -- Create explosion particle
                            particles.new(enemy.x, enemy.y, "explosion")
                            -- Play explosion sound
                            enemies.playExplosionSound()
                            -- Increment kill counter
                            enemies.killCount = enemies.killCount + 1
                        end
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
                        -- Skip collision if player is in hitStun or enemy has collision immunity
                        if player.hitStun > 0 or enemy.collisionImmunity > 0 then
                            break
                        end

                        player:damage()

                        -- Special rule: snake bodies always die on player collision
                        local instant_kill = enemy.type == "snakeBody"

                        -- Enemy takes 8 HP damage from collision (or instant kill)
                        if instant_kill then
                            enemy.hp = 0
                        else
                            enemy.hp = enemy.hp - 8
                        end
                        enemy.damageFlashTimer = 0.06

                        -- Play hit sound
                        enemies.playHitSound()

                        if enemy.hp <= 0 then
                            -- Enemy dies from collision
                            player.hitStun = 0.08
                            enemy.alive = false
                            -- Create explosion particle
                            particles.new(enemy.x, enemy.y, "explosion")
                            -- Play explosion sound
                            enemies.playExplosionSound()
                            -- Increment kill counter
                            enemies.killCount = enemies.killCount + 1
                        else
                            -- Enemy survives: knockback player and give enemy immunity
                            player.hitStun = 0.18

                            -- Give immunity for a bit
                            if player.meteor_mode then
                                enemy.collisionImmunity = 0.4
                            else
                                enemy.collisionImmunity = 2.0
                            end

                            -- Play knockback sound
                            players.playBackSound()

                            -- Calculate current velocity magnitude
                            local vel_magnitude = math.sqrt(player.vx * player.vx + player.vy * player.vy)

                            -- Calculate knockback direction (away from enemy)
                            local knockback_distance = math.sqrt(dx * dx + dy * dy)
                            if knockback_distance > 0 then
                                local dir_x = dx / knockback_distance
                                local dir_y = dy / knockback_distance

                                -- Set velocity to same magnitude but away from enemy
                                player.vx = dir_x * vel_magnitude
                                player.vy = dir_y * vel_magnitude
                            end
                        end

                        break
                    end
                end
            end
        end
    end

    -- Collision detection: powerups vs players
    for _, powerup in ipairs(powerups.list) do
        if powerup.alive then
            for _, player in ipairs(players.list) do
                if player.alive then
                    local dx = player.x - powerup.x
                    local dy = player.y - powerup.y
                    local distance = math.sqrt(dx * dx + dy * dy)
                    -- Powerup collection using powerup.r
                    if distance < powerup.r then
                        player:collect_weapon(powerup.weapon_type)
                        powerup.alive = false

                        -- Restore shield when picking up powerup
                        player.hasShield = true
                        player.shieldRestore = 0

                        -- Create text particle showing weapon name
                        local weapon = WeaponTypes[powerup.weapon_type]
                        if weapon and weapon.name then
                            local text = string.upper(weapon.name) .. "!"
                            particles.new(player.x, player.y - 24, "text", text)
                        end

                        break
                    end
                end
            end
        end
    end

    enemies.garbage()
    bullets.garbage()
    particles.garbage()
    powerups.garbage()
end

function love.keypressed(key)
    -- Press 'm' to toggle music
    if key == 'm' then
        music.toggle()
    end

    -- Debug keys only available with --debug flag
    if not debug_mode then
        return
    end

    -- TEMPORARY: Press 'x' to damage player for testing
    if key == 'x' then
        if players.list[1] then
            players.list[1]:damage()
        end
    end

    -- TEMPORARY: Press 'e' to spawn an enemy for testing
    if key == 'e' then
        enemies.spawnSnake()
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

    -- Press 'q' to spawn a random weapon powerup (debugging)
    if key == 'q' then
        -- Spawn a random powerup at top of screen (at least 32 pixels from edge)
        local game_width = GAME_WIDTH / PIXEL_SCALE
        local x = 32 + math.random() * (game_width - 64)

        -- Pick a random weapon type (excluding player's current weapon)
        local currentWeapon = players.list[1] and players.list[1].weapon or nil
        local availableWeapons = {}

        -- Get current wave number to determine if meteor can spawn
        local waveNumber = waves.waveNumber

        for _, weapon in ipairs(WEAPONS) do
            local shouldInclude = true

            -- Exclude current weapon
            if weapon == currentWeapon then
                shouldInclude = false
            end

            -- Exclude meteor if before wave 7
            if weapon == "meteor" and waveNumber < 7 then
                shouldInclude = false
            end

            if shouldInclude then
                table.insert(availableWeapons, weapon)
            end
        end

        -- If all weapons are the current weapon (shouldn't happen), just use any weapon
        if #availableWeapons == 0 then
            availableWeapons = WEAPONS
        end

        local random_weapon = availableWeapons[math.random(1, #availableWeapons)]
        powerups.new(x, -10, random_weapon)
    end
end

function love.quit()

end