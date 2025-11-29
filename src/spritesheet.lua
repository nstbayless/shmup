local spritesheet = {}

-- Load a spritesheet with filename pattern "name-n-m.png"
-- where n is the width of each sprite and m is the height of each sprite
-- Returns a list of quads, ordered left-to-right then top-to-bottom
function spritesheet.load(filename)
    -- Parse the filename to extract n (sprite width) and m (sprite height)
    local n_str, m_str = filename:match("%-(%d+)%-(%d+)%.png$")

    if not n_str or not m_str then
        error("Invalid spritesheet filename. Expected format: 'name-N-M.png', got: " .. filename)
    end

    local sprite_w = tonumber(n_str)
    local sprite_h = tonumber(m_str)

    if not sprite_w or not sprite_h or sprite_w <= 0 or sprite_h <= 0 then
        error("Invalid sprite dimensions: " .. sprite_w .. "x" .. sprite_h)
    end

    -- Load the image
    local image = love.graphics.newImage(filename)
    local img_width = image:getWidth()
    local img_height = image:getHeight()

    -- Calculate number of columns and rows
    local cols = math.floor(img_width / sprite_w)
    local rows = math.floor(img_height / sprite_h)

    -- Create quads for each sprite
    -- Order: left-to-right (horizontal), then top-to-bottom (vertical)
    local quads = {}

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local x = col * sprite_w
            local y = row * sprite_h

            local quad = love.graphics.newQuad(
                x, y,
                sprite_w, sprite_h,
                img_width, img_height
            )

            table.insert(quads, quad)
        end
    end

    return quads, image
end

return spritesheet
