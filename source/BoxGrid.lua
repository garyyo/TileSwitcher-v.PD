import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "DitherBox"
import "lib/gfxp"
import "color_distributions"

-- library short names
local pd <const> = playdate
local gfx <const> = pd.graphics
local gfxp <const> = GFXP
local timer <const> = pd.timer

class("BoxGrid").extends()

function BoxGrid:init(offset_x, offset_y)
    self.width = 5
    self.height = 5
    self.offset_x = offset_x
    self.offset_y = offset_y

    -- small state tracking
    self.is_done = true
    self.disable_updates = true
    self.game_started = false

    -- selecting and highlighting tracking
    self.grabbed_box = {-1,-1}
    self.is_grabbed = false
    self.highlighted_box = {1,1}

    -- persistent stats
    self.score = 0
    self.breakdown_text = ""
    self.max_score = 0

    self.palette = get_palette("Classic")
    self.color_layout = nil

    -- create all the boxes
    self.boxes = table.create(self.height, 0)

    for y=1, self.height, 1 do
        self.boxes[y] = table.create(self.width, 0)
        for x=1, self.width, 1 do
            self.boxes[y][x] = DitherBox(x, y, self.offset_x, self.offset_y)
            self.boxes[y][x]:add()
        end
    end

    -- load all the sounds
    self.explode_sound = pd.sound.sampleplayer.new("sounds/explosion.wav")
    self.pick_up_sound = pd.sound.sampleplayer.new("sounds/pick_up.wav")
    self.put_down_sound = pd.sound.sampleplayer.new("sounds/put_down.wav")

    -- load the randomized move noises
    self.blips = table.create(4, 0)
    for i=1,4 do
        self.blips[i] = pd.sound.sampleplayer.new("sounds/blip" .. i .. ".wav")
    end
end

