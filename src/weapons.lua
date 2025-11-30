local bullets = require "src/bullets"

local weapons = {}

-- List of available weapons
WEAPONS = {"standard", "bishot", "radiater"}

-- Standard weapon implementation
local weapon_standard = {
    name = "Standard",
    sprite_index = 1
}

function weapon_standard:init(player)
    player.firing_p = 0
end

function weapon_standard:update(player, dt)
    -- Decrease firing cooldown
    if player.firing_p > 0 then
        player.firing_p = player.firing_p - dt
    end

    -- Check if player is pressing fire button
    if player.firing and player.firing_p <= 0 then
        -- Fire bullet straight up
        bullets.new(player.x, player.y, 0, -4, "player", player)

        -- 6 bullets per second = 1/6 second between shots
        player.firing_p = 1 / 8
    end
end

-- Bishot weapon implementation
local weapon_bishot = {
    name = "Bishot",
    sprite_index = 2
}

function weapon_bishot:init(player)
    player.firing_p = 0
end

function weapon_bishot:update(player, dt)
    -- Decrease firing cooldown
    if player.firing_p > 0 then
        player.firing_p = player.firing_p - dt
    end

    -- Check if player is pressing fire button
    if player.firing and player.firing_p <= 0 then
        -- Random angle between 20 and 40 degrees from north
        local angle_degrees = 20 + math.random() * 20
        local angle_radians = math.rad(angle_degrees)

        -- Base speed upward
        local base_speed = 4

        -- Calculate velocity components for both bullets
        -- Positive angle (right)
        local vx1 = base_speed * math.sin(angle_radians)
        local vy1 = -base_speed * math.cos(angle_radians)

        -- Negative angle (left) - reflected across y-axis
        local vx2 = -vx1
        local vy2 = vy1

        -- Fire both bullets
        bullets.new(player.x, player.y, vx1, vy1, "player", player)
        bullets.new(player.x, player.y, vx2, vy2, "player", player)

        -- 3 shots per second = 1/3 second between shots
        player.firing_p = 1 / 5
    end
end

-- Radiater weapon implementation
local weapon_radiater = {
    name = "Radiater",
    sprite_index = 3
}

function weapon_radiater:init(player)
    player.firing_p = 0
    player.radiater_angle = 0  -- Current firing angle in degrees
end

function weapon_radiater:update(player, dt)
    -- Decrease firing cooldown
    if player.firing_p > 0 then
        player.firing_p = player.firing_p - dt
    end

    -- Check if player is pressing fire button
    if player.firing and player.firing_p <= 0 then
        -- Fire two bullets at opposite angles
        local speed = 4

        -- First bullet at current angle
        local angle1_rad = math.rad(player.radiater_angle)
        local vx1 = math.sin(angle1_rad) * speed
        local vy1 = -math.cos(angle1_rad) * speed
        bullets.new(player.x, player.y, vx1, vy1, "radiater", player)

        -- Second bullet at opposite angle (180 degrees apart)
        local angle2_rad = math.rad(player.radiater_angle + 180)
        local vx2 = math.sin(angle2_rad) * speed
        local vy2 = -math.cos(angle2_rad) * speed
        bullets.new(player.x, player.y, vx2, vy2, "radiater", player)

        -- Advance angle by random 0-8 degrees clockwise
        player.radiater_angle = (player.radiater_angle + math.random() * 8) % 360

        -- 7 shots per second = 1/7 second between shots
        player.firing_p = 1 / 7
    end
end

-- Global weapon type definitions
WeaponTypes = {
    standard = weapon_standard,
    bishot = weapon_bishot,
    radiater = weapon_radiater
}

return weapons
