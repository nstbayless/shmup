local spritesheet = require "src/spritesheet"
local bullets = require "src/bullets"
local players = require "src/players"

local enemies = {}

-- List of all enemies
enemies.list = {}

-- Enemy spritesheet
local enemy_quads, enemy_image

-- Load enemy assets
function enemies.load()
    enemy_quads, enemy_image = spritesheet.load("assets/enemies-16-16.png")
end

-- Create a new enemy
function enemies.new(x, y, type)
    local enemy = {
        x = x or 0,
        y = y or 0,
        r = 5,  -- Collision radius
        alive = true,
        type = type or "standard",
        fireTimer = math.random() + 1  -- Random time between 1-2 seconds
    }
    table.insert(enemies.list, enemy)
    return enemy
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

-- Global enemy type definitions
EnemyTypes = {
    standard = {
        update = enemy_update_standard,
        render = enemy_render_standard
    }
}

return enemies
