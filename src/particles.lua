local spritesheet = require "src/spritesheet"

local particles = {}

-- List of all particles
particles.list = {}

-- Particle spritesheets
local explosion_quads, explosion_image

-- Initialize particles module state
function particles.init()
    particles.list = {}
end

-- Load particle assets
function particles.load()
    explosion_quads, explosion_image = spritesheet.load("assets/explosion-16-16.png")
end

-- Create a new particle
function particles.new(x, y, type, text)
    local particle = {
        x = x or 0,
        y = y or 0,
        type = type or "explosion",
        animTime = 0,
        alive = true,
        text = text or ""  -- For text particles
    }
    table.insert(particles.list, particle)
    return particle
end

-- Create a meteor circle particle with random velocity and radius
function particles.new_meteor_circle(x, y)
    -- Random speed between 50-80 px/s
    local speed = 50 + math.random() * 30

    -- Random direction (angle in radians)
    local angle = math.random() * 2 * math.pi

    -- Calculate velocity components
    local vx = speed * math.cos(angle)
    local vy = speed * math.sin(angle)

    -- Random initial radius between 8-16
    local radius = 8 + math.random() * 8

    local particle = {
        x = x,
        y = y,
        type = "meteor_circle",
        vx = vx,
        vy = vy,
        radius = radius,
        alive = true
    }

    table.insert(particles.list, particle)
    return particle
end

-- Remove dead particles from the list
function particles.garbage()
    for i = #particles.list, 1, -1 do
        if not particles.list[i].alive then
            table.remove(particles.list, i)
        end
    end
end

-- Update all particles
function particles.update(dt)
    for _, particle in ipairs(particles.list) do
        local particle_type = ParticleTypes[particle.type]
        if particle_type and particle_type.update then
            particle_type.update(particle, dt)
        end
    end
end

-- Render all particles
function particles.render()
    for _, particle in ipairs(particles.list) do
        local particle_type = ParticleTypes[particle.type]
        if particle_type and particle_type.render then
            particle_type.render(particle)
        end
    end
end

-- Explosion particle update
function particle_update_explosion(p, dt)
    p.animTime = p.animTime + dt

    -- Animation plays at 6 Hz (6 frames per second)
    local frame_duration = 1 / 6
    local total_frames = #explosion_quads
    local total_duration = total_frames * frame_duration

    -- Remove particle when animation completes
    if p.animTime >= total_duration then
        p.alive = false
    end
end

-- Explosion particle render
function particle_render_explosion(p)
    if not explosion_quads or not explosion_image then
        return
    end

    -- Calculate current frame (1-indexed)
    local frame_duration = 1 / 6
    local frame_index = math.floor(p.animTime / frame_duration) + 1
    frame_index = math.min(frame_index, #explosion_quads)

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = explosion_quads[frame_index]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Draw the explosion sprite centered on x, y
    love.graphics.draw(explosion_image, explosion_quads[frame_index], p.x - offset_x, p.y - offset_y)
end

-- Text particle update (moves upward for 1 second then disappears)
function particle_update_text(p, dt)
    p.animTime = p.animTime + dt

    -- Move upward
    p.y = p.y - dt * 20  -- Move up 20 pixels per second

    -- Remove particle after 1 second
    if p.animTime >= 1 then
        p.alive = false
    end
end

-- Text particle render (flickers at 6 Hz)
function particle_render_text(p)
    -- Calculate flicker state (6 Hz)
    local flicker_period = 1 / 32
    local flicker_on = (math.floor(p.animTime / flicker_period) % 2) == 0

    if flicker_on then
        love.graphics.setColor(1, 1, 1)
        -- Get text width to center it
        local text_width = love.graphics.getFont():getWidth(p.text)
        love.graphics.print(p.text, p.x - text_width / 2, p.y)
    end
end

-- Respawn text particle update (moves upward for 1 second then disappears)
function particle_update_respawn_text(p, dt)
    p.animTime = p.animTime + dt

    -- Move upward
    p.y = p.y - dt * 20  -- Move up 20 pixels per second

    -- Remove particle after 1 second
    if p.animTime >= 1 then
        p.alive = false
    end
end

-- Respawn text particle render (shows "Revert to" above weapon name, light red, flickers)
function particle_render_respawn_text(p)
    -- Calculate flicker state (32 Hz)
    local flicker_period = 1 / 32
    local flicker_on = (math.floor(p.animTime / flicker_period) % 2) == 0

    if flicker_on then
        -- Light red color
        love.graphics.setColor(1, 0.5, 0.5)

        local font = love.graphics.getFont()

        -- Draw "Revert to" text (smaller, above)
        local revert_text = "Revert to"
        local revert_width = font:getWidth(revert_text)
        love.graphics.print(revert_text, p.x - revert_width / 2, p.y - 10)

        -- Draw weapon name (larger font size, below)
        local weapon_width = font:getWidth(p.text)
        love.graphics.print(p.text, p.x - weapon_width / 2, p.y)

        -- Reset color
        love.graphics.setColor(1, 1, 1)
    end
end

-- Meteor circle particle update
function particle_update_meteor_circle(p, dt)
    -- Move according to velocity
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt

    -- Decrease radius at 16 px/s
    p.radius = p.radius - 16 * dt

    -- Die when radius reaches 0
    if p.radius <= 0 then
        p.alive = false
    end
end

-- Meteor circle particle render
function particle_render_meteor_circle(p)
    -- Medium red color (0.7, 0, 0)
    love.graphics.setColor(0.7, 0, 0)
    love.graphics.circle("fill", p.x, p.y, p.radius)
    love.graphics.setColor(1, 1, 1)
end

-- Global particle type definitions
ParticleTypes = {
    explosion = {
        update = particle_update_explosion,
        render = particle_render_explosion
    },
    text = {
        update = particle_update_text,
        render = particle_render_text
    },
    respawn_text = {
        update = particle_update_respawn_text,
        render = particle_render_respawn_text
    },
    meteor_circle = {
        update = particle_update_meteor_circle,
        render = particle_render_meteor_circle
    }
}

return particles
