local spritesheet = require "src/spritesheet"
local bullets = require "src/bullets"
local players = require "src/players"
local particles = require "src/particles"

local enemies = {}

-- List of all enemies
enemies.list = {}

-- Current wave number (for HP calculations)
enemies.currentWave = 0

-- Enemy spritesheet
local enemy_quads, enemy_image

-- Initialize enemies module state
function enemies.init()
    enemies.list = {}
end

-- Load enemy assets
function enemies.load()
    enemy_quads, enemy_image = spritesheet.load("assets/enemies-16-16.png")
end

-- Create a new enemy
function enemies.new(x, y, type, config)
    local game_width = GAME_WIDTH / PIXEL_SCALE
    local game_height = GAME_HEIGHT / PIXEL_SCALE

    local enemy = {
        x = x or 0,
        y = y or 0,
        r = 5,  -- Collision radius
        alive = true,
        type = type or "standard",
        fireTimer = math.random() + 1  -- Random time between 1-2 seconds (for standard enemy)
    }

    -- Type-specific initialization
    if type == "positioner" then
        -- Set destination coordinates
        enemy.dstX = math.random() * game_width
        enemy.dstY = math.random() * (game_height / 2)  -- Top half of game area

        -- Calculate center of game area
        local centerX = game_width / 2

        -- Initial x is twice as far from center as dstX
        local dstDistanceFromCenter = enemy.dstX - centerX
        enemy.x = centerX + (dstDistanceFromCenter * 2)

        -- Clamp x position to game region
        enemy.x = math.max(0, math.min(game_width, enemy.x))

        enemy.y = -16

        -- Calculate and store original distance to destination
        local dx = enemy.dstX - enemy.x
        local dy = enemy.dstY - enemy.y
        enemy.originalDistance = math.sqrt(dx * dx + dy * dy)

        -- Initialize state
        enemy.state = "approaching"
        enemy.burstCooldown = 0
        enemy.burstTimer = 0
        enemy.shotsInBurst = 0
        enemy.burstsCompleted = 0
        enemy.directShotIndex = nil
        enemy.exitVelocity = 0
        enemy.exitDirection = 0
    elseif type == "snakeHead" then
        -- Snake head specific initialization
        enemy.currentDir = config and config.initialDir or 180  -- Direction in degrees
        enemy.targetDir = enemy.currentDir
        enemy.speed = 40  -- pixels per second
        enemy.aliveTime = 0  -- Track how long snake has been alive
        enemy.animTime = 0
        enemy.tail = nil  -- Reference to the last body piece
        enemy.bodyCount = 0  -- Count of living body pieces
    elseif type == "snakeBody" then
        -- Snake body specific initialization
        enemy.following = config and config.following or nil  -- Reference to piece in front
        enemy.head = config and config.head or nil  -- Reference to the head
        enemy.deathTimer = 0  -- Timer before exploding when leader dies
        enemy.animTime = 0
    end

    table.insert(enemies.list, enemy)
    return enemy
end

-- Spawn a complete snake
function enemies.spawnSnake()
    local game_width = GAME_WIDTH / PIXEL_SCALE

    -- Random number of segments (5-10 including head)
    local segmentCount = math.random(5, 10)

    -- Random x position
    local x = math.random() * game_width
    local y = -16

    -- Initial direction: south ± 30 degrees
    local initialDir = 180 + (math.random() * 60 - 30)

    -- Create head
    local head = enemies.new(x, y, "snakeHead", {initialDir = initialDir})

    -- Create body segments
    local previous = head
    local tail = head
    for i = 1, segmentCount - 1 do
        -- Position body segments 16 pixels above (behind) the head
        local bodyX = x
        local bodyY = y - 16 * i

        local body = enemies.new(bodyX, bodyY, "snakeBody", {following = previous, head = head})
        previous = body
        tail = body
        head.bodyCount = head.bodyCount + 1
    end

    -- Store reference to tail in head
    head.tail = tail

    return head
end

-- Remove dead enemies from the list
function enemies.garbage()
    for i = #enemies.list, 1, -1 do
        if not enemies.list[i].alive then
            table.remove(enemies.list, i)
        end
    end
end

-- Update all enemies
function enemies.update(dt)
    for _, enemy in ipairs(enemies.list) do
        local enemy_type = EnemyTypes[enemy.type]
        if enemy_type and enemy_type.update then
            enemy_type.update(enemy, dt)
        end
    end
end

-- Render all enemies
function enemies.render()
    for _, enemy in ipairs(enemies.list) do
        local enemy_type = EnemyTypes[enemy.type]
        if enemy_type and enemy_type.render then
            enemy_type.render(enemy)
        end
    end
end

-- Standard enemy update function
function enemy_update_standard(e, dt)
    -- Update fire timer
    e.fireTimer = e.fireTimer - dt

    -- Fire bullet when timer expires
    if e.fireTimer <= 0 then
        -- Reset timer to random value between 1-2 seconds
        e.fireTimer = math.random() + 1

        -- Fire toward player 0 if they exist
        if players.list[1] then
            local player = players.list[1]

            -- Calculate direction from enemy to player
            local dx = player.x - e.x
            local dy = player.y - e.y
            local distance = math.sqrt(dx * dx + dy * dy)

            -- Normalize and scale by bullet speed
            if distance > 0 then
                local vx = (dx / distance) * BULLET_SPEED
                local vy = (dy / distance) * BULLET_SPEED

                -- Create bullet
                bullets.new(e.x, e.y, vx, vy, "standard")
            end
        end
    end
