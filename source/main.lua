import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "BoxGrid"
import "color_distributions"

-- local references
local pd <const> = playdate
local gfx <const> = pd.graphics
local timer <const> = pd.timer

-- game stuff
local box_grid = nil

local function initGame()
	-- make a new grid
	box_grid = BoxGrid(10, 10)

    -- add the three menu items
    local menu = pd.getSystemMenu()
    -- 1. starting a game
    menu:addMenuItem("New Game", function()
        box_grid:new_level()
    end)
    -- 2. Color Palettes
    local palette_names = get_palette_names()
    menu:addOptionsMenuItem("Palettes", palette_names, function(palette_name)
        box_grid:set_palette(palette_name)
    end)
    -- 3. back to instructions
    menu:addMenuItem("Instructions", function()
        if not box_grid.game_started then
            return
        end
        box_grid.disable_updates = not box_grid.disable_updates
    end)

end

initGame()

function playdate.update()
	gfx.sprite.update()
    box_grid:update()
    timer.updateTimers()
end