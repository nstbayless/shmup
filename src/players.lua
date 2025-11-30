local spritesheet = require "src/spritesheet"
local weapons = require "src/weapons"

local players = {}

-- Module state
local player_quads, player_image
local shield_image
local shield_red_image
local weapon_icon_quads, weapon_icon_image
local flash_shader

-- Sound effects
local sfx_shield_restore
local sfx_hit
local sfx_death
local sfx_player_shoot
local sfx_meteor
local sfx_back

-- Player object metatable
local Player = {}
Player.__index = Player

-- Create a new player
function players.new(x, y)
    local player = setmetatable({}, Player)
    player.x = x or 0
    player.y = y or 0
    player.vx = 0
    player.vy = 0
    player.r = 5  -- Collision radius
    player.hasShield = true
    player.iTime = 0
    player.shieldRestore = 0
    player.alive = true
    player.explodeTime = 0
    player.shieldAnim = 0  -- 0 = shield present, 1 = shield absent
    player.input_x = 0  -- [-1, 1]
    player.input_y = 0  -- [-1, 1]
    player.weapon = "standard"  -- Current weapon
    player.weapon_stack = {}  -- Stack of fallback weapons
    player.firing = false  -- Is fire button pressed
    player.firing_previous = false  -- Previous frame's firing state (for press detection)
    player.firing_p = 0  -- Weapon-specific state (e.g., cooldown)
    player.respawn_timer = 0  -- Timer for respawning
    player.true_death = false  -- If true, player won't respawn
    player.meteor_mode = false  -- Is player in meteor mode
    player.meteor_timer = 0  -- Remaining time in meteor mode
    player.meteor_particle_timer = 0  -- Timer for spawning meteor particles
    player.meteor_sound_timer = 0  -- Timer for playing meteor sound
    player.shield_red_on_dissipate = false  -- Should shield be red while dissipating after meteor mode
    player.hitStun = 0  -- Hit stun timer (freezes velocity and position)

    table.insert(players.list, player)

    -- Initialize weapon
    player:equip_weapon("standard")

    return player
end

-- Activate meteor mode (called by meteor weapon when button pressed with shield)
function Player:activate_meteor_mode()
    self.meteor_mode = true
    self.meteor_timer = 5
    self.meteor_particle_timer = 0  -- Start spawning particles immediately
    self.meteor_sound_timer = 0  -- Start playing sound immediately

    -- Clear collision immunity from all enemies
    local enemies = require("src/enemies")
    for _, enemy in ipairs(enemies.list) do
        enemy.collisionImmunity = 0
    end
end

-- Equip a weapon
function Player:equip_weapon(weapon_name)
    self.weapon = weapon_name
    local weapon = WeaponTypes[weapon_name]
    if weapon and weapon.init then
        weapon:init(self)
    end
end

-- Collect a weapon powerup (pushes current weapon onto stack)
function Player:collect_weapon(weapon_name)
    -- Push current weapon onto stack
    table.insert(self.weapon_stack, self.weapon)
    -- Equip new weapon
    self:equip_weapon(weapon_name)
end

-- Pop a weapon from the stack
function Player:pop_weapon()
    if #self.weapon_stack > 0 then
        local weapon_name = table.remove(self.weapon_stack)
        self:equip_weapon(weapon_name)
        return true
    end
    return false
end

-- Initialize players module state
function players.init()
    players.list = {}
end

-- Load players module assets (called once)
function players.load()
    player_quads, player_image = spritesheet.load("assets/player-16-16.png")
    shield_image = love.graphics.newImage("assets/shield_Edit.png")
    shield_red_image = love.graphics.newImage("assets/shield_red.png")
    weapon_icon_quads, weapon_icon_image = spritesheet.load("assets/contra-weapons-24-16.png")
    flash_shader = love.graphics.newShader("assets/flash.glsl")

    -- Load sound effects
    sfx_shield_restore = love.audio.newSource("assets/sfx/Player/shoot.wav", "static")
    sfx_hit = love.audio.newSource("assets/sfx/Player/parry.wav", "static")
    sfx_death = love.audio.newSource("assets/sfx/Player/bullet_hit.wav", "static")
    sfx_player_shoot = love.audio.newSource("assets/sfx/Player/player_shoot.wav", "static")
    sfx_meteor = love.audio.newSource("assets/sfx/Player/meteor.wav", "static")
    sfx_back = love.audio.newSource("assets/sfx/Player/back.wav", "static")
