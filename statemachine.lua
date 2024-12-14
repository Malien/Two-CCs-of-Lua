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
    if type(next) == "nil" then
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
        assert(getmetatable(handler) == StateMachine.mt)
        if #state < 2 then
            error("A transition to a child state machine, " .. pretty(state[1]) .. " didn't provide a return state of the parent. Expected `return \"child\", \"return_to\"[, ... child arguments]>` ")
        end
        local child_state
        if #state == 2 then
            child_state = { START }
        else
            child_state = { table.unpack(state, 3) }
        end
        local next_child_state = step(child_state, handler.definition)
        if next_child_state[1] == EXIT then
            return { state[2], table.unpack(next_child_state, 2) }
        end
        return { state[1], state[2], table.unpack(next_child_state) }
    end

    local next_state = table.pack(handler(table.unpack(state, 2)))
    if #next_state == 0 then
        error("Handler for state " .. pretty(state[1]) .. " returned nil, not the next state to transition to")
    end
    return next_state
end

function StateMachine:run(...)
    local first_arg = ...
    local state = first_arg and { ... } or { START }

    while state[1] ~= EXIT do
        state = step(state, self.definition)
    end

    return table.unpack(state, 2)
end

function StateMachine:run_persisted(state_filepath, ...)
    local first_arg = ...
    local state = first_arg and { ... } or { START }

    while state[1] ~= EXIT do
        state = step(state, self.definition)
        local statefile = fs.open(state_filepath, "w")
        statefile.write(textutils.serialise(state))
        statefile.close()
    end

    return table.unpack(state, 2)
end

local function load_state_from_file(file)
    local statestring = file.readAll()
    local state = textutils.unserialise(statestring)
    if state == nil then
        error("Couldn't deserialize")
    end
    return state
end

function StateMachine:resume_persisted(state_filepath)
    if fs.exists(state_filepath) then
        local statefile = fs.open(state_filepath, "r")
        local ok, state_or_error = pcall(load_state_from_file, statefile)
        statefile.close()
        if ok then
            print("Recovered previously persisted state:", pretty(state_or_error))
            self:run_persisted(state_filepath, table.unpack(state_or_error))
        else
            print("Couldn't parse state file", state_or_error)
            self:run_persisted(state_filepath)
        end
    else
        print("Previously persisted state doesn't exists, starting with sm.START")
        return self:run_persisted(state_filepath)
    end
end

local function define_state_machine(definition)
    expect(1, definition, "table")
    return setmetatable({ definition = definition }, StateMachine.mt)
end

return {
    define = define_state_machine,
    START = START,
    EXIT = EXIT
}