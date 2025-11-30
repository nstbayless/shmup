local enemies = require "src/enemies"

local waves = {}

-- Current wave state
waves.currentWave = nil
waves.waveNumber = 0

-- Create a new wave
function waves.new(config)
    local enemyCount = config.enemySpawnCount or 5
    local wave = {
        type = config.type or "standard",
        maxTime = config.maxTime or 15,
        currentTime = 0,
        enemySpawnInterval = config.enemySpawnInterval or 0.3,
        enemySpawnCount = enemyCount,
        enemySpawnTimer = 0,
        enemiesSpawned = 0,
        breather = config.breather or false,
        spawningComplete = (enemyCount == 0)  -- If no enemies to spawn, mark as complete
    }
    return wave
end

-- Initialize waves module state
function waves.init()
    waves.currentWave = nil
    waves.waveNumber = 0
end

-- Start a wave
function waves.start(config)
    waves.currentWave = waves.new(config)
    waves.waveNumber = waves.waveNumber + 1
    -- Update enemies module's current wave tracker
    enemies.currentWave = waves.waveNumber
end

-- Update the current wave
-- Returns remaining time if wave completed, nil otherwise
function waves.update(dt)
    if not waves.currentWave then
        return nil
    end

    local wave = waves.currentWave

    -- Spawn enemies if not complete
    if not wave.spawningComplete then
        wave.enemySpawnTimer = wave.enemySpawnTimer + dt

        if wave.enemySpawnTimer >= wave.enemySpawnInterval and wave.enemiesSpawned < wave.enemySpawnCount then
            -- Spawn enemy based on wave type
            if wave.type == "positioner" then
                enemies.new(0, 0, "positioner")
            elseif wave.type == "snake" then
                enemies.spawnSnake()
            end

            wave.enemiesSpawned = wave.enemiesSpawned + 1
            wave.enemySpawnTimer = 0

            if wave.enemiesSpawned >= wave.enemySpawnCount then
                wave.spawningComplete = true
            end
        end
    end

    -- Count time after spawning complete
    if wave.spawningComplete then
        wave.currentTime = wave.currentTime + dt
    end

    -- Check if wave is complete
    local waveComplete = false

    if wave.breather then
        -- Breather waves only end on timer
        if wave.currentTime >= wave.maxTime then
            waveComplete = true
        end
    else
        -- Normal waves end on timer OR all enemies defeated
        local allEnemiesDefeated = #enemies.list == 0
        if wave.currentTime >= wave.maxTime or (wave.spawningComplete and allEnemiesDefeated) then
            waveComplete = true
        end
    end

    -- Return remaining time if wave completed
    if waveComplete then
        local remainingTime = wave.maxTime - wave.currentTime
        waves.currentWave = nil
        return remainingTime
    end

    return nil
end

-- Get next wave configuration
function waves.getNextWave()
    local nextWaveNum = waves.waveNumber + 1

    if nextWaveNum == 1 then
        -- First wave: breather
        return {
            type = "breather",
            maxTime = 2,
            enemySpawnCount = 0,
            breather = true
        }
    elseif nextWaveNum == 2 then
        -- Second wave: 5 positioners
        local count = 5
        local spawnTime = 3 + math.random() * 2  -- 3-5 seconds
        local interval = spawnTime / count

        return {
            type = "positioner",
            maxTime = 15,
            enemySpawnCount = count,
            enemySpawnInterval = interval
        }
    else
        -- Subsequent waves: 30% chance of snakes, otherwise positioners
        if math.random() < 0.3 then
            -- Snake wave
            local count = math.ceil(nextWaveNum / 3)
            local spawnTime = 3  -- 3 seconds to spawn all snakes
            local interval = spawnTime / count

            return {
                type = "snake",
                maxTime = 5,  -- 3 seconds spawning + 2 seconds wave time
                enemySpawnCount = count,
                enemySpawnInterval = interval
            }
        else
            -- Positioner wave
            local count = 4 + nextWaveNum
            local spawnTime = 3 + math.random() * 2  -- 3-5 seconds
            local interval = spawnTime / count

            return {
                type = "positioner",
                maxTime = 15,
                enemySpawnCount = count,
                enemySpawnInterval = interval
            }
        end
    end
end

return waves