end

-- Play player shoot sound
function players.playShootSound()
    if sfx_player_shoot then
        sfx_player_shoot:stop()
        sfx_player_shoot:play()
    end
end

-- Play knockback sound
function players.playBackSound()
    if sfx_back then
        sfx_back:stop()
        sfx_back:play()
    end
end

-- Damage a player
function Player:damage()
    -- Ignore damage during invincibility time
    if self.iTime > 0 then
        return
    end

    -- Ignore damage during meteor mode
    if self.meteor_mode then
        return
    end

    if self.hasShield then
        -- Lose shield
        self.hasShield = false
        self.iTime = DAMAGE_ITIME
        self.shieldRestore = 0

        -- Play hit sound
        if sfx_hit then
            sfx_hit:stop()
            sfx_hit:play()
        end
    else
        -- Die
        self.alive = false
        self.explodeTime = 0
        self.respawn_timer = 2  -- Respawn after 2 seconds

        -- Play death sound
        if sfx_death then
            sfx_death:stop()
            sfx_death:play()
        end
    end
end

-- Respawn the player
function Player:respawn()
    -- Pop a weapon from stack
    if self:pop_weapon() then
        -- Respawn with weapon from stack
        self.alive = true
        self.explodeTime = 0
        self.hasShield = true
        self.shieldRestore = 0
        self.shieldAnim = 1  -- Start shield animation (will animate toward 0)
        self.iTime = 3  -- 3 seconds of invincibility
        self.vx = 0
        self.vy = 0
        -- Reset to starting position (halfway along width, 90% along height)
        local game_width = GAME_WIDTH / PIXEL_SCALE
        local game_height = GAME_HEIGHT / PIXEL_SCALE
        self.x = game_width / 2
        self.y = game_height * 0.9

        -- Create respawn text particle showing weapon name
        local particles = require "src/particles"
        local weapon = WeaponTypes[self.weapon]
        if weapon and weapon.name then
            local weapon_name = string.upper(weapon.name)
            particles.new(self.x, self.y - 24, "respawn_text", weapon_name)
        end
    else
        -- No weapons left - true death
        self.true_death = true
    end
end

-- Ensure at least n players exist
function players.ensure_players(n)
    local current_count = #players.list
    for i = current_count + 1, n do
        -- Create new players at a default position (halfway along width, 90% along height)
        local game_width = GAME_WIDTH / PIXEL_SCALE
        local game_height = GAME_HEIGHT / PIXEL_SCALE
        players.new(game_width / 2, game_height * 0.9)
    end
end

-- Handle input for a single player
function Player:input(input_src)
    -- Reset input
    self.input_x = 0
    self.input_y = 0
    self.firing = false

    -- Add keyboard input
    if love.keyboard.isDown('left') then
        self.input_x = self.input_x - 1
    end
    if love.keyboard.isDown('right') then
        self.input_x = self.input_x + 1
    end
    if love.keyboard.isDown('up') then
        self.input_y = self.input_y - 1
    end
    if love.keyboard.isDown('down') then
        self.input_y = self.input_y + 1
    end

    -- Check keyboard fire button (space key)
    if love.keyboard.isDown('space') then
        self.firing = true
    end

    -- Add gamepad input
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local joystick = joysticks[1]  -- Use first joystick

        -- Add joystick axes for movement
        self.input_x = self.input_x + joystick:getAxis(1)  -- Left stick X axis
        self.input_y = self.input_y + joystick:getAxis(2)  -- Left stick Y axis

        -- OR gamepad fire button (X button / West, button 3)
        if joystick:isDown(3) then
            self.firing = true
        end
    end
end

