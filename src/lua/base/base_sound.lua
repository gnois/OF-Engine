---
-- base_sound.lua, version 1<br/>
-- Sound interface for Lua<br/>
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

--- Sound system for OF's Lua interface.
-- @class module
-- @name of.sound
module("of.sound", package.seeall)

--- Play sound, knowing the filename.
-- If done on the server, a message is sent to clients to play the sound.
-- @param n Path to the sound.
-- @param p Position as vec3, optional (defaults to 0,0,0)
-- @param v Sound volume (0 to 100, optional)
-- @param cn Client number (optional, server only, defaults to all clients)
function play(n, p, v, cn)
    p = p or math.vec3(0, 0, 0)

    if of.global.CLIENT then
        CAPI.playsoundname(n, p.x, p.y, p.z, v)
    else
        -- TODO: don't send if client is too far to hear
        -- warn when using non-compressed names
        if #n > 2 then
            of.logging.log(of.logging.WARNING, string.format("Sending a sound '%s' to clients using full string name. This should be done rarely, for bandwidth reasons.", n))
        end
        cn = cn or of.msgsys.ALL_CLIENTS
        of.msgsys.send(cn, CAPI.sound_toclients_byname, p.x, p.y, p.z, n, -1)
    end
end

--- Stop playing sound, knowing the filename.
-- If done on the server, a message is sent to clients to stop the sound.
-- @param n Path to the sound.
-- @param v Sound volume (0 to 100, optional)
-- @param cn Client number (optional, server only, defaults to all clients)
function stop(n, v, cn)
    if of.global.CLIENT then
        CAPI.stopsoundname(n, v)
    else
        -- warn when using non-compressed names
        if #n > 2 then
            of.logging.log(of.logging.WARNING, string.format("Sending a sound '%s' to clients using full string name. This should be done rarely, for bandwidth reasons.", n))
        end
        cn = cn or of.msgsys.ALL_CLIENTS
        of.msgsys.send(cn, CAPI.soundstop_toclients_byname, v, n, -1)
    end
end

--- Play music.
-- @param n Path to music.
-- @class function
-- @name playmusic
playmusic = CAPI.music

--- Set music handler. Starts playing immediately.
-- @param f Function representing music handler.
function setmusichandler(f)
    musichandler = f
    musiccallback() -- start playing now
end

--- Music callback. Called on playmusic from C++.
-- If there is music handler set, it calls it.
function musiccallback()
    if musichandler then
        musichandler()
    end
end

--- Register a sound. Used for hardcoded sounds. (TODO: do not hardcode sounds)
-- @param n Path to the sound in data/sounds.
-- @param v Volume of the sound (0 to 100, optional, defaults to 100)
-- @class function
-- @name register
register = CAPI.registersound

--- Reset sound slots. DEPRECATED. Entities are now using
-- real paths instead of preregistering.
-- @class function
-- @name reset
reset = CAPI.resetsound

--- Preload sound into slot. DEPRECATED. Entities are now using
-- real paths instead of preregistering.
-- @class function
-- @name preload
preload = CAPI.preloadsound
