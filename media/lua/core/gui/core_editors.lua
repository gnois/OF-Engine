--[[! File: lua/core/gui/core_widgets.lua

    About: Author
        q66 <quaker66@gmail.com>

    About: Copyright
        Copyright (c) 2013 OctaForge project

    About: License
        This file is licensed under MIT. See COPYING.txt for more information.

    About: Purpose
        Text editor and fields.
]]

local capi = require("capi")
local cs = require("core.engine.cubescript")
local math2 = require("core.lua.math")
local table2 = require("core.lua.table")
local signal = require("core.events.signal")
local ffi = require("ffi")

local clipboard_set_text, clipboard_get_text, clipboard_has_text, text_draw,
text_get_bounds, text_get_position, text_is_visible, input_is_modifier_pressed,
input_textinput, input_keyrepeat, input_get_key_name, hudmatrix_push,
hudmatrix_translate, hudmatrix_flush, hudmatrix_scale, hudmatrix_pop,
shader_hudnotexture_set, shader_hud_set, gle_color3ub, gle_defvertexf,
gle_begin, gle_end, gle_attrib2f, text_font_push, text_font_pop, text_font_set,
text_font_get_w, text_font_get_h in capi

local max   = math.max
local min   = math.min
local abs   = math.abs
local clamp = math2.clamp
local floor = math.floor
local emit  = signal.emit
local tostring = tostring

local M = require("core.gui.core")

-- consts
local gl, key = M.gl, M.key

-- input event management
local is_clicked, is_focused = M.is_clicked, M.is_focused
local set_focus = M.set_focus

-- widget types
local register_class = M.register_class

-- scissoring
local clip_push, clip_pop = M.clip_push, M.clip_pop

-- base widgets
local Widget = M.get_class("Widget")

-- setters
local gen_setter = M.gen_setter

-- text scale
local get_text_scale = M.get_text_scale

local mod = require("core.gui.constants").mod

local floor_to_fontw = function(n)
    local fw = text_font_get_w()
    return floor(n / fw) * fw
end

local floor_to_fonth = function(n)
    local fh = text_font_get_h()
    return floor(n / fh) * fh
end

local chunksize = 256
local ffi_new, ffi_cast, ffi_copy, ffi_string = ffi.new, ffi.cast, ffi.copy,
ffi.string

ffi.cdef [[
    void *memmove(void*, const void*, size_t);
    void *malloc(size_t nbytes);
    void free(void *ptr);
    typedef struct editline_t {
        char *text;
        int len, maxlen;
    } editline_t;
]]
local C = ffi.C

