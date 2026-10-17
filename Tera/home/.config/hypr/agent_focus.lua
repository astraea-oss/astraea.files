-- Keep windows opened by AI coding agents from stealing focus.
--
-- When a window opens, walk its process ancestry. If an agent CLI started it,
-- tag it, keep its workspace from scrolling, move it to the far right of
-- the tape, and hand focus straight back.
-- Windows opened any other way keep normal focus behaviour.
--
-- A no_initial_focus rule cannot be used: rules are evaluated before
-- open_early, which is the first point where the window's PID is known.
-- Instead, the events run open_early (old window still focused) -> focus
-- moves to the new window -> open, all before the next frame. open_early
-- inhibits scrolling on the target workspace so the focus change does not
-- move its tape, and open restores focus and lifts the inhibition.
--
-- Limits: a process that detaches to systemd (setsid, uwsm app, hyprctl
-- dispatch exec) loses its ancestry, and a request handed to an already
-- running app (xdg-open into an open browser) belongs to that app's process.

local M = {}

M.TAG = "agent-spawned"
local AGENTS = { claude = true, codex = true, opencode = true }

-- State carried from open_early to open for the window being mapped.
local pending = nil

local function read_line(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local line = file:read("*l")
    file:close()
    return line
end

local function parent_pid(pid)
    local stat = read_line("/proc/" .. pid .. "/stat")
    -- The command name may contain spaces or ")"; fields resume after the
    -- last ")": state, then the parent PID.
    local ppid = stat and stat:match(".*%) %S+ (%d+)")
    return ppid and tonumber(ppid)
end

function M.spawned_by_agent(pid)
    for _ = 1, 64 do
        if not pid or pid <= 1 then
            return false
        end
        if AGENTS[read_line("/proc/" .. pid .. "/comm")] then
            return true
        end
        pid = parent_pid(pid)
    end
    return false
end

local function focus_address(address)
    local window = address and hl.get_window("address:" .. address)
    if window then
        hl.dispatch(hl.dsp.focus({ window = window }))
    end
end

-- inhibit_scroll toggles, and applies to the focused workspace's layout.
local function toggle_scroll_inhibit()
    hl.dispatch(hl.dsp.layout("inhibit_scroll"))
end

-- A window can be destroyed between open_early and open. Lift its inhibit
-- (from its workspace, which still holds focus) so scrolling is not stuck.
local function release_stale()
    local state = pending
    pending = nil
    if state and state.inhibited then
        focus_address(state.workspace_last)
        toggle_scroll_inhibit()
        focus_address(state.previous)
    end
end

function M.handle_destroy(window)
    if pending and window and window.address == pending.address then
        release_stale()
    end
end

function M.handle_open_early(window)
    release_stale()
    if not window or not window.pid or window.pid <= 0 or not M.spawned_by_agent(window.pid) then
        return
    end
    hl.dispatch(hl.dsp.window.tag({ tag = "+" .. M.TAG, window = window }))

    local active = hl.get_active_window()
    local workspace = window.workspace
    local workspace_last = workspace and workspace.last_window
    pending = {
        address = window.address,
        previous = active and active.address,
        workspace_last = workspace_last and workspace_last.address,
        inhibited = false,
    }

    -- An empty workspace has no tape position to protect.
    if workspace and workspace.tiled_layout == "scrolling" and workspace_last then
        -- Make the target workspace the focused one so the inhibit lands on
        -- its layout; open restores the real focus afterwards. Focusing in
        -- from another monitor would recentre the column, so use fit mode
        -- (scroll only if not already visible) for the hop, as
        -- smart_scroll_nav.lua does.
        if not active or active.address ~= workspace_last.address then
            hl.config({ scrolling = { focus_fit_method = 1 } })
            hl.exec_scheduled_prop_refresh_immediately()
            focus_address(workspace_last.address)
            hl.config({ scrolling = { focus_fit_method = 0 } })
            hl.exec_scheduled_prop_refresh_immediately()
        end
        toggle_scroll_inhibit()
        pending.inhibited = true
    end
end

-- The new window is still focused here and scrolling is inhibited, so its
-- column can be swapped to the end of the tape without moving the view.
local function move_to_last_column(window)
    local current = hl.get_window("address:" .. window.address)
    local layout = current and current.layout
    if type(layout) ~= "table" or layout.name ~= "scrolling" or not layout.column
        or #layout.column.windows > 1 or not current.workspace then
        return
    end
    local last = layout.column.index
    for _, other in ipairs(current.workspace:get_windows()) do
        local other_layout = other.layout
        if type(other_layout) == "table" and other_layout.column and other_layout.column.index > last then
            last = other_layout.column.index
        end
    end
    focus_address(window.address)
    -- Swap exactly as many times as needed; wrap_swapcol would otherwise
    -- carry the column round to the start.
    for _ = layout.column.index + 1, last do
        hl.dispatch(hl.dsp.layout("swapcol r"))
    end
end

function M.handle_open(window)
    local state = pending
    pending = nil
    if not state or not window or window.address ~= state.address then
        return
    end

    -- Keep the workspace's own focused column; with scrolling inhibited this
    -- does not move the tape either. Always lift the inhibit afterwards.
    local ok, err = pcall(function()
        if state.inhibited then
            move_to_last_column(window)
        end
        focus_address(state.workspace_last)
    end)
    if state.inhibited then
        toggle_scroll_inhibit()
    end
    if state.previous and state.previous ~= state.workspace_last then
        focus_address(state.previous)
    end

    if not ok then
        error(err)
    end
end

return M