end

-- Standard enemy render function
function enemy_render_standard(e)
    if not enemy_quads or not enemy_image then
        return
    end

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = enemy_quads[1]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Draw the first enemy sprite centered on x, y
    love.graphics.draw(enemy_image, enemy_quads[1], e.x - offset_x, e.y - offset_y)
end

-- Positioner enemy update function
function enemy_update_positioner(e, dt)
    local game_width = GAME_WIDTH / PIXEL_SCALE

    if e.state == "approaching" then
        -- Calculate current distance to destination
        local dx = e.dstX - e.x
        local dy = e.dstY - e.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance < 1 then
            -- Reached destination, snap to exact position and stop
            e.x = e.dstX
            e.y = e.dstY
            e.state = "firing"
            e.burstCooldown = math.random() + 3  -- 3-4 seconds until first burst
            e.burstsCompleted = 0
        else
            -- Calculate speed based on distance ratio
            -- Speed lerps from 100 px/s (at original distance) to 25 px/s (at destination)
            local ratio = distance / e.originalDistance
            local speed = 25 + 75 * ratio  -- Lerp from 25 to 100

            -- Move in straight line toward destination
            local dirX = dx / distance
            local dirY = dy / distance

            e.x = e.x + dirX * speed * dt
            e.y = e.y + dirY * speed * dt
        end
    elseif e.state == "firing" then
        -- Update burst cooldown
        if e.burstCooldown > 0 then
            e.burstCooldown = e.burstCooldown - dt
            if e.burstCooldown <= 0 then
                -- Start new burst
                e.shotsInBurst = 0
                e.burstTimer = 0
            end
        end

        -- Fire shots in burst
        if e.burstCooldown <= 0 and e.burstTimer <= 0 and e.shotsInBurst < 4 then
            -- Fire a shot
            if players.list[1] and players.list[1].alive then
                local player = players.list[1]
                local targetX, targetY

                -- One random shot in the burst is aimed directly at player
                if e.directShotIndex == nil then
                    e.directShotIndex = math.random(1, 4)
                end

                if e.shotsInBurst + 1 == e.directShotIndex then
                    -- Aim directly at player
                    targetX = player.x
                    targetY = player.y
                else
                    -- Aim at random point within 40 px of player
                    local angle = math.random() * 2 * math.pi
                    local dist = math.random() * 40
                    targetX = player.x + math.cos(angle) * dist
                    targetY = player.y + math.sin(angle) * dist
                end

                -- Calculate direction and fire bullet
                local dx = targetX - e.x
                local dy = targetY - e.y
                local distance = math.sqrt(dx * dx + dy * dy)

                if distance > 0 then
                    -- Positioner bullets travel at 70% of normal speed
                    local bulletSpeed = BULLET_SPEED * 0.7
                    local vx = (dx / distance) * bulletSpeed
                    local vy = (dy / distance) * bulletSpeed
                    bullets.new(e.x, e.y, vx, vy, "standard")
                end
            end

            e.shotsInBurst = e.shotsInBurst + 1
            e.burstTimer = 0.1  -- 0.1 seconds between shots

            -- Check if burst is complete
            if e.shotsInBurst >= 4 then
                e.burstsCompleted = e.burstsCompleted + 1
                e.directShotIndex = nil  -- Reset for next burst

                if e.burstsCompleted >= 5 then
                    -- Start exiting
                    e.state = "exiting"
                    e.exitDirection = math.random() < 0.5 and -1 or 1  -- Left or right
                    e.exitVelocity = 0

                    -- Set exit destination
                    if e.exitDirection < 0 then
                        e.exitDstX = -32
                    else
                        e.exitDstX = game_width + 32
                    end
                    e.exitDstY = e.y + math.random() * 120 - 30  -- -30 to +90
                else
                    -- Start cooldown for next burst
                    e.burstCooldown = math.random() + 1
                end
            end
        end

        -- Update burst shot timer
        if e.burstTimer > 0 then
            e.burstTimer = e.burstTimer - dt
        end
    elseif e.state == "exiting" then
        -- Accelerate toward exit
        e.exitVelocity = math.min(e.exitVelocity + 150 * dt, 120)  -- Accelerate at 150 px/s/s, max 120 px/s

        -- Move toward exit destination
        e.x = e.x + e.exitDirection * e.exitVelocity * dt
        e.y = toward(e.y, e.exitDstY, dt * e.exitVelocity)

        -- Check if off screen
        if (e.exitDirection < 0 and e.x < -32) or (e.exitDirection > 0 and e.x > game_width + 32) then
            e.alive = false
        end
    end
end

