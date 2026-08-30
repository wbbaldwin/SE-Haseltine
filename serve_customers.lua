--[[
Waits for locksmithing customers and services their jobs the same way
praetor-scripts' lock_job does (craft lockpick, unlock, lock, install
mechanism). Reuses lock_job's own reaction table via require() instead of
copying its job logic, and only overrides two things:

  - Greeting a customer as soon as they arrive while idle. lock_job's own
    arrival reactions only enqueue; they assume board already started it
    with someone to serve.
  - Going back to waiting when the queue runs dry, instead of lock_job's
    own set_mode('board') hand-off into board's skill-training rotation.

/mode serve_customers

Requires a lockpick already in inventory (or gettable via 'get my lockpick').
]]
local locksmithing = require('lib_locksmithing')
local lock_job = require('lock_job')

local M = {}

M.desc = 'Greet and service locksmithing customers as they arrive'

local customer_types = {
    {name = 'sailor', patterns = locksmithing.sailor_arrival},
    {name = 'scholar', patterns = locksmithing.scholar_arrival},
    {name = 'citizen', patterns = locksmithing.citizen_arrival},
    {name = 'merchant', patterns = locksmithing.merchant_arrival},
    {name = 'trader', patterns = locksmithing.trader_arrival},
}

-- Pop the next queued customer and greet them, same greeting lock_job uses.
-- Leaves state.customer nil (mode just waits) when the queue is empty.
local function greet_next_customer()
    local customers = state.get('customers') or {}
    if #customers == 0 then
        state.set('customer', nil)
        return
    end
    local customer = table.remove(customers, 1)
    state.set('customers', customers)
    state.set('customer', customer)
    state.set('job_type', nil)
    state.set('broken_wire', false)
    state.set('is_crafted', false)
    state.set('is_installed', false)
    state.set('is_jammed', false)
    state.set('is_locked', false)
    state.set('metal_type', nil)
    state.set('lock_target', nil)
    local greeting = random_item(locksmithing.greetings)
    send('say to ' .. customer .. ' ' .. greeting, 500)
end

local function enqueue_customer(name)
    local customers = state.get('customers') or {}
    customers[#customers + 1] = name
    state.set('customers', customers)
    -- lock_job's own arrival reactions only enqueue; they assume board
    -- already has someone being served. We start service ourselves the
    -- moment nobody is being served, so an arrival never sits unhandled.
    if not state.get('customer') then greet_next_customer() end
end

function M.on_start(args)
    state.set('customers', {})
    state.set('customer', nil)
end

M.reactions = {}

-- Arrival reactions: shadow lock_job's own (which only enqueue) so a
-- customer is greeted immediately whenever nobody is currently being served.
for _, c in ipairs(customer_types) do
    table.insert(M.reactions, {
        match = c.patterns,
        action = function() enqueue_customer(c.name) end,
    })
end

-- 'You offer' hands the finished job over: shadow lock_job's own copy of
-- this reaction, which calls set_mode('board') once the queue runs dry.
-- We just go back to waiting instead.
table.insert(M.reactions, {
    match = 'You offer',
    action = function() greet_next_customer() end,
})

-- Everything else -- job-type detection, crafting, unlock/lock/install,
-- lockpick recovery, the unbusy dispatch -- is lock_job's own logic,
-- reused unmodified so it never drifts out of sync with lock_job itself.
for _, r in ipairs(lock_job.reactions) do
    table.insert(M.reactions, r)
end

return M