-- Update player physics
function Player:update(dt)
    -- Normalize input vector to 1.0 if length exceeds 1
    local input_length = math.sqrt(self.input_x * self.input_x + self.input_y * self.input_y)
    if input_length > 1 then
        self.input_x = self.input_x / input_length
        self.input_y = self.input_y / input_length
    end

    -- Update invincibility time
    if self.iTime > 0 then
        self.iTime = toward(self.iTime, 0, dt)
    end

    -- Update hit stun
    if self.hitStun > 0 then
        self.hitStun = toward(self.hitStun, 0, dt)
    end

    -- Update shield animation (moves toward 1 when no shield, toward 0 when shielded)
    local target_anim = self.hasShield and 0 or 1
    self.shieldAnim = toward(self.shieldAnim, target_anim, dt / SHIELD_LOSE_ANIM_TIME)

    -- Update shield restore
    if not self.hasShield then
        -- Shield regenerates faster when holding meteor weapon
        local restore_speed = 1
        if self.weapon == "meteor" then
            restore_speed = 1.3
        end

        self.shieldRestore = self.shieldRestore + (dt / SHIELD_RESTORE_TIME) * restore_speed
        if self.shieldRestore >= 1 then
            self.shieldRestore = 0
            self.hasShield = true
            self.shield_red_on_dissipate = false  -- Reset red dissipate flag

            -- Play shield restore sound
            if sfx_shield_restore then
                sfx_shield_restore:stop()
                sfx_shield_restore:play()
            end
        end
    else
        -- Reset red dissipate flag whenever shield is present
        self.shield_red_on_dissipate = false
    end

    -- If not alive, update explode time and handle respawn
    if not self.alive then
        self.explodeTime = self.explodeTime + dt

        if not self.true_death then
            -- Update respawn timer
            self.respawn_timer = self.respawn_timer - dt
            if self.respawn_timer <= 0 then
                self:respawn()
            end
        end

        return
    end

    -- Update meteor mode (independent of weapon)
    if self.meteor_mode then
        self.meteor_timer = self.meteor_timer - dt

        -- Spawn meteor circle particles at 20 Hz
        self.meteor_particle_timer = self.meteor_particle_timer - dt
        if self.meteor_particle_timer <= 0 then
            local particles_module = require("src/particles")
            particles_module.new_meteor_circle(self.x, self.y)
            self.meteor_particle_timer = 1 / 20  -- 20 Hz = 0.05 seconds
        end

        -- Play meteor sound every 0.23 seconds
        self.meteor_sound_timer = self.meteor_sound_timer - dt
        if self.meteor_sound_timer <= 0 then
            if sfx_meteor then
                sfx_meteor:stop()
                sfx_meteor:play()
            end
            self.meteor_sound_timer = 0.23
        end

        if self.meteor_timer <= 0 then
            -- Meteor mode ends naturally
            self.meteor_mode = false
            self.hasShield = false
            self.shield_red_on_dissipate = true  -- Shield dissipates as red
            self.iTime = math.max(self.iTime, 1.0) 
        end
    end

    -- Update weapon (but not during meteor mode - player cannot shoot)
    if not self.meteor_mode then
        local weapon = WeaponTypes[self.weapon]
        if weapon and weapon.update then
            weapon:update(self, dt)
        end
    end

    -- Determine speed and acceleration (tripled speed, reduced accel during meteor mode)
    local speed = STANDARD_SPEED
    local accel_x = ACCEL_X
    local accel_y = ACCEL_Y

    if self.meteor_mode then
        speed = STANDARD_SPEED * 3
        accel_x = 5
        accel_y = 5
        self.r = 14  -- Increased radius during meteor mode
    else
        self.r = 5  -- Normal radius
    end

    -- Freeze velocity and position during hit stun
    if self.hitStun <= 0 then
        -- Move velocity toward target velocity using acceleration
        local target_vx = speed * self.input_x
        local target_vy = speed * self.input_y

        self.vx = toward(self.vx, target_vx, dt * accel_x)
        self.vy = toward(self.vy, target_vy, dt * accel_y)

        -- Update position
        self.x = self.x + self.vx
        self.y = self.y + self.vy

        -- Game region dimensions (scaled by pixel scale)
        local game_width = GAME_WIDTH / PIXEL_SCALE
        local game_height = GAME_HEIGHT / PIXEL_SCALE

        -- Clamp to game region and bounce if outside
        if self.x < 0 then
            self.x = 0
            self.vx = self.vx * -0.5
        elseif self.x > game_width then
            self.x = game_width
            self.vx = self.vx * -0.5
        end

        if self.y < 0 then
            self.y = 0
            self.vy = self.vy * -0.5
        elseif self.y > game_height then
            self.y = game_height
            self.vy = self.vy * -0.5
        end
    end

    -- Store firing state for next frame (for press detection)
    self.firing_previous = self.firing
