--[[
Waits for locksmithing customers and hands each one off to lock_job -- the
same hand-off board.lua does -- without board's own skill-training rotation
while waiting.

/mode serve_customers

Requires lock_job to support after:<mode> chaining (it doesn't, upstream,
as of this writing -- see CLAUDE.md for the small patch that adds it).
Without that patch, lock_job falls back to its stock set_mode('board') once
its queue empties, and you'll land in board's training rotation instead of
back here.
]]
local locksmithing = require('lib_locksmithing')

local M = {}

M.desc = 'Greet and service locksmithing customers as they arrive'

local customer_types = {
    {name = 'sailor', patterns = locksmithing.sailor_arrival},
    {name = 'scholar', patterns = locksmithing.scholar_arrival},
    {name = 'citizen', patterns = locksmithing.citizen_arrival},
    {name = 'merchant', patterns = locksmithing.merchant_arrival},
    {name = 'trader', patterns = locksmithing.trader_arrival},
}

M.reactions = {}

for _, c in ipairs(customer_types) do
    table.insert(M.reactions, {
        match = c.patterns,
        action = function() set_mode('lock_job', {c.name, 'after:serve_customers'}) end,
    })
end

return M
