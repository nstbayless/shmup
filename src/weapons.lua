local bullets = require "src/bullets"

local weapons = {}

-- List of available weapons
WEAPONS = {"standard", "bishot", "radiater", "flamer"}

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

        -- Play shoot sound
        local players_module = package.loaded["src/players"]
        if players_module and players_module.playShootSound then
            players_module.playShootSound()
        end

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

        -- Play shoot sound
        local players_module = package.loaded["src/players"]
        if players_module and players_module.playShootSound then
            players_module.playShootSound()
        end

        -- 9 shots per second = 1/9 second between shots
        player.firing_p = 1 / 9
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

        -- Play shoot sound
        local players_module = package.loaded["src/players"]
        if players_module and players_module.playShootSound then
            players_module.playShootSound()
        end

        -- Advance angle by random 1-9 degrees clockwise
        player.radiater_angle = (player.radiater_angle + math.random() * 8) % 360

        -- 7 shots per second = 1/7 second between shots
        player.firing_p = 1 / 7
    end
end

-- Flamer weapon implementation
local weapon_flamer = {
    name = "Flamer",
    sprite_index = 4
}

function weapon_flamer:init(player)
    player.firing_p = 0
end

function weapon_flamer:update(player, dt)
    -- Decrease firing cooldown
    if player.firing_p > 0 then
        player.firing_p = player.firing_p - dt
    end

    -- Check if player is pressing fire button
    if player.firing and player.firing_p <= 0 then
        -- Generate 3 shots with their bullets
        local shots = {}
        local speed = 4

        for i = 1, 3 do
            -- Base direction: north (0 degrees) + random(-40, +40)
            local angle_degrees = (math.random() * 80 - 40)

            -- 25% chance to add additional random(-20, +20)
            if math.random() < 0.25 then
                angle_degrees = angle_degrees + (math.random() * 40 - 20)
            end

            local angle_radians = math.rad(angle_degrees)

            -- Calculate velocity components
            local vx = speed * math.sin(angle_radians)
            local vy = -speed * math.cos(angle_radians)

            -- Calculate distance to live: 64 + random(32) - 1 per degree from north
            -- Base: 64-96 pixels, reduced by absolute degrees away from north
            local distance_to_live = (64 + math.random() * 32) - math.abs(angle_degrees)

            -- Flamer damage: 0.5 HP per bullet
            local damage = 0.5

            -- Create bullet
            local bullet = bullets.new(player.x, player.y, vx, vy, "flamer", player, distance_to_live, damage)

            -- Store bullet and its angle
            table.insert(shots, {bullet = bullet, angle = angle_degrees})
        end

        -- Check for shots within 5 degrees of each other and mark for deletion
        for i = 1, #shots do
            for j = i + 1, #shots do
                if shots[i].bullet.alive and shots[j].bullet.alive then
                    if math.abs(shots[i].angle - shots[j].angle) < 5 then
                        -- Two shots within 5 degrees, remove the one closest to north (0)
                        local dist_i = math.abs(shots[i].angle)
                        local dist_j = math.abs(shots[j].angle)

                        if dist_i < dist_j then
                            -- i is closer to north, remove it
                            shots[i].bullet.alive = false
                        elseif dist_j < dist_i then
                            -- j is closer to north, remove it
                            shots[j].bullet.alive = false
                        else
                            -- Equal distance, remove first one (i)
                            shots[i].bullet.alive = false
                        end
                    end
                end
            end
        end

        -- Play shoot sound
        local players_module = package.loaded["src/players"]
        if players_module and players_module.playShootSound then
            players_module.playShootSound()
        end

        -- 16 shots per second = 1/16 second between shots
        player.firing_p = 1 / 16
    end
end

-- Global weapon type definitions
WeaponTypes = {
    standard = weapon_standard,
    bishot = weapon_bishot,
    radiater = weapon_radiater,
    flamer = weapon_flamer
}

return weapons
