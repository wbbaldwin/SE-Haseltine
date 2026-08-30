--[[
Waits for locksmithing customers to arrive and services their jobs
(craft lockpick, unlock, lock, install mechanism), the same job logic as
praetor-scripts' lock_job, but with no board-training rotation: this mode
just sits idle between customers instead of switching to board.

/mode serve_customers

Requires a lockpick already in inventory (or gettable via 'get my lockpick').
]]
local strings = require('lib_strings')
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

local function reset_job_state()
    state.set('job_type', nil)
    state.set('broken_wire', false)
    state.set('is_crafted', false)
    state.set('is_installed', false)
    state.set('is_jammed', false)
    state.set('is_locked', false)
    state.set('metal_type', nil)
    state.set('lock_target', nil)
end

-- Pop the next queued customer and greet them. Leaves state.customer nil
-- (and sends nothing) when the queue is empty, so the mode just waits.
local function greet_next_customer()
    local customers = state.get('customers') or {}
    if #customers == 0 then
        state.set('customer', nil)
        return
    end
    local customer = table.remove(customers, 1)
    state.set('customers', customers)
    state.set('customer', customer)
    reset_job_state()
    local greeting = random_item(locksmithing.greetings)
    send('say to ' .. customer .. ' ' .. greeting, 500)
end

