---
-- mod_conv.lua, version 1<br/>
-- Type conversions module for OF<br/>
-- <br/>
-- @author q66 (quaker66@gmail.com)<br/>
-- license: MIT/X11<br/>
-- <br/>
-- @copyright 2011 OctaForge project<br/>
-- <br/>
-- Permission is hereby granted, free of charge, to any person obtaining a copy<br/>
-- of this software and associated documentation files (the "Software"), to deal<br/>
-- in the Software without restriction, including without limitation the rights<br/>
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell<br/>
-- copies of the Software, and to permit persons to whom the Software is<br/>
-- furnished to do so, subject to the following conditions:<br/>
-- <br/>
-- The above copyright notice and this permission notice shall be included in<br/>
-- all copies or substantial portions of the Software.<br/>
-- <br/>
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR<br/>
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,<br/>
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE<br/>
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER<br/>
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,<br/>
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN<br/>
-- THE SOFTWARE.
--

--- Type conversion module for OctaForge. Contains several basic type conversion
-- methods, some of them wrapped from global. toboolean is a new method.
-- tointeger is a new method too, tonumber and tostring are wrapped.
-- tocalltable is new and converts function to callable table.
-- @class module
-- @name convert
module("convert", package.seeall)

--- Convert types into boolean.
-- @param v Value to convert.
-- @return A boolean value.
function toboolean(v)
    return (
        (type(v) == "number" and v ~= 0) or
        (type(v) == "string" and v == "true") or
        (type(v) == "boolean" and v) or
        false
    )
end

--- Convert types into integer.
-- @param v Value to convert.
-- @return A number with integral value.
function tointeger(v)
    return math.floor(tonumber(v))
end

--- Convert a floating point number to
-- string representing the number with
-- max two decimal positions. Returns "0"
-- if the number is lower than 0.01.
-- @param v Value to convert.
-- @return A converted value.
function todec2str(v)
    v = v or 0
    if math.abs(v) < 0.01 then return "0" end
    local r = tostring(v)
    local p = string.find(r, "%.")
    return not p and r or string.sub(r, 1, p + 2)
end

-- Convert types into number.
-- @param v Value to convert.
-- @return A number value.
function tonumber(v)
    return (type(v) == "boolean" and
        (v and 1 or 0) or _G["tonumber"](v)
    )
end

-- Convert types into string.
-- @param v Value to convert.
-- @return A string value.
-- @class function
-- @name tostring
tostring = _G["tostring"];

--- Make function a callable table.
-- @param f A function.
-- @return Callable table.
function tocalltable(f)
    return (type(f) == "function"
        and setmetatable({}, { __call = f })
        or nil
    )
end

--- Convert array of three numbers to vec3.
-- @param v The array to convert.
-- @return vec3 of the numbers.
function tovec3(v)
    if v.is_a and v:is_a(math.vec3) then return v end
    return math.vec3(v[1], v[2], v[3])
end

--- Convert array of four numbers to vec4.
-- @param v The array to convert.
-- @return vec4 of the numbers.
function tovec4(v)
    if v.is_a and v:is_a(math.vec4) then return v end
    return math.vec4(v[1], v[2], v[3], v[4])
end

