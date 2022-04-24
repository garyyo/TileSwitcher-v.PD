import "lib/gfxp"
local gfxp <const> = GFXP

local max_scores <const> = {26, 27, 27, 27, 27, 27, 28, 28, 28, 28, 27, 29, 27, 28, 29, 27, 28, 27, 30, 29, 29, 30, 30, 29, 29, 30, 29, 29, 28, 30, 29, 29, 34, 34, 34, 33, 33, 33, 33, 32, 32, 33, 32, 33, 32, 32, 34, 34, 33, 33, 33, 33, 32, 33, 32, 32, 32}
local color_counts <const>  = {{3, 3, 3, 3, 3}, {4, 3, 3, 3, 2}, {4, 4, 3, 2, 2}, {4, 4, 3, 3, 1}, {4, 4, 4, 2, 1}, {4, 4, 4, 3, 0}, {5, 3, 3, 2, 2}, {5, 3, 3, 3, 1}, {5, 4, 2, 2, 2}, {5, 4, 3, 2, 1}, {5, 4, 3, 3, 0}, {5, 4, 4, 1, 1}, {5, 4, 4, 2, 0}, {5, 5, 2, 2, 1}, {5, 5, 3, 1, 1}, {5, 5, 3, 2, 0}, {5, 5, 4, 1, 0}, {5, 5, 5, 0, 0}, {6, 3, 2, 2, 2}, {6, 3, 3, 2, 1}, {6, 3, 3, 3, 0}, {6, 4, 2, 2, 1}, {6, 4, 3, 1, 1}, {6, 4, 3, 2, 0}, {6, 4, 4, 1, 0}, {6, 5, 2, 1, 1}, {6, 5, 2, 2, 0}, {6, 5, 3, 1, 0}, {6, 5, 4, 0, 0}, {6, 6, 1, 1, 1}, {6, 6, 2, 1, 0}, {6, 6, 3, 0, 0}, {7, 2, 2, 2, 2}, {7, 3, 2, 2, 1}, {7, 3, 3, 1, 1}, {7, 3, 3, 2, 0}, {7, 4, 2, 1, 1}, {7, 4, 2, 2, 0}, {7, 4, 3, 1, 0}, {7, 4, 4, 0, 0}, {7, 5, 1, 1, 1}, {7, 5, 2, 1, 0}, {7, 5, 3, 0, 0}, {7, 6, 1, 1, 0}, {7, 6, 2, 0, 0}, {7, 7, 1, 0, 0}, {8, 2, 2, 2, 1}, {8, 3, 2, 1, 1}, {8, 3, 2, 2, 0}, {8, 3, 3, 1, 0}, {8, 4, 1, 1, 1}, {8, 4, 2, 1, 0}, {8, 4, 3, 0, 0}, {8, 5, 1, 1, 0}, {8, 5, 2, 0, 0}, {8, 6, 1, 0, 0}, {8, 7, 0, 0, 0}}

-- helpers
local function Shuffle(t)
    local s = {}
    for i = 1, #t do s[i] = t[i] end
    for i = #t, 2, -1 do
        local j = math.random(i)
        s[i], s[j] = s[j], s[i]
    end
    return s
end

local function permute(tab, n, count)
    math.randomseed(playdate.getSecondsSinceEpoch())
    n = n or #tab
    for i = 1, count or n do
        local j = math.random(i, n)
        tab[i], tab[j] = tab[j], tab[i]
    end
    return tab
end
local function get_keys(key_table)
    local keyset = {}
    local n = 0

    for k, v in pairs(key_table) do
        n = n + 1
        keyset[n] = k
    end
    return keyset
end

-- a list of colors
local color_palettes <const> = {
    Classic = {"white", "lightgray-1", "gray", "darkgray", "black"},
    Cross = {"white", "cross-1", "cross-5", "cross-1i", "black"},
    Lines = {"vline-1", "vline-2", "vline-3", "vline-2i", "vline-1i"},
    Rand = {"white", "lightgray", "gray", "darkgray", "black"}
}
function get_palette(palette_name)
    local palette = color_palettes[palette_name]
    if palette_name == "Rand" then
        -- build the list of possible patterns
        local keyset = get_keys(gfxp.lib)

        -- pick 3 random patterns to serve as a palette
        keyset = permute(keyset, 5)
        palette[1] = keyset[1]
        palette[2] = keyset[2]
        palette[3] = keyset[3]
        palette[4] = keyset[4]
        palette[5] = keyset[5]
    end
    return palette
end
function get_palette_names()
    local keys = get_keys(color_palettes)
    table.sort(keys)
    return keys
end

-- the good stuff
function get_level()
    -- choose a "random" layout, which is just randomly chosen from a list of layouts that fit some criteria of not being too hard or easy
    local random_level = math.random(#color_counts)
    
    -- take the color_counts and turn them into a color table (which a 5x5 table, but its flattened into a 25x1 cuz easier)
    color_layout = {}
    for i, v in ipairs(color_counts[random_level]) do
        for j=1, v+2, 1 do
            color_layout[#color_layout+1] = i
        end
    end
    print(#color_layout)
    -- assert(#color_layout == 25, "the color layout has to be 25 long")
    -- shuffle for max fun
    color_layout = Shuffle(color_layout)

    return color_layout, max_scores[random_level]
end