function BoxGrid:random_blip_sound()
    local blip = self.blips[math.random(1, #self.blips)]
    blip:play()
end

function BoxGrid:new_level()
    -- assign new colors to all the boxes
    local color_layout, max_score = get_level()
    self.color_layout = color_layout
    self.max_score = max_score
    for y=1, self.height, 1 do
        for x=1, self.width, 1 do
            local color_num = color_layout[x + (y-1) * 5]
            local color = self.palette[color_num]
            self:getBox(x, y):set_color(color, color_num)
            
        end
    end
    self.is_done = false

    -- mark the currently selected box as currently selected
    self:set_highlighted(3, 3)

    -- enable updates
    self.disable_updates = false
    self.game_started = true

    -- reset the score and update it
    self:score_grid()
    update_needed = true
    self:update()
end

function BoxGrid:set_palette(palette_name)
    self.palette = get_palette(palette_name)
    -- if the game is not yet started we dont try to set any colors
    if self.color_layout == nil then
        return
    end
    for y=1, self.height, 1 do
        for x=1, self.width, 1 do
            local box = self:getBox(x, y)
            local color_num = box.color_num
            local color = self.palette[color_num]
            box:set_color(color, color_num)
        end
    end
end

function BoxGrid:getBox(x, y)
    return self.boxes[y][x]
end

function BoxGrid:setBox(x, y, box)
    self.boxes[y][x] = box
    self.boxes[y][x]:update_coord(x, y)
end

function BoxGrid:find_match(score_entry, x, y, direction)
    old_score_entry = nil
    if (score_entry and self:getBox(x, y).color == score_entry.color) then
        score_entry.len += 1
    else
        -- if our score_entry is empty
        if next(score_entry) ~= nil then
            old_score_entry = score_entry
        end
        score_entry = {
            len = 1,
            pos = {x, y},
            color = self:getBox(x, y).color,
            direction = direction
        }
    end
    return score_entry, old_score_entry
end

function BoxGrid:score_grid()
    local matches = {}

    -- score the rows
    for y=1, self.height, 1 do
        local score_entry = {}

        for x=1, self.width, 1 do
            score_entry, old_score_entry = self:find_match(score_entry, x, y, "right")
            -- add the old score if we had to create a new one
            if old_score_entry ~= nil then
                matches[#matches + 1] = old_score_entry
            end
        end
        -- always add the last score entry
        matches[#matches + 1] = score_entry
    end

    -- score the cols
    for x=1, self.width, 1 do
        local score_entry = {}

        for y=1, self.height, 1 do
            score_entry, old_score_entry = self:find_match(score_entry, x, y, "down")
            -- add the old score if we had to create a new one
            if old_score_entry ~= nil then
                matches[#matches + 1] = old_score_entry
            end
        end
        matches[#matches + 1] = score_entry
    end

    -- filter out anything that is too small
    filtered_matches = {}
    for i, match in pairs(matches) do
        if match.len >= 3 then
            filtered_matches[#filtered_matches + 1] = match
        end
    end

    -- sum up all the scores
    score = 0
    for i, match in pairs(filtered_matches) do
        score += match.len
    end
    
    self.score = score
    self.breakdown_text = self:score_breakdown(filtered_matches)
end

function BoxGrid:score_breakdown(matches)
    local breakdown_text = ""
    for i, match in pairs(matches) do
        local text = "(" .. match.pos[1] .. "," ..  match.pos[2] .. ") " .. match.direction .. " for " .. match.len
        breakdown_text = breakdown_text .. "\n" .. text
    end
    return breakdown_text
end

-- dealing with selecting stuff

function BoxGrid:in_bounds(x, y)
    return not (x < 1 or x > self.width or y < 1 or y > self.height)
end

function BoxGrid:swap_boxes(x1, y1, x2, y2)
    -- grab ref
    local box1 = self:getBox(x1, y1)
    local box2 = self:getBox(x2, y2)
    -- swap their table order
    self:setBox(x1, y1, box2)
    self:setBox(x2, y2, box1)
end

function BoxGrid:change_highlighted(dx, dy)
    local x, y = table.unpack(self.highlighted_box)
    local new_x = ((x + dx - 1) % 5) + 1
    local new_y = ((y + dy - 1) % 5) + 1
    -- if we try to move while a box is highlighted
    if self.is_grabbed then
        if self:in_bounds(new_x, new_y) then
            -- swap the boxes
            self:swap_boxes(x, y, new_x, new_y)
            -- update what is considered grabbed
            self:grab_box(new_x, new_y)
        end
    end
    self:set_highlighted(new_x, new_y)
end

function BoxGrid:set_highlighted(x, y)
    self:highlight_box(x, y)
end

function BoxGrid:grab()
    self:grab_box(table.unpack(self.highlighted_box))
    self.is_grabbed = true
    self.pick_up_sound:play()
end

function BoxGrid:ungrab()
    self:grab_box(-1, -1)
    self.is_grabbed = false
    self.put_down_sound:play()
end

function BoxGrid:grab_box(x, y)
    -- switch the various properties out
    local old_x = self.grabbed_box[1]
    local old_y = self.grabbed_box[2]
    if not (old_x < 1 or old_x > self.width or old_y < 1 or old_y > self.height) then
        local old_box = self:getBox(old_x, old_y)
        old_box.grabbed = false
        old_box:setZIndex(0)
        old_box:markDirty()
    end

    -- bounds are set to -1 when we still want to ungrab, but not select something new
    if not (x < 1 or x > self.width or y < 1 or y > self.height) then
        self.grabbed_box = {x, y}
        local new_box = self:getBox(x, y)
        new_box.grabbed = true
        new_box:setZIndex(10)
        new_box:markDirty()
    end

end

function BoxGrid:highlight_box(x, y)
    if x < 1 or x > self.width or y < 1 or y > self.height then
        return
    end

    -- switch the various properties out
    local old_box = self.boxes[self.highlighted_box[2]][self.highlighted_box[1]]
    old_box.highlighted = false
    old_box:setZIndex(0)
    old_box:markDirty()

    self.highlighted_box = {x, y}
    local new_box = self.boxes[y][x]
    new_box.highlighted = true
    new_box:setZIndex(10)
    new_box:markDirty()
end

function BoxGrid:level_finished()
    self.is_done = true
    self.explode_sound:play()

    -- flash the screen a bit
    local flash_delay = 60
    local final_i = 4
    if pd.getReduceFlashing() then
        flash_delay = 150
        final_i = 2
    end
    
    for i=1,final_i do
        timer.performAfterDelay(flash_delay * i, function()
            pd.display.setInverted(not pd.display.getInverted())
        end)
    end
    timer.performAfterDelay(flash_delay * final_i+1, function()
        pd.display.setInverted(false)
    end)

    -- todo: figure out an easy way to do a screenshake effect
    -- playdate.display.setOffset(x, y)
end

-- everything needed for an update
local left_repeat_timer = nil
local right_repeat_timer = nil
local up_repeat_timer = nil
local down_repeat_timer = nil

local update_needed = true

function BoxGrid:handle_keys()
    -- key repeats for directional inputs
	if pd.buttonJustPressed(pd.kButtonLeft) and left_repeat_timer == nil then
        left_repeat_timer = timer.keyRepeatTimer(function()
            self:change_highlighted(-1, 0)
            self:random_blip_sound()
            update_needed = true
        end)
    end
    if pd.buttonJustReleased(pd.kButtonLeft) then
        if left_repeat_timer ~= nil then
            left_repeat_timer:remove()
            left_repeat_timer = nil
        end
    end
    
	if pd.buttonJustPressed(pd.kButtonRight) and right_repeat_timer == nil then
        right_repeat_timer = timer.keyRepeatTimer(function()
            self:change_highlighted(1, 0)
            self:random_blip_sound()
            update_needed = true
        end)
    end
    if pd.buttonJustReleased(pd.kButtonRight) then
        if right_repeat_timer ~= nil then
            right_repeat_timer:remove()
            right_repeat_timer = nil
        end
    end
    
	if pd.buttonJustPressed(pd.kButtonUp) and up_repeat_timer == nil then
        
        up_repeat_timer = timer.keyRepeatTimer(function()
            self:change_highlighted(0, -1)
            self:random_blip_sound()
            update_needed = true
        end)
    end
    if pd.buttonJustReleased(pd.kButtonUp) then
        if up_repeat_timer ~= nil then
            up_repeat_timer:remove()
            up_repeat_timer = nil
        end
    end
    
	if pd.buttonJustPressed(pd.kButtonDown) and down_repeat_timer == nil then
        down_repeat_timer = timer.keyRepeatTimer(function()
            self:change_highlighted(0, 1)
            self:random_blip_sound()
            update_needed = true
        end)
    end
    if pd.buttonJustReleased(pd.kButtonDown) then
        if down_repeat_timer ~= nil then
            down_repeat_timer:remove()
            down_repeat_timer = nil
        end
    end

    -- pick up and put down tile
	if pd.buttonJustPressed(pd.kButtonA) then
        if self.is_grabbed then
            self:ungrab()
        else
            self:grab()
        end
    end
	if pd.buttonJustPressed(pd.kButtonB) then
        self:ungrab()
    end

end

function BoxGrid:update()
    if self.disable_updates then
        -- write instructions on screen
        local instructions_text = "Match the colored tiles to form rows and columns of 3+\nUse Ⓐ to pickup tiles and ✛ to move \n\nPress Menu ⊙ to start."
        gfx.drawTextInRect(instructions_text, 240, 12, 150, 200)

        return
    end

    -- only do update checks once the player has stopped holding any directions
    if (left_repeat_timer == nil and right_repeat_timer == nil and up_repeat_timer == nil and down_repeat_timer == nil) and update_needed then
        -- draw the score
        self:score_grid()

        -- check if the game is done
        if self.score >= self.max_score then
            if not self.is_done then
                self:level_finished()
            end
        end
        update_needed = false
    end

    gfx.drawTextAligned("Score: " , 240, 12, kTextAlignment.left)
    gfx.drawTextAligned(self.score .. "/" .. self.max_score, 390, 12, kTextAlignment.right)
    gfx.drawTextInRect(self.breakdown_text, 240, 15, 150, 220, nil, nil, kTextAlignment.right)

    -- handle keys in a separate method as to not make this one too messy
    self:handle_keys()
end