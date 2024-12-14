local expect = require("cc.expect").expect
local pretty = require("cc.pretty").pretty

local SymbolMetatable = {
    __tostring = function(self)
        return "symbol(" .. self.symbol_name .. ")"
    end
}
local function symbol(name)
    expect(1, name, "string")
    return setmetatable({ symbol_name = name }, SymbolMetatable)
end


local START = symbol("sm.START")
local EXIT = symbol("sm.EXIT")

local StateMachine = {}
StateMachine.mt = {
    __index = StateMachine
}

---@param descriptor string|table
---@param definition table
---@return function|table
local function traverse_once(descriptor, definition)
    local next = definition[descriptor]
    -- print("traverse_once", pretty(descriptor), pretty(next))
    if type(next) == "nil" then
        -- print(pretty(definition))
        -- print(pretty(descriptor))
        -- print(pretty(next))
        error("State machine transitioned to an undefined state " .. pretty(descriptor))
    elseif type(next) == "function" or type(next) == "table" then
        return next
    else
        error("State machine transition for state " .. pretty(descriptor) .. " is invalid. Expected a function or a table, received " .. pretty(next))
    end
end

---@param handler function|table
---@return boolean
local function is_redirect(handler)
    return type(handler) == "table" and getmetatable(handler) ~= StateMachine.mt
end

---@param table table
---@return table
local function keys(table)
    local result = {}
    for k in pairs(table) do
        table.insert(result, k)
    end
    return result
end

---@param state table
---@param definition table
local function traverse_redirections(state, definition)
    local next = traverse_once(state[1], definition)
    if not is_redirect(next) then return next, state end
    local state, next = next, traverse_once(next[1], definition)
    if not is_redirect(next) then return next, state end
    local state, next = next, traverse_once(next[1], definition)
    if not is_redirect(next) then return next, state end
    local state, next = next, traverse_once(next[1], definition)

    -- This might be a loop. Let's track it
    local visited = {}

    while is_redirect(next) do
        if visited[next[1]] then
            error("State machine is in an inifite redirect cycle: " .. pretty(keys(visited)))
        end
        visited[next[1]] = true
        state, next = next, traverse_once(next[1], definition)
    end

    return next, state
end

local function step(from_state, definition)
    local handler, state = traverse_redirections(from_state, definition)

    if type(handler) == "table" then
        error("TODO: Support child state machines")
    end

    local next_state = table.pack(handler(table.unpack(state, 2)))
    if #next_state == 0 then
        error("Handler for state " .. pretty(state[1]) .. " returned nil, not the next state to transition to")
    end
    return next_state
end

function StateMachine:run(...)
    local first_arg = ...
    -- print("first_arg", first_arg)
    -- print("...", ...)
    local state = first_arg and { ... } or { START }

    while state[1] ~= EXIT do
        -- print(pretty(state))
        state = step(state, self.definition)
    end

    return table.unpack(state, 2)
end


local function define_state_machine(definition)
    expect(1, definition, "table")
    return setmetatable({ definition = definition }, StateMachine.mt)
end

local function load_state_from_string(str)
    expect(1, str, "string")
end

local function load_state_from_file(path)
    expect(1, path, "string")
end

local function serialize_state(state)
    expect(1, state, "table")
end

local function persist_state_to_file(state, path)
    expect(1, state, "table")
    expect(2, path, "string")
end

return {
    define = define_state_machine,
    START = START,
    EXIT = EXIT
}

-- local strip_mine = define_state_machine {
--     [sm.START] = { "moved_forward", 0 },

--     moved_forward = function(iteration)
--         mine()
--         return "mined", iteration + 1
--     end,
--     mined = function(iteration)
--         if needs_dump() then
--             place_container()
--             return "placed_chest", iteration
--         elseif iteration == TUNNEL_WIDTH then
--             return sm.EXIT
--         else
--             force_forward()
--             return "moved_forward", iteration
--         end
--     end,
--     placed_chest = function(iteration)
--         dump()
--         return "mined", iteration
--     end
-- }

-- local main_loop = define_state_machine {
--     [sm.START] = { "facing_right_wall" },

--     facing_right_wall = function()
--         force_forward()
--         return "within_right_wall"
--     end,
--     within_right_wall = function()
--         turtle.turnRight()
--         return "strip_mine", "finished_mining_right"
--     end,
--     finished_mining_right = function()
--         turtle.turnLeft()
--         return "facing_left_wall"
--     end,
--     facing_left_wall = function()
--         force_forward()
--         return "within_left_wall"
--     end,
--     within_left_wall = function()
--         turtle.turnLeft()
--         return "strip_mine", "finished_mining_left"
--     end,
--     finished_mining_left = function()
--         turtle.turnRight()
--         return "facing_right_wall"
--     end,

--     strip_mine = strip_mine
-- }