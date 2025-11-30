local spritesheet = require "src/spritesheet"

local bullets = {}

-- List of all bullets
bullets.list = {}

-- Bullet spritesheet
local bullet_quads, bullet_image

-- Initialize bullets module state
function bullets.init()
    bullets.list = {}
end

-- Load bullet assets
function bullets.load()
    bullet_quads, bullet_image = spritesheet.load("assets/bullets-16-16.png")
end

-- Create a new bullet
function bullets.new(x, y, vx, vy, type, owner)
    local bullet = {
        x = x or 0,
        y = y or 0,
        vx = vx or 0,
        vy = vy or 0,
        r = 2,  -- Collision radius
        alive = true,
        type = type or "standard",
        owner = owner  -- nil or reference to player who fired it
    }
    table.insert(bullets.list, bullet)
    return bullet
end

-- Remove dead bullets from the list
function bullets.garbage()
    for i = #bullets.list, 1, -1 do
        if not bullets.list[i].alive then
            table.remove(bullets.list, i)
        end
    end
end

-- Update all bullets
function bullets.update(dt)
    for _, bullet in ipairs(bullets.list) do
        local bullet_type = BulletTypes[bullet.type]
        if bullet_type and bullet_type.update then
            bullet_type.update(bullet, dt)
        end
    end
end

-- Render all bullets
function bullets.render()
    for _, bullet in ipairs(bullets.list) do
        local bullet_type = BulletTypes[bullet.type]
        if bullet_type and bullet_type.render then
            bullet_type.render(bullet)
        end
    end
end

-- Standard bullet update function
function bullet_update_standard(b, dt)
    -- Move bullet
    b.x = b.x + b.vx
    b.y = b.y + b.vy

    -- Game region dimensions (scaled by pixel scale)
    local game_width = GAME_WIDTH / PIXEL_SCALE
    local game_height = GAME_HEIGHT / PIXEL_SCALE

    -- Check if bullet left the game region
    if b.x < 0 or b.x > game_width or b.y < 0 or b.y > game_height then
        b.alive = false
    end
end

-- Standard bullet render function (enemy bullets)
function bullet_render_standard(b)
    if not bullet_quads or not bullet_image then
        return
    end

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = bullet_quads[5]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Draw the bullet sprite centered on x, y
    love.graphics.draw(bullet_image, bullet_quads[5], b.x - offset_x, b.y - offset_y)
end

-- Player bullet render function
function bullet_render_player(b)
    if not bullet_quads or not bullet_image then
        return
    end

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = bullet_quads[1]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Draw the bullet sprite centered on x, y (sprite 1)
    love.graphics.draw(bullet_image, bullet_quads[1], b.x - offset_x, b.y - offset_y)
end

-- Radiater bullet render function
function bullet_render_radiater(b)
    if not bullet_quads or not bullet_image then
        return
    end

    -- Get sprite dimensions to center it
    local _, _, sprite_w, sprite_h = bullet_quads[3]:getViewport()
    local offset_x = sprite_w / 2
    local offset_y = sprite_h / 2

    -- Draw the bullet sprite centered on x, y (sprite 3)
    love.graphics.draw(bullet_image, bullet_quads[3], b.x - offset_x, b.y - offset_y)
end

-- Global bullet type definitions
BulletTypes = {
    standard = {
        update = bullet_update_standard,
        render = bullet_render_standard
    },
    player = {
        update = bullet_update_standard,
        render = bullet_render_player
    },
    radiater = {
        update = bullet_update_standard,
        render = bullet_render_radiater
    }
}

return bullets
