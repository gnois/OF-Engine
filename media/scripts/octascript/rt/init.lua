--[[
    OctaScript runtime

    Copyright (C) 2014 Daniel "q66" Kolesa

    See COPYING.txt for licensing.
]]

local M = {}

local bit = require("bit")

M.bit_bnot    = bit.bnot
M.bit_bor     = bit.bor
M.bit_band    = bit.band
M.bit_bxor    = bit.bxor
M.bit_lshift  = bit.lshift
M.bit_rshift  = bit.rshift
M.bit_arshift = bit.arshift

return M