--[[! File: library/core/std/entities/init.lua

    About: Author
        q66 <quaker66@gmail.com>

    About: Copyright
        Copyright (c) 2011 OctaForge project

    About: License
        This file is licensed under MIT. See COPYING.txt for more information.

    About: Purpose
        OctaForge standard library loader (Entity system).
]]

log(DEBUG, ":::: State variables.")
svars = require("std.entities.svars")

log(DEBUG, ":::: Entities.")
ents = require("std.entities.ents")

log(DEBUG, ":::: Entities: basic set.")
require("std.entities.ents_basic")