end

-- Handle input for all players
function players.input()
    for i, player in ipairs(players.list) do
        -- For now, first player uses keyboard, others would use gamepad
        local input_src = (i == 1) and 'keyboard' or i - 1
        player:input(input_src)
    end
end

-- Update all players
function players.update(dt)
    for _, player in ipairs(players.list) do
        player:update(dt)
    end
end

-- Get shield rendering attributes (radius, alpha)
function Player:get_shield_attributes()
    -- shieldAnim: 0 = shield present, 1 = shield absent
    -- Radius grows from 16 (shieldAnim=0) to 32 (shieldAnim=1)
    local radius = SHIELD_RADIUS + (32 - SHIELD_RADIUS) * self.shieldAnim
    -- Alpha fades from 1 (shieldAnim=0) to 0 (shieldAnim=1)
    local alpha = 1 - self.shieldAnim
    return radius, alpha
end

-- Determine shield color and visibility
-- Returns: use_red (boolean), draw_shield (boolean), use_white_flash (boolean)
function Player:get_shield_color()
    -- During meteor mode with flickering at end
    if self.meteor_mode and self.meteor_timer <= 1.5 then
        -- Flicker visible/invisible at 7 Hz, but always red when visible
        local time = love.timer.getTime()
        local flicker_period = 1 / 7
        local flicker_on = (math.floor(time / flicker_period) % 2) == 0
        if not flicker_on then
            return false, false, false  -- Invisible
        else
            return true, true, false  -- Red and visible
        end
    end

    -- During meteor mode (not flickering yet)
    if self.meteor_mode then
        -- White flash for 0.1 seconds out of every 0.25 seconds
        local time = love.timer.getTime()
        local cycle_time = time % 0.25
        local use_white_flash = cycle_time < 0.1
        return true, true, use_white_flash  -- Pure red, with white flash
    end

    -- Shield dissipating after meteor mode
    if self.shield_red_on_dissipate and not self.hasShield then
        return true, true, false  -- Red while dissipating
    end

    -- Check if weapon has custom shield color logic
    local weapon = WeaponTypes[self.weapon]
    if weapon and weapon.isShieldRed then
        local is_red = weapon:isShieldRed(self)
        return is_red, true, false
    end

    -- Default: blue shield
    return false, true, false
end

