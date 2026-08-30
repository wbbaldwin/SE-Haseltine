--[[
Prints lifetime locksmithing stats (jobs, active time, earnings, gold/hour)
to the log and as a notification. Read-only -- sends nothing to the server.

/mode locksmith_stats
]]
local stats = require('lib_stats')

local M = {}

M.desc = 'Show lifetime locksmithing job and earnings stats'

function M.on_start(args)
    local lines = stats.summary_lines()
    for _, line in ipairs(lines) do log(line) end
    notify('Locksmith Stats', lines[1] .. '  ' .. lines[3])
    set_mode('disable')
end

M.reactions = {}

return M
