require "src/config"

math.tau = 2 * math.pi

function love.conf(t)
    t.window.width = WINDOW_W
    t.window.height = WINDOW_H
    t.identity = "shmup"
    t.version = "11.4"
    t.vsync = 0
    t.console = true
    t.window.title = "Shmup"
    --t.window.icon = "assets/shmup/icon.png"
end

print(_VERSION)