local function enqueue_customer(name)
    local customers = state.get('customers') or {}
    customers[#customers + 1] = name
    state.set('customers', customers)
    -- Nobody being served right now: start on this one immediately instead
    -- of waiting for an unbusy line that may never come while idle.
    if not state.get('customer') then greet_next_customer() end
end

-- Customer hands over the chest/coffer/tube/trunk to work on.
local function on_item_handed(target)
    state.set('lock_target', target)
    local job = state.get('job_type')
    if job == 'lock' then
        send('lock ' .. target .. ' with lock')
    elseif job == 'unlock' then
        send('unlock ' .. target .. ' with lock')
    elseif job == 'install' then
        send('buy tumbler')
    end
end

function M.on_start(args)
    state.set('customers', {})
    state.set('customer', nil)
end

M.reactions = {}

for _, c in ipairs(customer_types) do
    table.insert(M.reactions, {
        match = c.patterns,
        action = function() enqueue_customer(c.name) end,
    })
end

for _, r in ipairs({
    -- Job type detection: craft lockpick (tin/bronze/iron)
    {
        match = 'I need a lockpick. A tin one.',
        action = function()
            state.set('job_type', 'craft')
            state.set('metal_type', 'tin')
            send('say to ' .. state.get('customer') .. ' yes')
            send('buy wire', 5500)
        end,
    },
    {
        match = 'I need a lockpick. A bronze one.',
        action = function()
            state.set('job_type', 'craft')
            state.set('metal_type', 'bronze')
            send('say to ' .. state.get('customer') .. ' yes')
            send('buy wire', 5500)
        end,
    },
    {
        match = 'I need a lockpick. An iron one.',
        action = function()
            state.set('job_type', 'craft')
            state.set('metal_type', 'iron')
            send('say to ' .. state.get('customer') .. ' yes')
            send('buy wire', 5500)
        end,
    },
    -- Wire substance selection
    {
        match = 'That comes in the following substances',
        action = function() send(state.get('metal_type')) end,
    },
    -- Wire purchase confirmation
    {
        match = 'Would you still like a thin length of wire',
        action = function() send('y') end,
    },
    -- Wire placed on counter
    {
        match = '* places a thin length',
        action = function() send('get wire') end,
    },
    -- Took wire: fashion pick
    {
        match = 'You take a thin length',
        action = function() send('fashion lockpick from wire') end,
    },
    -- Took broken wire: stash it
    {
        match = 'You take a broken thin length',
        action = function()
            send('put broken in my sack')
            state.set('broken_wire', false)
        end,
    },
    -- Put broken wire away: buy new
    {
        match = 'You put a broken',
        action = function() send('buy wire') end,
    },
    -- Pick fashioned successfully
    {
        match = 'and work it into',
        action = function() state.set('is_crafted', true) end,
    },
    -- Wire snapped
    {
        match = 'wire snaps! Its functionality gone',
        action = function() state.set('broken_wire', true) end,
    },
    -- Unlock request
    {
        match = 'Can you pick it open?',
        action = function()
            if not state.get('job_type') then
                state.set('job_type', 'unlock')
                state.set('is_locked', true)
                send('say to ' .. state.get('customer') .. ' yes')
            end
        end,
    },
    -- Lock request
    {
        match = 'Can you pick it locked?',
        action = function()
            if not state.get('job_type') then
                state.set('job_type', 'lock')
                state.set('is_locked', false)
                send('say to ' .. state.get('customer') .. ' yes')
            end
        end,
    },
    -- Jammed lock request
    {
        match = "I think it's jammed",
        action = function()
            if not state.get('job_type') then
                state.set('job_type', 'unlock')
                state.set('is_locked', true)
                state.set('is_jammed', true)
                send('say to ' .. state.get('customer') .. ' yes')
            end
        end,
    },
    -- Install request
    {
        match = 'Can you install a lock in it for me?',
        action = function()
            if not state.get('job_type') then
                state.set('job_type', 'install')
                send('say to ' .. state.get('customer') .. ' yes')
            end
        end,
    },
    -- Already done (offer straight away)
    {
        match = 'It is already',
        action = function()
            local target = state.get('lock_target')
            local customer = state.get('customer')
            if target and customer then
                send('offer ' .. target .. ' to ' .. customer)
            end
        end,
    },
    -- Unjammed / unlocked / locked
    {
        match = 'You feel an obstruction release',
        action = function() state.set('is_jammed', false) end,
    },
    {
        match = 'You hear a click as the tumbler mechanism releases',
        action = function() state.set('is_locked', false) end,
    },
    {
        match = 'You hear a click as a tumbler mechanism closes.',
        action = function() state.set('is_locked', true) end,
    },
    -- Lock is jammed (discovered during unlock)
    {
        match = 'This lock is jammed',
        action = function()
            state.set('is_jammed', true)
            send('unjam ' .. state.get('lock_target') .. ' with lock')
        end,
    },
    -- Need lockpick
    {
        match = {'You must be holding', "You don't see any", "You can't unlock", "You can't lock"},
        action = function() send('get my lockpick') end,
    },
    -- Got lockpick: resume job
    {
        match = {'You take * lockpick', 'You are already carrying * lockpick'},
        action = function()
            local job = state.get('job_type')
            local target = state.get('lock_target')
            if not target then return end
            if job == 'lock' then
                send('lock ' .. target .. ' with lock')
            elseif job == 'unlock' then
                send('unlock ' .. target .. ' with lock')
            end
        end,
    },
    -- Customer hands over the item to work on
    {
        match = 'hands you * chest',
        action = function() on_item_handed('chest') end,
    },
    {
        match = 'hands you a coffer',
        action = function() on_item_handed('coffer') end,
    },
    {
        match = 'hands you a bronze scroll tube',
        action = function() on_item_handed('tube') end,
    },
    {
        match = 'hands you a heavy wooden trunk',
        action = function() on_item_handed('trunk') end,
    },
    -- Install mechanism flow
    {
        match = "* places a small wooden box labeled 'Tumbler' *",
        action = function() send('get box') end,
    },
    {
        match = "You take a small wooden box labeled 'Tumbler'",
        action = function() send('open box') end,
    },
    {
        match = "You open a small wooden box labeled 'Tumbler', revealing a tumbler mechanism and a small tin key",
        action = function() send('empty box into ' .. state.get('lock_target')) end,
    },
    {
        match = "You empty the contents of a small wooden box labeled 'Tumbler' into",
        action = function() send('discard box') end,
    },
    {
        match = "Are you sure you want to throw a small wooden box labeled 'Tumbler' away? (y/n)",
        action = function() send('y') end,
    },
    {
        match = "You discard a small wooden box labeled 'Tumbler'",
        action = function() send('get mechanism') end,
    },
    {
        match = 'You take a tumbler mechanism',
        action = function() send('install mechanism in ' .. state.get('lock_target')) end,
    },
    {
        match = 'You set the placement of the new tumbler mechanism with great care',
        action = function() state.set('is_installed', true) end,
    },
    -- Job handed over: greet next queued customer, or go back to waiting
    {
        match = 'You offer',
        action = function() greet_next_customer() end,
    },
    -- Unbusy: state-dependent next step
    {
        match = strings.unbusy,
        action = function()
            local job = state.get('job_type')
            local customer = state.get('customer')
            if not customer then return end
            if job == 'craft' then
                if state.get('broken_wire') then
                    send('get broken')
                elseif state.get('is_crafted') then
                    send('offer ' .. state.get('metal_type') .. ' to ' .. customer)
                end
                return
            end
            local target = state.get('lock_target')
            if not target then return end
            if job == 'unlock' then
                if state.get('is_jammed') then
                    send('unjam ' .. target .. ' with lock')
                elseif state.get('is_locked') then
                    send('unlock ' .. target .. ' with lock')
                else
                    send('offer ' .. target .. ' to ' .. customer)
                end
            elseif job == 'lock' then
                if not state.get('is_locked') then
                    send('lock ' .. target .. ' with lock')
                else
                    send('offer ' .. target .. ' to ' .. customer)
                end
            elseif job == 'install' then
                if not state.get('is_installed') then
                    send('install mech in ' .. target)
                else
                    send('offer ' .. target .. ' to ' .. customer)
                end
            end
        end,
    },
}) do
    table.insert(M.reactions, r)
end

return M