-- Render a single player
function Player:render()
    -- If not alive, draw explosion effect
    if not self.alive then
        love.graphics.setColor(1, 1, 1)

        -- Calculate distance and radius for explosion circles
        local distance = self.explodeTime * EXPLOSION_SPEED
        local radius = EXPLOSION_RADIUS_BASE + EXPLOSION_RADIUS_AMPLITUDE * math.sin(2 * math.pi * self.explodeTime)

        -- Draw circles evenly spaced around a circle
        for i = 0, EXPLOSION_CIRCLE_COUNT - 1 do
            local angle = i * 2 * math.pi / EXPLOSION_CIRCLE_COUNT
            local circle_x = self.x + distance * math.cos(angle)
            local circle_y = self.y + distance * math.sin(angle)
            love.graphics.circle("fill", circle_x, circle_y, radius)
        end

        return
    end

    if not player_quads or not player_image then
        return
    end

    -- Select frame based on input_x
    local frame_index
    if self.input_x == 0 then
        frame_index = 1
    elseif self.input_x < 0 then
        frame_index = 3
    else
        frame_index = 2
    end

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = player_quads[frame_index]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Flicker during invincibility time or meteor mode (every 4 frames)
    local should_draw = true
    if self.iTime > 0 or self.meteor_mode then
        local frame_count = math.floor(love.timer.getTime() * 60)  -- Assuming 60 FPS
        if (frame_count % 4) < 2 then
            should_draw = false
        end
    end

    -- Draw the player sprite centered on x, y
    if should_draw then
        love.graphics.draw(player_image, player_quads[frame_index], self.x - offset_x, self.y - offset_y)
    end

    -- Draw shield if animation value indicates any visibility
    if self.shieldAnim < 1 then
        local use_red_shield, draw_shield, use_white_flash = self:get_shield_color()

        if draw_shield then
            local current_shield_image = use_red_shield and shield_red_image or shield_image

            if current_shield_image then
                local shield_radius, shield_alpha = self:get_shield_attributes()

                -- Calculate scale based on radius (shield image size to fit the radius)
                local shield_w = current_shield_image:getWidth()
                local shield_h = current_shield_image:getHeight()
                local scale = (shield_radius * 2) / shield_w

                -- Apply white flash shader if needed
                if use_white_flash and flash_shader then
                    love.graphics.setShader(flash_shader)
                    flash_shader:send("flashing", true)
                end

                -- Apply alpha for transparency
                love.graphics.setColor(1, 1, 1, shield_alpha)

                -- Draw shield centered and scaled
                love.graphics.draw(
                    current_shield_image,
                    self.x,
                    self.y,
                    0,
                    scale,
                    scale,
                    shield_w / 2,
                    shield_h / 2
                )

                -- Reset shader and color
                love.graphics.setShader()
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end
end

-- Draw all players
function players.draw()
    for _, player in ipairs(players.list) do
        player:render()
    end
end

-- Draw weapon stack UI
function players.draw_ui()
    if not weapon_icon_quads or not weapon_icon_image then
        return
    end

    -- Position to the right of the game area
    local x_base = (MARGIN_L + GAME_WIDTH) / PIXEL_SCALE + 5
    local y_margin = MARGIN_T / PIXEL_SCALE + 5

    for _, player in ipairs(players.list) do
        -- Draw current weapon at top (position 0)
        local current_weapon = WeaponTypes[player.weapon]
        local current_sprite_index = current_weapon and current_weapon.sprite_index or 1
        local x = x_base
        local y = y_margin

        -- Calculate flicker state for current weapon (6 Hz)
        local time = love.timer.getTime()
        local flicker_period = 1 / 6  -- 6 Hz
        local flicker_on = (math.floor(time / flicker_period) % 2) == 0

        -- Flicker current weapon if player is dead
        local should_draw_current = true
        if not player.alive and not flicker_on then
            should_draw_current = false
        end

        if should_draw_current then
            -- Highlight current weapon with blue rectangle
            love.graphics.setColor(0.5, 0.5, 1, 0.5)
            love.graphics.rectangle("fill", x - 2, y - 2, 28, 20)
            love.graphics.setColor(1, 1, 1)

            -- Draw current weapon icon
            love.graphics.draw(weapon_icon_image, weapon_icon_quads[current_sprite_index], x, y)
        end

        -- Draw up to 4 weapons from the stack below current weapon
        local stack_size = #player.weapon_stack
        local weapons_to_show = math.min(stack_size, 4)

        for i = 1, weapons_to_show do
            local weapon_name = player.weapon_stack[stack_size - i + 1]  -- Show from top of stack
            local weapon = WeaponTypes[weapon_name]
            local sprite_index = weapon and weapon.sprite_index or 1

            local stack_x = x_base
            local stack_y = y_margin + i * 20

            love.graphics.draw(weapon_icon_image, weapon_icon_quads[sprite_index], stack_x, stack_y)
        end

        -- If more than 4 weapons in stack, show "+n"
        if stack_size > 4 then
            local extra_count = stack_size - 4
            local text_x = x_base
            local text_y = y_margin + 5 * 20
            love.graphics.print("+" .. extra_count, text_x, text_y)
        end
    end
end

return players
