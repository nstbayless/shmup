// Flash shader for enemy damage
uniform bool flashing;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(texture, texture_coords);

    // If flashing is true and pixel is not transparent, quadruple RGB values
    if (flashing && pixel.a > 0.0)
    {
        pixel.rgb = pixel.rgb * 4.0;
    }

    return pixel * color;
}
