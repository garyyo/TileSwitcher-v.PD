import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/animator"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "lib/gfxp"

-- library short names
local pd <const> = playdate
local gfx <const> = pd.graphics
local gfxp <const> = GFXP

-- my new class
class('DitherBox').extends(gfx.sprite)

function DitherBox:init(index_x, index_y, offset_x, offset_y)
    DitherBox.super.init(self)

    self.highlighted = false
    self.grabbed = false
    self.highlighted_size_increase = 8
    
    self.color = "gray"
    self.color_num = 1

    self.margin = 3
    self.stroke_width = 3
    self.box_radius = 2

    self.logical_width = 44
    self.width = self.logical_width + self.highlighted_size_increase * 2

    self.ix = index_x
    self.iy = index_y

    self.offset_x = offset_x
    self.offset_y = offset_y

    self:setSize(self.width, self.width)
    self:move_coord(index_x, index_y)
end

function DitherBox:indexed_coord(ix, iy)
    local padding = 1
    local x = (ix - 1) * (self.logical_width + padding) + (self.logical_width // 2) + self.offset_x
    local y = (iy - 1) * (self.logical_width + padding) + (self.logical_width // 2) + self.offset_y
    return x, y
end

function DitherBox:move_coord(ix, iy)
    local x, y = self:indexed_coord(ix, iy)
    self:moveTo(x, y)
    
end

function DitherBox:update_coord(ix, iy)
    local x, y = self:indexed_coord(ix, iy)
    
    local move_animator = gfx.animator.new(100, pd.geometry.lineSegment.new(self.x, self.y, x, y))
    self:setAnimator(move_animator)
end

function DitherBox:set_color(color, color_num)
    self.color_num = color_num
    self.color = color
    self:markDirty()
end

function DitherBox:draw()
    local width = self.logical_width
    local x = self.highlighted_size_increase
    if self.grabbed then
        width = self.logical_width + self.highlighted_size_increase * 2
        x = 0
    elseif self.highlighted then
        width = self.logical_width + self.highlighted_size_increase
        x = self.highlighted_size_increase // 2
    end

    -- draw the black outline
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(x, x, width, width, 2)

    -- draw the white space inside
    gfx.setColor(gfx.kColorWhite)
    local stroke_x = self.stroke_width + x
    local stroke_width = width - 2 * self.stroke_width
    gfx.fillRoundRect(stroke_x, stroke_x, stroke_width, stroke_width, self.box_radius)

    -- draw the "color" of the box
    gfxp.set(self.color)
    local margin_x = self.margin + self.stroke_width + x
    local margin_width = width - 2 * (self.margin + self.stroke_width)
    gfx.fillRoundRect(margin_x, margin_x, self.width - (2 * margin_x), self.height - (2 * margin_x), self.box_radius)
end