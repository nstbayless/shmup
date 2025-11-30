local spritesheet = require "src/spritesheet"
local weapons = require "src/weapons"

local players = {}

-- Module state
local player_quads, player_image
local shield_image
local weapon_icon_quads, weapon_icon_image

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
    player.firing_p = 0  -- Weapon-specific state (e.g., cooldown)
    player.respawn_timer = 0  -- Timer for respawning
    player.true_death = false  -- If true, player won't respawn

    table.insert(players.list, player)

    -- Initialize weapon
    player:equip_weapon("standard")

    return player
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
    weapon_icon_quads, weapon_icon_image = spritesheet.load("assets/contra-weapons-24-16.png")
end

-- Damage a player
function Player:damage()
    -- Ignore damage during invincibility time
    if self.iTime > 0 then
        return
    end

    if self.hasShield then
        -- Lose shield
        self.hasShield = false
        self.iTime = DAMAGE_ITIME
        self.shieldRestore = 0
    else
        -- Die
        self.alive = false
        self.explodeTime = 0
        self.respawn_timer = 2  -- Respawn after 2 seconds
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
        self.iTime = 1  -- 1 second of invincibility
        self.vx = 0
        self.vy = 0
        -- Reset to starting position (halfway along width, 90% along height)
        local game_width = GAME_WIDTH / PIXEL_SCALE
        local game_height = GAME_HEIGHT / PIXEL_SCALE
        self.x = game_width / 2
        self.y = game_height * 0.9
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

    -- Try keyboard first
    local keyboard_input = false
    if love.keyboard.isDown('left') or love.keyboard.isDown('right') or
       love.keyboard.isDown('up') or love.keyboard.isDown('down') or
       love.keyboard.isDown('x') then
        keyboard_input = true
    end

    if keyboard_input then
        -- Poll arrow keys for input
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

        -- Check fire button (x key)
        self.firing = love.keyboard.isDown('x')
    else
        -- Try gamepad input
        local joysticks = love.joystick.getJoysticks()
        if #joysticks > 0 then
            local joystick = joysticks[1]  -- Use first joystick

            -- Get joystick axes for movement
            self.input_x = joystick:getAxis(1)  -- Left stick X axis
            self.input_y = joystick:getAxis(2)  -- Left stick Y axis

            -- Check fire button (A button, or button 1)
            self.firing = joystick:isDown(1)
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

    -- Update shield animation (moves toward 1 when no shield, toward 0 when shielded)
    local target_anim = self.hasShield and 0 or 1
    self.shieldAnim = toward(self.shieldAnim, target_anim, dt / SHIELD_LOSE_ANIM_TIME)

    -- Update shield restore
    if not self.hasShield then
        self.shieldRestore = self.shieldRestore + dt / SHIELD_RESTORE_TIME
        if self.shieldRestore >= 1 then
            self.shieldRestore = 0
            self.hasShield = true
        end
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

    -- Update weapon
    local weapon = WeaponTypes[self.weapon]
    if weapon and weapon.update then
        weapon:update(self, dt)
    end

    -- Move velocity toward target velocity using acceleration
    local target_vx = STANDARD_SPEED * self.input_x
    local target_vy = STANDARD_SPEED * self.input_y

    self.vx = toward(self.vx, target_vx, dt * ACCEL_X)
    self.vy = toward(self.vy, target_vy, dt * ACCEL_Y)

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

    -- Flicker during invincibility time (every 4 frames)
    local should_draw = true
    if self.iTime > 0 then
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
    if self.shieldAnim < 1 and shield_image then
        local shield_radius, shield_alpha = self:get_shield_attributes()

        -- Calculate scale based on radius (shield image size to fit the radius)
        local shield_w = shield_image:getWidth()
        local shield_h = shield_image:getHeight()
        local scale = (shield_radius * 2) / shield_w

        -- Apply alpha for transparency
        love.graphics.setColor(1, 1, 1, shield_alpha)

        -- Draw shield centered and scaled
        love.graphics.draw(
            shield_image,
            self.x,
            self.y,
            0,
            scale,
            scale,
            shield_w / 2,
            shield_h / 2
        )

        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
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
