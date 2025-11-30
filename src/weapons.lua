local bullets = require "src/bullets"

local weapons = {}

-- List of available weapons
WEAPONS = {"standard", "bishot", "radiator", "flamer", "meteor"}

-- Standard weapon implementation
local weapon_standard = {
    name = "Standard",
    sprite_index = 3
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
    sprite_index = 5
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

-- Radiator weapon implementation
local weapon_radiator = {
    name = "Radiator",
    sprite_index = 4
}

function weapon_radiator:init(player)
    player.firing_p = 0
    player.radiator_angle = 0  -- Current firing angle in degrees
end

function weapon_radiator:update(player, dt)
    -- Decrease firing cooldown
    if player.firing_p > 0 then
        player.firing_p = player.firing_p - dt
    end

    -- Check if player is pressing fire button
    if player.firing and player.firing_p <= 0 then
        -- Fire three bullets equally spaced (120 degrees apart)
        local speed = 4

        -- First bullet at current angle
        local angle1_rad = math.rad(player.radiator_angle)
        local vx1 = math.sin(angle1_rad) * speed
        local vy1 = -math.cos(angle1_rad) * speed
        bullets.new(player.x, player.y, vx1, vy1, "radiator", player)

        -- Second bullet at +120 degrees
        local angle2_rad = math.rad(player.radiator_angle + 120)
        local vx2 = math.sin(angle2_rad) * speed
        local vy2 = -math.cos(angle2_rad) * speed
        bullets.new(player.x, player.y, vx2, vy2, "radiator", player)

        -- Third bullet at +240 degrees
        local angle3_rad = math.rad(player.radiator_angle + 240)
        local vx3 = math.sin(angle3_rad) * speed
        local vy3 = -math.cos(angle3_rad) * speed
        bullets.new(player.x, player.y, vx3, vy3, "radiator", player)

        -- Play shoot sound
        local players_module = package.loaded["src/players"]
        if players_module and players_module.playShootSound then
            players_module.playShootSound()
        end

        -- Advance angle by random 1-9 degrees
        -- Direction depends on weapon stack size: even = counterclockwise, odd = clockwise
        local angle_delta = math.random() * 8
        if #player.weapon_stack % 2 == 0 then
            -- Even stack size: rotate counterclockwise (subtract)
            player.radiator_angle = (player.radiator_angle - angle_delta) % 360
        else
            -- Odd stack size: rotate clockwise (add)
            player.radiator_angle = (player.radiator_angle + angle_delta) % 360
        end

        -- 7 shots per second = 1/7 second between shots
        player.firing_p = 1 / 7
    end
end

-- Flamer weapon implementation
local weapon_flamer = {
    name = "Flamer",
    sprite_index = 2
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

-- Meteor weapon implementation
local weapon_meteor = {
    name = "Meteor",
    sprite_index = 1
}

function weapon_meteor:init(player)
    player.firing_p = 0
    player.meteor_charge_time = 0  -- Time spent charging (firing while shielded)
    player.meteor_weapon_time = 0  -- Time since weapon was equipped
    -- Select random angle multiplier: 1 or -1
    player.meteor_angle_multiplier = (math.random() < 0.5) and 1 or -1
end

function weapon_meteor:update(player, dt)
    -- Increase weapon time
    player.meteor_weapon_time = player.meteor_weapon_time + dt

    -- Decrease firing cooldown
    if player.firing_p > 0 then
        player.firing_p = player.firing_p - dt
    end

    -- Detect button press (transition from not firing to firing)
    if player.firing and not player.firing_previous then
        -- Button was just pressed
        if player.hasShield then
            -- Activate meteor mode (handled by player)
            player:activate_meteor_mode()
            return
        end
    end

    -- Update charge time when firing with shield
    if player.firing and player.hasShield then
        player.meteor_charge_time = player.meteor_charge_time + dt
    elseif not player.firing then
        -- Reset charge time when button released
        player.meteor_charge_time = 0
    end

    -- Calculate firing rate based on charge
    local fire_rate = 1 / 5  -- Base: 5 Hz
    if player.hasShield then
        -- Decrease rate over 4 seconds until it stops
        if player.meteor_charge_time >= 4 then
            -- Stop firing after 4 seconds
            return
        end
        -- Gradually increase fire_rate (slower firing)
        local slowdown_factor = 1 + (player.meteor_charge_time / 4) * 4  -- 1x to 5x slower
        fire_rate = fire_rate * slowdown_factor
    end

    -- Check if player is pressing fire button
    if player.firing and player.firing_p <= 0 then
        -- Calculate angle using sin(t) oscillating between -50 and +50 degrees
        local angle_degrees = math.sin(player.meteor_weapon_time) * 50 * player.meteor_angle_multiplier
        local angle_radians = math.rad(angle_degrees)

        -- Base speed
        local speed = 4

        -- Calculate velocity components
        local vx = speed * math.sin(angle_radians)
        local vy = -speed * math.cos(angle_radians)

        -- Fire bullet
        bullets.new(player.x, player.y, vx, vy, "player", player)

        -- Play shoot sound
        local players_module = package.loaded["src/players"]
        if players_module and players_module.playShootSound then
            players_module.playShootSound()
        end

        player.firing_p = fire_rate
    end
end

-- Meteor weapon shield color function (flickers blue/red at 4 Hz when has shield)
function weapon_meteor:isShieldRed(player)
    -- Flicker between blue and red at 4 Hz when has shield
    if player.hasShield then
        local time = love.timer.getTime()
        local flicker_period = 1 / 4
        local flicker_on = (math.floor(time / flicker_period) % 2) == 0
        return flicker_on  -- true = red, false = blue
    end
    return false
end

-- Global weapon type definitions
WeaponTypes = {
    standard = weapon_standard,
    bishot = weapon_bishot,
    radiator = weapon_radiator,
    flamer = weapon_flamer,
    meteor = weapon_meteor
}

return weapons
