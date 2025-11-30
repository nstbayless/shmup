local music = {}

-- Music state
music.enabled = true  -- Defaults to on
local intro_music = nil
local main_music = nil
local current_source = nil
local playing_intro = false

-- Load music assets
function music.load()
    intro_music = love.audio.newSource("assets/BossIntro.ogg", "static")
    main_music = love.audio.newSource("assets/BossMain.ogg", "static")
    main_music:setLooping(true)
end

-- Initialize/restart music
function music.init()
    music.stop()
    if music.enabled then
        music.play_intro()
    end
end

-- Play intro music
function music.play_intro()
    if not music.enabled or not intro_music then
        return
    end

    music.stop()
    intro_music:play()
    current_source = intro_music
    playing_intro = true
end

-- Play main music loop
function music.play_main()
    if not music.enabled or not main_music then
        return
    end

    music.stop()
    main_music:play()
    current_source = main_music
    playing_intro = false
end

-- Stop all music
function music.stop()
    if intro_music then
        intro_music:stop()
    end
    if main_music then
        main_music:stop()
    end
    current_source = nil
    playing_intro = false
end

-- Toggle music on/off
function music.toggle()
    music.enabled = not music.enabled

    if music.enabled then
        -- Music was turned on, start from intro
        music.play_intro()
    else
        -- Music was turned off, stop all
        music.stop()
    end
end

-- Update music (check if intro finished, switch to main loop)
function music.update()
    if not music.enabled then
        return
    end

    -- If playing intro and it finished, switch to main loop
    if playing_intro and intro_music and not intro_music:isPlaying() then
        music.play_main()
    end
end

-- Check if player has true death, stop music if so
function music.check_player_death(player)
    if player.true_death and not player.alive then
        music.stop()
    end
end

return music
