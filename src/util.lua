function values(t)
    local i = 0
    return function()
        i = i + 1
        return t[i]
    end
end

function filter(tbl, predicate)
    local filtered = {}
    for key, value in pairs(tbl) do
        if predicate(value, key) then
            table.insert(filtered, value)
        end
    end
    return filtered
end

function nza(...) 
    local y = ({...})[1] or 0
    for x in values {...} do
        if not x then return false end
        y = bit.band(x, y)
    end
    return y ~= 0
end

function hex(number)
    return string.format("%x", number)
end

function shallowCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = value
    end
    return copy
end

function deepCopy(original)
    local function _deepCopy(original, copies)
        if type(original) ~= "table" then
            return original
        elseif copies[original] then
            return copies[original]
        end
        local copy = {}
        copies[original] = copy
        for key, value in pairs(original) do
            copy[_deepCopy(key, copies)] = _deepCopy(value, copies)
        end
        return setmetatable(copy, getmetatable(original))
    end
    return _deepCopy(original, {})
end

-- returns x but closer to target by rate
function toward(x, target, rate)
    if x == nil then return target end
    rate = rate or 1
    if target - x > rate then
        x = x + rate
    elseif x - target > rate then
        x = x - rate
    else
        x = target
    end
    return x 
end

-- bias: breaks tie (can be - or + or nil)
-- returns new value for x, diff applied
function modular_toward(x, target, modulus, rate, bias)
    x = x % modulus
    target = target % modulus
    
    local diff = target - x
    if diff < 0 then diff = diff + modulus end
    if bias and bias < 0 then
        if diff >= modulus / 2 then
            diff = diff - modulus
        end
    else
        if diff > modulus / 2 then
            diff = diff - modulus
        end
    end
    dx = toward(0, diff, rate)
    return (x + dx) % modulus, dx
end

-- 0: right; 1: down; 2: left; 3: up
function face_dxdy(face)
    face = face % 4
    if face == 0 then
        return 1, 0
    elseif face == 1 then
        return 0, 1
    elseif face == 2 then
        return -1, 0
    else
        return 0, -1
    end
end

function dxdy_face(dx, dy)
    if dx == 0 and dy == 0 then
        return 0
    elseif dx == 1 and dy == 0 then
        return 0
    elseif dy == 1 and dx == 0 then
        return 1
    elseif dx == -1 and dy == 0 then
        return 2
    elseif dx == 0 and dy == -1 then
        return 3
    end
    return math.atan2(dy, dx) / math.tau * 4
end

function splitStringIntoChunks(str, maxLength)
    local chunks = {}
    for i = 1, #str, maxLength do
        table.insert(chunks, str:sub(i, i + maxLength - 1))
    end
    return chunks
end

function fn(...) end

function clamp(x, a, b)
    return math.min(math.max(x, a), b)
end
math.clamp = clamp

function sample(t, r)
    local rand = r * #t
    return t[1 + math.floor(rand)]
end

function sample_weighted(t, r)
    -- Calculate the sum of all weights
    local weightSum = 0
    local y = nil;
    for x, weight in pairs(t) do
        y = x
        weightSum = weightSum + weight
    end

    -- Generate a random number in the range [0, weightSum)
    local rand = r * weightSum

    -- Iterate through the table to find the weighted random choice
    for index, weight in pairs(t) do
        rand = rand - weight
        if rand <= 0 then
            return index
        end
    end
    
    return y
end

-- rng_fn(a, b) must generate a random number in the range [a,b]
function shuffle(tbl, rng_fn)
    for i = #tbl, 2, -1 do
        local j = rng_fn(1, i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

function iota(n)
    local result = {}
    for i = 1, n do
        table.insert(result, i)
    end
    return result
end

function empty(table)
    for i, v in pairs(table) do
        return false
    end
    return true
end

function tableSize(table)
    local size = 0
    for i, v in pairs(table) do
        size = size + 1
    end
    return size
end

function ease_in(x)
    return x * x
end

function ease_out(x)
    return 1 - ease_in(1 - x)
end

function ease_cos(x)
    return 1 - (0.5 + math.cos(x * math.pi)/2)
end

-- natural modulo
-- output in range [1, k]
function nmod(x, k)
    x = x % k
    if x <= 0 then
        x = x + k
    end
    return x
end

function setDefaults(defaults, tbl)
    for k, v in pairs(defaults) do
        if tbl[k] == nil then
            tbl[k] = v
        end
    end
    return tbl
end  

on = {}
local methods = {}
setmetatable(on, {
  __newindex = function(_, key, func)
    if not methods[key] then
        methods[key] = {}
    end
    table.insert(methods[key], func)
  end,
  __index = function(_, key)
    return function(...)
        if methods[key] then
            for _, func in ipairs(methods[key]) do
                func(...)
            end
        end
    end
  end
})

function getSystemLocale()
    local locale = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LC_CTYPE") or "C"
    return locale
end

function getSystemLanguage(locale)
    locale = locale or getSystemLocale()
    local language = string.match(locale, "^(%a%a%a?)_?")
    return language
end

function contains(a, b)
    for key, e in pairs(a) do
        if e == b then
            return true
        end
    end
    return false
end

function sum(t)
    local s = 0
    for i, v in pairs(t) do
        s = s + v
    end
    return s
end

function keys(t)
    local k = {}
    for i, v in pairs(t) do
        table.insert(k, i)
    end
    return k
end

function rotateList(list, n)
    local length = #list
    if length == 0 then return end
    local rotateBy = n % length
    if rotateBy == 0 then return end

    if rotateBy < 0 then
        rotateBy = length + rotateBy
    end

    for i = 1, rotateBy do
        table.insert(list, 1, table.remove(list))
    end
end