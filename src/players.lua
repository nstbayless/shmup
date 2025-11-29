local spritesheet = require "src/spritesheet"

local players = {}

-- Array to store all player instances
players.list = {}

-- Player spritesheet and shield image
local player_quads, player_image
local shield_image

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
    player.hasShield = true
    player.iTime = 0
    player.shieldRestore = 0
    player.alive = true
    player.explodeTime = 0
    player.shieldAnim = 0  -- 0 = shield present, 1 = shield absent
    player.input_x = 0  -- [-1, 1]
    player.input_y = 0  -- [-1, 1]

    table.insert(players.list, player)
    return player
end

-- Initialize players module (load spritesheet)
function players.load()
    player_quads, player_image = spritesheet.load("assets/player-16-16.png")
    shield_image = love.graphics.newImage("assets/shield_Edit.png")
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
    end
end

-- Ensure at least n players exist
function players.ensure_players(n)
    local current_count = #players.list
    for i = current_count + 1, n do
        -- Create new players at a default position
        players.new(50, 50)
    end
end

-- Handle input for a single player
function Player:input(input_src)
    if input_src == 'keyboard' then
        -- Poll arrow keys for input
        self.input_x = 0
        self.input_y = 0

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
    end
    -- TODO: Handle gamepad input
end

-- Update player physics
function Player:update(dt)
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

    -- If not alive, update explode time and don't update position
    if not self.alive then
        self.explodeTime = self.explodeTime + dt
        return
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
        frame_index = 2
    else
        frame_index = 3
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

return players
