local spritesheet = require "src/spritesheet"

local powerups = {}

-- List of all powerups
powerups.list = {}

-- Powerup spritesheet
local powerup_quads, powerup_image

-- Spawn timer
powerups.spawn_timer = 0

-- Load powerup assets
function powerups.load()
    powerup_quads, powerup_image = spritesheet.load("assets/contra-weapons-24-16.png")
    -- Set initial spawn timer to random value
    powerups.spawn_timer = 20 + math.random() * 20
end

-- Create a new powerup
function powerups.new(x, y, weapon_type)
    local powerup = {
        x = x or 0,
        y = y or 0,
        vy = 0.5,  -- Drift down slowly
        alive = true,
        weapon_type = weapon_type or "standard"
    }
    table.insert(powerups.list, powerup)
    return powerup
end

-- Remove dead powerups from the list
function powerups.garbage()
    for i = #powerups.list, 1, -1 do
        if not powerups.list[i].alive then
            table.remove(powerups.list, i)
        end
    end
end

-- Update all powerups
function powerups.update(dt)
    -- Update spawn timer
    powerups.spawn_timer = powerups.spawn_timer - dt
    if powerups.spawn_timer <= 0 then
        -- Spawn a random powerup at top of screen
        local game_width = GAME_WIDTH / PIXEL_SCALE
        local x = math.random(10, game_width - 10)

        -- Pick a random weapon type
        local random_weapon = WEAPONS[math.random(1, #WEAPONS)]

        powerups.new(x, -10, random_weapon)

        -- Reset timer to random value between 20-40 seconds
        powerups.spawn_timer = 20 + math.random() * 20
    end

    -- Update each powerup
    for _, powerup in ipairs(powerups.list) do
        powerup.y = powerup.y + powerup.vy

        -- Game region dimensions (scaled by pixel scale)
        local game_height = GAME_HEIGHT / PIXEL_SCALE

        -- Despawn if below bottom + 32 pixel margin
        if powerup.y > game_height + 32 then
            powerup.alive = false
        end
    end
end

-- Render all powerups
function powerups.render()
    if not powerup_quads or not powerup_image then
        return
    end

    for _, powerup in ipairs(powerups.list) do
        -- Get sprite index from weapon definition
        local sprite_index = WeaponSprites[powerup.weapon_type] or 1

        -- Get sprite dimensions to center it
        local _, _, sprite_w, sprite_h = powerup_quads[sprite_index]:getViewport()
        local offset_x = sprite_w / 2
        local offset_y = sprite_h / 2

        -- Draw the powerup sprite centered on x, y
        love.graphics.draw(powerup_image, powerup_quads[sprite_index], powerup.x - offset_x, powerup.y - offset_y)
    end
end

return powerups
