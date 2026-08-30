--[[
Lifetime locksmithing stats: totals persisted across mode switches and app
restarts. metrics.* resets every time the mode changes, and
serve_customers/lock_job bounce between modes on every single job, so it
can never hold a running total here -- state.persist can, and also
survives an app restart, which is what "throughout all my playtime" needs.

Call from wherever a job actually starts, finishes, or moves money --
currently that's lock_job.lua (see CLAUDE.md for the hook points).
]]
local S = {}

local KEY = 'locksmith_stats'

local function load()
    return state.get(KEY) or {
        total_jobs = 0,
        active_ms = 0,
        earnings = 0,
        expenses = 0,
        jobs_by_type = {},
        jobs_by_customer = {},
    }
end

local function save(data)
    state.set(KEY, data)
    state.persist(KEY)
end

-- Call when a customer is greeted (a job begins).
function S.job_started()
    state.set('stats_job_start', time.now())
end

-- Call once per completed job (e.g. on 'You offer', before job state is
-- reset for the next customer). job_type: 'craft'/'unlock'/'lock'/'install'.
-- customer_type: 'sailor'/'scholar'/'citizen'/'merchant'/'trader'.
function S.job_finished(job_type, customer_type)
    local data = load()
    local start = state.get('stats_job_start')
    data.total_jobs = data.total_jobs + 1
    data.active_ms = data.active_ms + (start and time.since(start) or 0)
    if job_type then
        data.jobs_by_type[job_type] = (data.jobs_by_type[job_type] or 0) + 1
    end
    if customer_type then
        data.jobs_by_customer[customer_type] = (data.jobs_by_customer[customer_type] or 0) + 1
    end
    save(data)
end

-- Call wherever a customer actually pays for a finished job.
function S.record_earning(amount)
    local data = load()
    data.earnings = data.earnings + amount
    save(data)
end

-- Call wherever a job costs money up front (e.g. buying wire for a craft job).
function S.record_expense(amount)
    local data = load()
    data.expenses = data.expenses + amount
    save(data)
end

function S.summary_lines()
    local data = load()
    local hours = data.active_ms / 3600000
    local net = data.earnings - data.expenses
    local lines = {
        string.format('Jobs completed: %d', data.total_jobs),
        string.format('Active time: %.1f hours', hours),
        string.format('Earnings: %d  Expenses: %d  Net: %d', data.earnings, data.expenses, net),
        string.format('Net per hour: %.1f', hours > 0 and (net / hours) or 0),
    }
    for jtype, count in pairs(data.jobs_by_type) do
        lines[#lines + 1] = string.format('  %s jobs: %d', jtype, count)
    end
    for ctype, count in pairs(data.jobs_by_customer) do
        lines[#lines + 1] = string.format('  %s customers: %d', ctype, count)
    end
    return lines
end

return S
