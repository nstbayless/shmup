local spritesheet = require "src/spritesheet"

local powerups = {}

-- List of all powerups
powerups.list = {}

-- Powerup spritesheet
local powerup_quads, powerup_image

-- Spawn timer
powerups.spawn_timer = 0
powerups.spawn_count = 0  -- Track how many powerups have spawned

-- Initialize powerups module state
function powerups.init()
    powerups.list = {}
    powerups.spawn_timer = 5  -- First powerup after 5 seconds
    powerups.spawn_count = 0
end

-- Load powerup assets
function powerups.load()
    powerup_quads, powerup_image = spritesheet.load("assets/contra-weapons-24-16.png")
end

-- Create a new powerup
function powerups.new(x, y, weapon_type)
    local powerup = {
        x = x or 0,
        y = y or 0,
        r = 9,  -- Collision radius
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
    -- Check if player has more than 4 weapons on stack - if so, tick 30% slower
    local players = require "src/players"
    local adjusted_dt = dt
    if players.list[1] and #players.list[1].weapon_stack > 4 then
        adjusted_dt = dt * 0.7  -- Tick 30% slower
    end

    -- Update spawn timer with adjusted dt
    powerups.spawn_timer = powerups.spawn_timer - adjusted_dt
    if powerups.spawn_timer <= 0 then
        -- Spawn a random powerup at top of screen (at least 32 pixels from edge)
        local game_width = GAME_WIDTH / PIXEL_SCALE
        local x = 32 + math.random() * (game_width - 64)

        -- Pick a random weapon type (excluding player's current weapon)
        local currentWeapon = players.list[1] and players.list[1].weapon or nil
        local availableWeapons = {}

        -- Get current wave number to determine if meteor can spawn
        local waves = require "src/waves"
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

        -- Calculate next spawn interval
        -- First powerup: 5s, second: 10s later, then +5s each time
        powerups.spawn_count = powerups.spawn_count + 1
        if powerups.spawn_count == 1 then
            -- After first powerup, wait 10 seconds for second
            powerups.spawn_timer = 10
        else
            -- After second powerup, add 5 seconds each time
            -- spawn_count=2 -> 15s, spawn_count=3 -> 20s, etc.
            powerups.spawn_timer = 10 + (powerups.spawn_count - 1) * 5
        end
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
        local weapon = WeaponTypes[powerup.weapon_type]
        local sprite_index = weapon and weapon.sprite_index or 1

        -- Get sprite dimensions to center it
        local _, _, sprite_w, sprite_h = powerup_quads[sprite_index]:getViewport()
        local offset_x = sprite_w / 2
        local offset_y = sprite_h / 2

        -- Draw the powerup sprite centered on x, y
        love.graphics.draw(powerup_image, powerup_quads[sprite_index], powerup.x - offset_x, powerup.y - offset_y)
    end
end

return powerups