-- Positioner enemy render function
function enemy_render_positioner(e)
    if not enemy_quads or not enemy_image then
        return
    end

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = enemy_quads[2]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Draw the second enemy sprite centered on x, y
    love.graphics.draw(enemy_image, enemy_quads[2], e.x - offset_x, e.y - offset_y)
end

-- Snake head update function
function enemy_update_snakeHead(e, dt)
    local game_width = GAME_WIDTH / PIXEL_SCALE
    local game_height = GAME_HEIGHT / PIXEL_SCALE

    -- Update alive time
    e.aliveTime = e.aliveTime + dt

    -- Update animation time
    e.animTime = e.animTime + dt

    -- Pick new target direction only when we've reached the current target
    -- If we have fewer than 2 body pieces, don't change direction (keep going straight)
    if e.bodyCount >= 2 and e.currentDir == e.targetDir then
        if e.y > game_height * 0.95 then
            -- Below 95% line: always point straight down
            e.targetDir = 180
        elseif e.aliveTime < 20 then
            -- Pick a random coordinate on the board and steer toward it
            local targetX = math.random() * game_width
            local targetY = math.random() * game_height
            local dx = targetX - e.x
            local dy = targetY - e.y
            e.targetDir = math.deg(math.atan2(dx, -dy))
        else
            -- After 30 seconds, pick random point in southern region
            e.targetDir = 180 + math.random() * 60 - 30
        end
    end

    -- Special behaviors based on position
    if e.y < 0 then
        -- Above screen: point straight down
        e.targetDir = 180
    elseif e.x < 0 or e.x > game_width then
        -- Left or right of screen: point toward center
        local centerX = game_width / 2
        local centerY = game_height / 2
        local dx = centerX - e.x
        local dy = centerY - e.y
        e.targetDir = math.deg(math.atan2(dx, dy))
    end

    -- Adjust current direction toward target direction using modular_toward
    e.currentDir = modular_toward(e.currentDir, e.targetDir, 360, dt * 50)

    -- Move based on current direction
    local angle = math.rad(e.currentDir)
    e.x = e.x + math.sin(angle) * e.speed * dt
    e.y = e.y - math.cos(angle) * e.speed * dt

    -- Despawn only if both head and tail are below bottom of screen
    if e.y > game_height then
        -- Check if tail is also below screen (or doesn't exist/isn't alive)
        if not e.tail or not e.tail.alive or e.tail.y > game_height then
            e.alive = false
        end
    end
end

-- Snake head render function
function enemy_render_snakeHead(e)
    if not enemy_quads or not enemy_image then
        return
    end

    -- Animate between frames 5 and 6 at 3 Hz
    local frame_duration = 1 / 3
    local frame_index = 5 + (math.floor(e.animTime / frame_duration) % 2)

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = enemy_quads[frame_index]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Calculate y velocity to determine if we need to flip
    local angle = math.rad(e.currentDir)
    local vy = math.cos(angle) * e.speed

    -- Flip vertically if moving upward (negative y velocity)
    local scaleY = (vy > 0) and -1 or 1

    -- Draw the sprite centered on x, y
    love.graphics.draw(
        enemy_image,
        enemy_quads[frame_index],
        e.x,
        e.y,
        0,
        1,
        scaleY,
        offset_x,
        offset_y
    )
end

-- Snake body update function
function enemy_update_snakeBody(e, dt)
    -- Update animation time
    e.animTime = e.animTime + dt

    -- Check if piece we're following is alive
    if not e.following or not e.following.alive then
        -- Leader is dead, start death timer
        e.deathTimer = e.deathTimer + dt
        if e.deathTimer >= 0.2 then
            e.alive = false
            -- Create explosion particle
            particles.new(e.x, e.y, "explosion")
            -- Decrement head's body count
            if e.head and e.head.alive then
                e.head.bodyCount = e.head.bodyCount - 1
            end
        end
        return
    end

    -- Follow the piece in front
    local dx = e.x - e.following.x
    local dy = e.y - e.following.y
    local distance = math.sqrt(dx * dx + dy * dy)

    if distance > 0 then
        -- Normalize and set to 16 pixels away
        local normalizedX = dx / distance
        local normalizedY = dy / distance
        e.x = e.following.x + normalizedX * 16
        e.y = e.following.y + normalizedY * 16
    end
end

-- Snake body render function
function enemy_render_snakeBody(e)
    if not enemy_quads or not enemy_image then
        return
    end

    -- Animate between frames 19-22 at 8 Hz
    local frame_duration = 1 / 8
    local frame_index = 17 + (math.floor(e.animTime / frame_duration) % 4)

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = enemy_quads[frame_index]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Draw the sprite centered on x, y
    love.graphics.draw(enemy_image, enemy_quads[frame_index], e.x - offset_x, e.y - offset_y)
end

-- Global enemy type definitions
EnemyTypes = {
    standard = {
        update = enemy_update_standard,
        render = enemy_render_standard
    },
    positioner = {
        update = enemy_update_positioner,
        render = enemy_render_positioner
    },
    snakeHead = {
        update = enemy_update_snakeHead,
        render = enemy_render_snakeHead
    },
    snakeBody = {
        update = enemy_update_snakeBody,
        render = enemy_render_snakeBody
    }
}

return enemies
