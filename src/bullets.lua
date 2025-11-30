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
function bullets.new(x, y, vx, vy, type, owner, distance_to_live, damage)
    local bullet = {
        x = x or 0,
        y = y or 0,
        vx = vx or 0,
        vy = vy or 0,
        r = 2,  -- Collision radius
        alive = true,
        type = type or "standard",
        owner = owner,  -- nil or reference to player who fired it
        distance_to_live = distance_to_live,  -- Maximum distance bullet can travel (nil = infinite)
        distance_traveled = 0,  -- Track how far bullet has traveled
        damage = damage or 1  -- Damage dealt by this bullet (default 1)
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

-- Radiator bullet render function
function bullet_render_radiator(b)
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

-- Flamer bullet update function (tracks distance traveled)
function bullet_update_flamer(b, dt)
    -- Calculate distance moved this frame
    local dx = b.vx
    local dy = b.vy
    local distance_this_frame = math.sqrt(dx * dx + dy * dy)

    -- Move bullet
    b.x = b.x + b.vx
    b.y = b.y + b.vy

    -- Track distance traveled
    b.distance_traveled = b.distance_traveled + distance_this_frame

    -- Check if bullet exceeded its distance to live
    if b.distance_to_live and b.distance_traveled >= b.distance_to_live then
        b.alive = false
        return
    end

    -- Game region dimensions (scaled by pixel scale)
    local game_width = GAME_WIDTH / PIXEL_SCALE
    local game_height = GAME_HEIGHT / PIXEL_SCALE

    -- Check if bullet left the game region
    if b.x < 0 or b.x > game_width or b.y < 0 or b.y > game_height then
        b.alive = false
    end
end

-- Flamer bullet render function
function bullet_render_flamer(b)
    if not bullet_quads or not bullet_image then
        return
    end

    -- Get sprite dimensions to center it (using sprite 3, same as radiator)
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
    radiator = {
        update = bullet_update_standard,
        render = bullet_render_radiator
    },
    flamer = {
        update = bullet_update_flamer,
        render = bullet_render_flamer
    }
}

return bullets