local editline_MT = {
    __new = function(self, x)
        return ffi_new(self):set(x or "")
    end,
    __tostring = function(self)
        return ffi_string(self.text, self.len)
    end,
    __gc = function(self)
        self:clear()
    end,
    __index = {
        empty = function(self) return self.len <= 0 end,
        clear = function(self)
            C.free(self.text)
            self.text = nil
            self.len, self.maxlen = 0, 0
        end,
        grow = function(self, total, nocopy)
            if total + 1 <= self.maxlen then return false end
            self.maxlen = (total + chunksize) - total % chunksize
            local newtext = ffi_cast("char*", C.malloc(self.maxlen))
            if not nocopy then
                ffi_copy(newtext, self.text, self.len + 1)
            end
            C.free(self.text)
            self.text = newtext
            return true
        end,
        set = function(self, str)
            self:grow(#str, true)
            ffi_copy(self.text, str)
            self.len = #str
            return self
        end,
        prepend = function(self, str)
            local slen = #str
            self:grow(self.len + slen)
            C.memmove(self.text + slen, self.text, self.len + 1)
            ffi_copy(self.text, str)
            self.len += slen
            return self
        end,
        append = function(self, str)
            self:grow(self.len + #str)
            ffi_copy(self.text + self.len, str)
            self.len += #str
            return self
        end,
        del = function(self, start, count)
            if not self.text then return self end
            if start < 0 then
                count, start = count + start, 0
            end
            if count <= 0 or start >= self.len then return self end
            if start + count > self.len then count = self.len - start - 1 end
            C.memmove(self.text + start, self.text + start + count,
                self.len + 1 - (start + count))
            self.len -= count
            return self
        end,
        chop = function(self, newlen)
            if not self.text then return self end
            self.len = clamp(newlen, 0, len)
            self.text[self.len] = 0
            return self
        end,
        insert = function(self, str, start, count)
            if not count or count <= 0 then count = #str end
            start = clamp(start, 0, self.len)
            self:grow(self.len + count)
            if self.len == 0 then self.text[0] = 0 end
            C.memmove(self.text + start + count, self.text + start,
                self.len - start + 1)
            ffi_copy(self.text + start, str, count)
            self.len += count
            return self
        end,
        combine_lines = function(self, src)
            if #src == 0 then self:set("")
            else for i, v in ipairs(src) do
                if i != 1 then self:append("\n") end
                if i == 1 then self:set(v.text, v.len)
                else self:insert(v.text, self.len, v.len) end
            end end
            return self
        end,
    }
}
local editline = ffi.metatype("editline_t", editline_MT)

--[[! Struct: Text_Editor
    Implements a text editor widget. It's a basic editor that supports
    scrolling of text and some extra features like key filter, password
    and so on. It supports copy-paste that interacts with native system
    clipboard. It doesn't have any states.
]]
local Text_Editor = register_class("Text_Editor", Widget, {
    __init = function(self, kwargs)
        kwargs = kwargs or {}

        self.clip_w = kwargs.clip_w or 0
        self.clip_h = kwargs.clip_h or 0
        self.virt_w = 0
        self.virt_h = 0
        self.text_w = 0
        self.text_h = 0
        local mline = kwargs.multiline != false and true or false
        self.multiline = mline

        self.keyfilter  = kwargs.key_filter
        self.init_value = kwargs.value
        local font = kwargs.font
        self.font  = font
        self.scale = kwargs.scale or 1

        self.offset_h, self.offset_v = 0, 0
        self.filename = nil

        -- cursor position - ensured to be valid after a region() or
        -- currentline()
        self.cx, self.cy = 0, 0
        -- selection mark, mx = -1 if following cursor - avoid direct access,
        -- instead use region()
        self.mx, self.my = -1, -1

        self.scrolly = 0

        self.line_wrap = kwargs.line_wrap or false
        self.password = kwargs.password or false

        -- must always contain at least one line
        self.lines = { editline(kwargs.value) }

        self._needs_calc = true

        return Widget.__init(self, kwargs)
    end,

    clear = function(self)
        self:set_focus(nil)
        return Widget.clear(self)
    end,

    edit_clear = function(self, init)
        self._needs_calc = true
        self.cx, self.cy = 0, 0
        self:mark()
        if init == false then
            self.lines = {}
        else
            self.lines = { editline(init) }
        end
    end,

    mark = function(self, enable)
        self.mx = enable and self.cx or -1
        self.my = self.cy
    end,

    select_all = function(self)
        self.cx, self.cy = 0, 0
        self.mx, self.my = 1 / 0, 1 / 0
    end,

    is_empty = function(self)
        local lines = self.lines
        return #lines == 1 and lines[1].text[0] == 0
    end,

    -- constrain results to within buffer - s = start, e = end, return true if
    -- a selection range also ensures that cy is always within lines[] and cx
    -- is valid
    region = function(self)
        local sx, sy, ex, ey

        local n = #self.lines
        local cx, cy, mx, my = self.cx, self.cy, self.mx, self.my

        if  cy < 0 then
            cy = 0
        elseif cy >= n then
            cy = n - 1
        end
        local len = self.lines[cy + 1].len
        if  cx < 0 then
            cx = 0
        elseif cx > len then
            cx = len
        end
        if mx >= 0 then
            if  my < 0 then
                my = 0
            elseif my >= n then
                my = n - 1
            end
            len = self.lines[my + 1].len
            if  mx > len then
                mx = len
            end
        end
        sx, sy = (mx >= 0) and mx or cx, (mx >= 0) and my or cy -- XXX
        ex, ey = cx, cy
        if sy > ey then
            sy, ey = ey, sy
            sx, ex = ex, sx
        elseif sy == ey and sx > ex then
            sx, ex = ex, sx
        end

        self.cx, self.cy, self.mx, self.my = cx, cy, mx, my

        return ((sx != ex) or (sy != ey)), sx, sy, ex, ey
    end,

    -- also ensures that cy is always within lines[] and cx is valid
    current_line = function(self)
        local  n = #self.lines
        assert(n != 0)

        if     self.cy <  0 then self.cy = 0
        elseif self.cy >= n then self.cy = n - 1 end

        local len = self.lines[self.cy + 1].len

        if     self.cx < 0   then self.cx = 0
        elseif self.cx > len then self.cx = len end

        return self.lines[self.cy + 1]
    end,

    to_string = function(self)
        return tostring(editline():combine_lines(self.lines))
    end,

    selection_to_string = function(self)
        local buf = {}
        local sx, sy, ex, ey = select(2, self:region())

        for i = 1, 1 + ey - sy do
            local y = sy + i - 1
            local line = tostring(self.lines[y + 1])
            local len  = #line
            if y == sy then line = line:sub(sx + 1) end
            buf[#buf + 1] = line
            buf[#buf + 1] = "\n"
        end

        if #buf > 0 then
            return table.concat(buf)
        end
    end,

    remove_lines = function(self, start, count)
        self._needs_calc = true
        for i = 1, count do
            table.remove(self.lines, start)
        end
    end,

    -- removes the current selection (if any),
    -- returns true if selection was removed
    del = function(self)
        local b, sx, sy, ex, ey = self:region()
        if not b then
            self:mark()
            return false
        end

        self._needs_calc = true

        if sy == ey then
            if sx == 0 and ex == self.lines[ey + 1].len then
                self:remove_lines(sy + 1, 1)
            else self.lines[sy + 1]:del(sx, ex - sx)
            end
        else
            if ey > sy + 1 then
                self:remove_lines(sy + 2, ey - (sy + 1))
                ey = sy + 1
            end

            if ex == self.lines[ey + 1].len then
                self:remove_lines(ey + 1, 1)
            else
                self.lines[ey + 1]:del(0, ex)
            end

            if sx == 0 then
                self:remove_lines(sy + 1, 1)
            else
                self.lines[sy + 1]:del(sx, self.lines[sy].len - sx)
            end
        end

        if #self.lines == 0 then self.lines = { editline() } end
        self:mark()
        self.cx, self.cy = sx, sy

        local current = self:current_line()
        if self.cx > current.len and self.cy < #self.lines - 1 then
            current:append(tostring(self.lines[self.cy + 2]))
            self:remove_lines(self.cy + 2, 1)
        end

        return true
    end,

    insert = function(self, ch)
        if #ch > 1 then
            for c in ch:gmatch(".") do
                self:insert(c)
            end
            return nil
        end

        self._needs_calc = true

        self:del()
        local current = self:current_line()

        if ch == "\n" then
            if self.multiline then
                local newline = editline(tostring(current):sub(self.cx + 1))
                current:chop(self.cx)
                self.cy = min(#self.lines, self.cy + 1)
                table.insert(self.lines, self.cy + 1, newline)
            else
                current:chop(self.cx)
            end
            self.cx = 0
        else
            if self.cx <= current.len then
                current:insert(ch, self.cx, 1)
                self.cx = self.cx + 1
            end
        end
    end,

    movement_mark = function(self)
        self:scroll_on_screen()
        if input_is_modifier_pressed(mod.SHIFT) then
            if not self:region() then self:mark(true) end
        else
            self:mark(false)
        end
    end,

    scroll_on_screen = function(self)
        text_font_push()
        text_font_set(self.font)
        self:region()
        self.scrolly = clamp(self.scrolly, 0, self.cy)
        local h = 0
        for i = self.cy + 1, self.scrolly + 1, -1 do
            local width, height = text_get_bounds(tostring(self.lines[i].text),
                self.line_wrap and self.pixel_width or -1)
            if h + height > self.pixel_height then
                self.scrolly = i
                break
            end
            h = h + height
        end
        text_font_pop()
    end,

    edit_key = function(self, code)
        local mod_keys
        if ffi.os == "OSX" then
            mod_keys = mod.GUI
        else
            mod_keys = mod.CTRL
        end

        if code == key.UP then
            self:movement_mark()
            if self.line_wrap then
                local str = tostring(self:current_line())
                text_font_push()
                text_font_set(self.font)
                local x, y = text_get_position(str, self.cx + 1,
                    self.pixel_width)
                if y > 0 then
                    self.cx = text_is_visible(str, x, y - text_font_get_h(),
                        self.pixel_width)
                    self:scroll_on_screen()
                    text_font_pop()
                    return nil
                end
                text_font_pop()
            end
            self.cy = self.cy - 1
            self:scroll_on_screen()
        elseif code == key.DOWN then
            self:movement_mark()
            if self.line_wrap then
                local str = tostring(self:current_line())
                text_font_push()
                text_font_set(self.font)
                local x, y = text_get_position(str, self.cx,
                    self.pixel_width)
                local width, height = text_get_bounds(str,
                    self.pixel_width)
                y = y + text_font_get_h()
                if y < height then
                    self.cx = text_is_visible(str, x, y, self.pixel_width)
                    self:scroll_on_screen()
                    text_font_pop()
                    return nil
                end
                text_font_pop()
            end
            self.cy = self.cy + 1
            self:scroll_on_screen()
        elseif code == key.MOUSE4 then
            self.scrolly = self.scrolly - 3
        elseif code == key.MOUSE5 then
            self.scrolly = self.scrolly + 3
        elseif code == key.PAGEUP then
            self:movement_mark()
            if input_is_modifier_pressed(mod_keys) then
                self.cy = 0
            else
                self.cy = self.cy - self.pixel_height / text_font_get_h()
            end
            self:scroll_on_screen()
        elseif code == key.PAGEDOWN then
            self:movement_mark()
            if input_is_modifier_pressed(mod_keys) then
                self.cy = 1 / 0
            else
                self.cy = self.cy + self.pixel_height / text_font_get_h()
            end
            self:scroll_on_screen()
        elseif code == key.HOME then
            self:movement_mark()
            self.cx = 0
            if input_is_modifier_pressed(mod_keys) then
                self.cy = 0
            end
            self:scroll_on_screen()
        elseif code == key.END then
            self:movement_mark()
            self.cx = 1 / 0
            if input_is_modifier_pressed(mod_keys) then
                self.cy = 1 / 0
            end
            self:scroll_on_screen()
        elseif code == key.LEFT then
            self:movement_mark()
            if     self.cx > 0 then self.cx = self.cx - 1
            elseif self.cy > 0 then
                self.cx = 1 / 0
                self.cy = self.cy - 1
            end
            self:scroll_on_screen()
        elseif code == key.RIGHT then
            self:movement_mark()
            if self.cx < self.lines[self.cy + 1].len then
                self.cx = self.cx + 1
            elseif self.cy < #self.lines - 1 then
                self.cx = 0
                self.cy = self.cy + 1
            end
            self:scroll_on_screen()
        elseif code == key.DELETE then
            if not self:del() then
                self._needs_calc = true
                local current = self:current_line()
                if self.cx < current.len then
                    current:del(self.cx, 1)
                elseif self.cy < #self.lines - 1 then
                    -- combine with next line
                    current:append(tostring(self.lines[self.cy + 2]))
                    self:remove_lines(self.cy + 2, 1)
                end
            end
            self:scroll_on_screen()
        elseif code == key.BACKSPACE then
            if not self:del() then
                self._needs_calc = true
                local current = self:current_line()
                if self.cx > 0 then
                    current:del(self.cx - 1, 1)
                    self.cx = self.cx - 1
                elseif self.cy > 0 then
                    -- combine with previous line
                    self.cx = self.lines[self.cy].len
                    self.lines[self.cy]:append(tostring(current))
                    self:remove_lines(self.cy + 1, 1)
                    self.cy = self.cy - 1
                end
            end
            self:scroll_on_screen()
        elseif code == key.RETURN then
            -- maintain indentation
            self._needs_calc = true
            local str = tostring(self:current_line())
            self:insert("\n")
            for c in str:gmatch "." do if c == " " or c == "\t" then
                self:insert(c) else break
            end end
            self:scroll_on_screen()
        elseif code == key.TAB then
            local b, sx, sy, ex, ey = self:region()
            if b then
                self._needs_calc = true
                for i = sy, ey do
                    if input_is_modifier_pressed(mod.SHIFT) then
                        local rem = 0
                        for j = 1, min(4, self.lines[i + 1].len) do
                            if tostring(self.lines[i + 1]):sub(j, j) == " "
                            then
                                rem = rem + 1
                            else
                                if tostring(self.lines[i + 1]):sub(j, j)
                                == "\t" and j == 0 then
                                    rem = rem + 1
                                end
                                break
                            end
                        end
                        self.lines[i + 1]:del(0, rem)
                        if i == self.my then self.mx = self.mx
                            - (rem > self.mx and self.mx or rem) end
                        if i == self.cy then self.cx = self.cx -  rem end
                    else
                        self.lines[i + 1]:prepend("\t")
                        if i == self.my then self.mx = self.mx + 1 end
                        if i == self.cy then self.cx = self.cx + 1 end
                    end
                end
            elseif input_is_modifier_pressed(mod.SHIFT) then
                if self.cx > 0 then
                    self._needs_calc = true
                    local cy = self.cy
                    local lines = self.lines
                    if tostring(lines[cy + 1]):sub(1, 1) == "\t" then
                        lines[cy + 1]:del(0, 1)
                        self.cx = self.cx - 1
                    else
                        for j = 1, min(4, #lines[cy + 1]) do
                            if tostring(lines[cy + 1]):sub(1, 1) == " " then
                                lines[cy + 1]:del(0, 1)
                                self.cx = self.cx - 1
                            end
                        end
                    end
                end
            else
                self:insert("\t")
            end
            self:scroll_on_screen()
        elseif code == key.A then
            if not input_is_modifier_pressed(mod_keys) then
                return nil
            end
            self:select_all()
            self:scroll_on_screen()
        elseif code == key.C or code == key.X then
            if not input_is_modifier_pressed(mod_keys)
            or not self:region() then
                return nil
            end
            self:copy()
            if code == key.X then self:del() end
            self:scroll_on_screen()
        elseif code == key.V then
            if not input_is_modifier_pressed(mod_keys) then
                return nil
            end
            self:paste()
            self:scroll_on_screen()
        else
            self:scroll_on_screen()
        end
    end,

    hit = function(self, hitx, hity, dragged)
        local max_width = self.line_wrap and self.pixel_width or -1
        local h = 0
        text_font_push()
        text_font_set(self.font)
        local fontw = text_font_get_w()
        local pwidth = self.pixel_width
        for i = self.scrolly + 1, #self.lines do
            local linestr = tostring(self.lines[i])
            local width, height = text_get_bounds(linestr, max_width)
            if h + height > self.pixel_height then break end
            if hity >= h and hity <= h + height then
                local xo = 0
                if max_width < 0 then
                    local x, y = text_get_position(linestr, self.cx, -1)
                    local d = x - pwidth
                    if d > 0 then xo = d end
                end
                local x = text_is_visible(linestr, hitx + xo, hity - h,
                    max_width)
                if dragged then
                    self.mx, self.my = x, i - 1
                else
                    self.cx, self.cy = x, i - 1
                end
                break
            end
            h = h + height
        end
        text_font_pop()
    end,

    limit_scroll_y = function(self)
        text_font_push()
        text_font_set(self.font)
        local max_width = self.line_wrap and self.pixel_width or -1
        local slines = #self.lines
        local ph = self.pixel_height
        while slines > 0 and ph > 0 do
            local width, height = text_get_bounds(tostring(self.lines[slines]),
                max_width)
            if height > ph then break end
            ph = ph - height
            slines = slines - 1
        end
        text_font_pop()
        return slines
    end,

    copy = function(self)
        if not self:region() then return nil end
        self._needs_calc = true
        local str = self:selection_to_string()
        if str then clipboard_set_text(str) end
    end,

    paste = function(self)
        if not clipboard_has_text() then return false end
        self._needs_calc = true
        if self:region() then self:del() end
        local  str = clipboard_get_text()
        if not str then return false end
        self:insert(str)
        return true
    end,

    target = function(self, cx, cy)
        return Widget.target(self, cx, cy) or self
    end,

    hover = function(self, cx, cy)
        return self:target(cx, cy) and self
    end,

    click = function(self, cx, cy)
        return self:target(cx, cy) and self
    end,

    commit = function(self)
        self:set_focus(nil)
    end,

    hovering = function(self, cx, cy)
        if is_clicked(self) and is_focused(self) then
            local k = self:draw_scale()
            local dx, dy = abs(cx - self.offset_h), abs(cy - self.offset_v)
            local dragged = max(dx, dy) > (text_font_get_h() / 8 * k)
            self:hit(floor(cx / k), floor(cy / k), dragged)
        end
    end,

    set_focus = function(self, ed)
        if is_focused(ed) then return nil end
        set_focus(ed)
        local ati = ed and ed:allow_text_input()
        input_textinput(ati, 1 << 1) -- TI_GUI
        input_keyrepeat(ati, 1 << 1) -- KR_GUI
    end,

    clicked = function(self, cx, cy)
        self:set_focus(self)
        self:mark()
        self.offset_h = cx
        self.offset_v = cy

        return Widget.clicked(self, cx, cy)
    end,

    key_hover = function(self, code, isdown)
        if code == key.LEFT   or code == key.RIGHT or
           code == key.UP     or code == key.DOWN  or
           code == key.MOUSE4 or code == key.MOUSE5
        then
            if isdown then self:edit_key(code) end
            return true
        end
        return Widget.key_hover(self, code, isdown)
    end,

    key = function(self, code, isdown)
        if Widget.key(self, code, isdown) then return true end
        if not is_focused(self) then return false end

        if code == key.ESCAPE then
            if isdown then self:set_focus(nil) end
            return true
        elseif code == key.RETURN or code == key.TAB then
            if not self.multiline then
                if isdown then self:commit() end
                return true
            end
        elseif code == key.KP_ENTER then
            if isdown then self:commit() end
            return true
        end
        if isdown then self:edit_key(code) end
        return true
    end,

    allow_text_input = function(self) return true end,

    text_input = function(self, str)
        if Widget.text_input(self, str) then return true end
        if not is_focused(self) or not self:allow_text_input() then
            return false
        end
        local filter = self.keyfilter
        if not filter then
            self:insert(str)
        else
            local buf = {}
            for ch in str:gmatch(".") do
                if filter:find(ch) then buf[#buf + 1] = ch end
            end
            self:insert(table.concat(buf))
        end
        return true
    end,

    reset_value = function(self)
        local ival = self.init_value
        if ival and ival != tostring(self.lines[1]) then
            self:edit_clear(ival)
        end
    end,

    draw_scale = function(self)
        local scale = self.scale
        return (abs(scale) * get_text_scale(scale < 0)) / text_font_get_h()
    end,

    calc_dimensions = function(self, maxw)
        if not self._needs_calc then
            return self.text_w, self.text_h
        end
        self._needs_calc = false
        local lines = self.lines
        local w, h = 0, 0
        for i = 1, #lines do
            local tw, th = text_get_bounds(tostring(lines[i]), maxw)
            w, h = w + tw, h + th
        end
        local k = self:draw_scale()
        w, h = w * k, h * k
        self.text_w, self.text_h = w, h
        return w, h
    end,

    layout = function(self)
        Widget.layout(self)

        text_font_push()
        text_font_set(self.font)
        if not is_focused(self) then
            self:reset_value()
        end

        local lw, ml = self.line_wrap, self.multiline
        local k = self:draw_scale()
        local pw, ph = self.clip_w / k
        if not lw and not ml then
            ph = text_font_get_h()
        elseif ml then
            ph = self.clip_h / k
        else
            local w, h = text_get_bounds(tostring(self.lines[1]), pw)
            ph = h
        end

        local tw, th = self:calc_dimensions(lw and pw or -1)

        self.virt_w = max(self.w, tw)
        self.virt_h = max(self.h, th)

        self.w = max(self.w, pw * k)
        self.h = max(self.h, ph * k)
        self.pixel_width, self.pixel_height = pw, ph

        text_font_pop()
    end,

    get_clip = function(self)
        return self.clip_w, (self.multiline and self.clip_h
            or self.pixel_height * self:draw_scale())
    end,

    draw_selection = function(self, max_width)
        local selection, sx, sy, ex, ey = self:region()
        if not selection then return nil end
        local max_width = self.line_wrap and self.pixel_width or -1
        -- convert from cursor coords into pixel coords
        local psx, psy = text_get_position(tostring(self.lines[sy + 1]), sx,
            max_width)
        local pex, pey = text_get_position(tostring(self.lines[ey + 1]), ex,
            max_width)
        local maxy = #self.lines
        local h = 0
        for i = self.scrolly + 1, maxy do
            local width, height = text_get_bounds(tostring(self.lines[i]),
                max_width)
            if h + height > self.pixel_height then
                maxy = i
                break
            end
            if i == sy + 1 then
                psy = psy + h
            end
            if i == ey + 1 then
                pey = pey + h
                break
            end
            h = h + height
        end
        maxy = maxy - 1

        if ey >= self.scrolly and sy <= maxy then
            local fonth = text_font_get_h()
            -- crop top/bottom within window
            if  sy < self.scrolly then
                sy = self.scrolly
                psy = 0
                psx = 0
            end
            if  ey > maxy then
                ey = maxy
                pey = self.pixel_height - fonth
                pex = self.pixel_width
            end

            shader_hudnotexture_set()
            gle_color3ub(0xA0, 0x80, 0x80)
            gle_defvertexf(2)
            gle_begin(gl.QUADS)
            if psy == pey then
                gle_attrib2f(psx, psy)
                gle_attrib2f(pex, psy)
                gle_attrib2f(pex, pey + fonth)
                gle_attrib2f(psx, pey + fonth)
            else
                gle_attrib2f(psx,              psy)
                gle_attrib2f(psx,              psy + fonth)
                gle_attrib2f(self.pixel_width, psy + fonth)
                gle_attrib2f(self.pixel_width, psy)
                if (pey - psy) > fonth then
                    gle_attrib2f(0,                psy + fonth)
                    gle_attrib2f(self.pixel_width, psy + fonth)
                    gle_attrib2f(self.pixel_width, pey)
                    gle_attrib2f(0,                pey)
                end
                gle_attrib2f(0,   pey)
                gle_attrib2f(0,   pey + fonth)
                gle_attrib2f(pex, pey + fonth)
                gle_attrib2f(pex, pey)
            end
            gle_end()
            shader_hud_set()
        end
    end,

    draw_line_wrap = function(self, h, height)
        if not self.line_wrap then return nil end
        local fonth = text_font_get_h()
        shader_hudnotexture_set()
        gle_color3ub(0x3C, 0x3C, 0x3C)
        gle_defvertexf(2)
        gle_begin(gl.LINE_STRIP)
        gle_attrib2f(0, h + fonth)
        gle_attrib2f(0, h + height)
        gle_end()
        shader_hud_set()
    end,

    draw = function(self, sx, sy)
        clip_push(sx, sy, self:get_clip())
        text_font_push()
        text_font_set(self.font)
        hudmatrix_push()

        hudmatrix_translate(sx, sy, 0)
        local k = self:draw_scale()
        hudmatrix_scale(k, k, 1)
        hudmatrix_flush()

        local hit = is_focused(self)
        self.scrolly = clamp(self.scrolly, 0, #self.lines - 1)

        self:draw_selection()

        local h = 0
        local fontw, fonth = text_font_get_w(), text_font_get_h()
        local pwidth = self.pixel_width
        local max_width = self.line_wrap and pwidth or -1
        for i = self.scrolly + 1, #self.lines do
            local line = tostring(self.password
                and ("*"):rep(self.lines[i].len) or self.lines[i])
            local width, height = text_get_bounds(line,
                max_width)
            if h + height > self.pixel_height then break end
            local xo = 0
            if max_width < 0 and (width + fontw) > pwidth then
                local x, y = text_get_position(line, self.cx, -1)
                local d = pwidth - x - fontw
                if d < 0 then xo = d end
            end
            text_draw(line, xo, h, 255, 255, 255, 255,
                (hit and (self.cy == i - 1)) and self.cx or -1, max_width)

            if height > fonth then self:draw_line_wrap(h, height) end
            h = h + height
        end

        hudmatrix_pop()
        text_font_pop()

        Widget.draw(self, sx, sy)
        clip_pop()
    end,

    is_field = function() return true end
})
M.Text_Editor = Text_Editor

--[[! Struct: Field
    Represents a field, a specialization of <Text_Editor>. It has the same
    properties with one added, "value". It represents the current value in
    the field. You can also provide "var" via kwargs which is the name of
    the engine variable this field will write into, but it's not a property.
    If the variable doesn't exist the field will auto-create it.
]]
M.Field = register_class("Field", Text_Editor, {
    __init = function(self, kwargs)
        kwargs = kwargs or {}
        kwargs.multiline = kwargs.multiline or false

        self.value = kwargs.value or ""
        if kwargs.var then
            local varn = kwargs.var
            self.var = varn
            cs.var_new_checked(varn, cs.var_type.string, self.value)
        end

        return Text_Editor.__init(self, kwargs)
    end,

    commit = function(self)
        Text_Editor.commit(self)
        local val = tostring(self.lines[1])
        self.value = val
        -- trigger changed signal
        emit(self, "value_changed", val)

        local varn = self.var
        if varn then M.update_var(varn, val) end
    end,

    --[[! Function: key_hover
        Here it just tries to call <key>. If that returns false, it just
        returns Widget.key_hover(self, code, isdown).
    ]]
    key_hover = function(self, code, isdown)
        return self:key(code, isdown) or Widget.key_hover(self, code, isdown)
    end,

    --[[! Function: reset_value
        Resets the field value to the last saved value, effectively canceling
        any sort of unsaved changes.
    ]]
    reset_value = function(self)
        local str = self.value
        local str2 = tostring(self.lines[1])
        if str2 != str then self:edit_clear(str) end
    end,

    --[[! Function: set_value ]]
    set_value = gen_setter "value"
})

--[[! Struct: Key_Field
    Derived from <Field>. Represents a keyfield - it catches keypresses and
    inserts key names. Useful when creating an e.g. keybinding GUI.
]]
M.Key_Field = register_class("Key_Field", M.Field, {
    allow_text_input = function(self) return false end,

    key_insert = function(self, code)
        local keyname = input_get_key_name(code)
        if keyname then
            if not self:is_empty() then self:insert(" ") end
            self:insert(keyname)
        end
    end,

    --[[! Function: key_raw
        Overloaded. Commits on the escape key, inserts the name otherwise.
    ]]
    key_raw = function(code, isdown)
        if Widget.key_raw(code, isdown) then return true end
        if not is_focused(self) or not isdown then return false end
        if code == key.ESCAPE then self:commit()
        else self:key_insert(code) end
        return true
    end
})
