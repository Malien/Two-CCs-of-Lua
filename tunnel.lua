local pretty = require "cc.pretty"
local expect = require "cc.expect"
local expect = expect.expect

local containers = { "minecraft:chest", "quark:spruce_chest", "quark:oak_chest", "quark:birch_chest"}
local TUNNEL_WIDTH = 3

local function mine()
    turtle.dig()
    turtle.digUp()
    turtle.digDown()
end

local function is_valid_container(item_name)
    for _, container in ipairs(containers) do
        if container == item_name then return true end
    end
    return false
end

local function place_container()
    local chest_slot_item = turtle.getItemDetail(16)
    if not chest_slot_item then error("No containers left in the last slot") end
    if not is_valid_container(chest_slot_item.name) then error("Last item in the slot is not a valid container") end
    turtle.select(16)
    if not turtle.placeDown() then error("Couldn't place container") end
end

local function needs_dump()
    local last_slot_items = turtle.getItemCount(15)
    return last_slot_items ~= 0
end

local function dump()
    for i = 1, 15 do
        turtle.select(i)
        turtle.dropDown()
    end
    turtle.select(1)
end

local function force_forward()
    while true do
        turtle.dig()
        if turtle.forward() then return end
    end
end

local function try_dump() 
    if needs_dump() then
        place_container() 
        dump()
    end
end

local function mine_strip()
    for i = 1, TUNNEL_WIDTH - 1 do
        mine()
        try_dump()
        force_forward()
    end
    mine()
    try_dump()
end

---@param state? table
---@param return_to? string
---@return table|string
local function execute_strip_mine(state, return_to)
    assert(state == nil or (type(state) == "table" and #state == 4 and state[1] == "strip"), pretty.pretty(state))
    state = state or { "strip", 0, "moved-forward", return_to }

    local _, iteration, stage, return_to = table.unpack(state)

    if stage == "mined" and needs_dump() then
        place_container()
        return { "strip", iteration, "placed-chest", return_to }
    elseif stage == "mined" and iteration == TUNNEL_WIDTH then
        return return_to
    elseif stage == "mined" then
        force_forward()
        return { "strip", iteration, "moved-forward", return_to }
    elseif stage == "placed-chest" then
        dump()
        return { "strip", iteration, "mined", return_to }
    elseif stage == "moved-forward" then
        mine()
        return { "strip", iteration + 1, "mined", return_to }
    else
        error("Unknown stage " .. stage)
    end
end

---@return string|table
local function execute_step(state)
    if state == "facing-right-wall" then
        force_forward()
        return "within-right-wall"
    elseif state == "within-right-wall" then
        turtle.turnRight()
        return "facing-right-strip"
    elseif state == "facing-right-strip" then
        return execute_strip_mine(nil, "finished-mining-right")
    elseif state == "finished-mining-right" then
        turtle.turnLeft()
        return "facing-left-wall"
    elseif state == "facing-left-wall" then
        force_forward()
        return "within-left-wall"
    elseif state == "within-left-wall" then
        turtle.turnLeft()
        return "facing-left-strip"
    elseif state == "facing-left-strip" then
        return execute_strip_mine(nil, "finished-mining-left")
    elseif state == "finished-mining-left" then
        turtle.turnRight()
        return "facing-right-wall"
    elseif type(state) == "table" and state[1] == "strip" then
        return execute_strip_mine(state)
    else
        error("Unknown state " .. pretty.render(pretty.pretty(state)))
    end
end

-- while true do
--     mine_strip()
--     turtle.turnRight()
--     force_forward()
--     turtle.turnRight()
--     mine_strip()
--     turtle.turnLeft()
--     force_forward()
--     turtle.turnLeft()
-- end

local function contains(table, target_item)
    for _, item in ipairs(table) do
        if item == target_item then return true end
    end
    return false
end

local PERMITTED_SIMPLE_STATES = {"facing-right-wall", "within-right-wall", "facing-right-strip", "facing-left-wall", "within-left-wall", "facing-left-strip", "finished-mining-left", "finished-mining-right"}
local PERMITTED_STAGES = {"mined", "placed-chest", "moved-forward"}
---@param contents string
local function parse_persisted_state(contents)
    expect(1, contents, "string")

    if contains(PERMITTED_SIMPLE_STATES, contents) then
        return contents
    end

    local iteration, stage, return_to = string.match(contents, "strip (%d+) (%S+) (%S+)")
    if iteration == nil then error("Couldn't match strip state") end

    local iteration_num = tonumber(iteration)
    if iteration_num == nil then error("strip iteration is not a number") end
    if not contains(PERMITTED_STAGES, stage) then error("strip stage " .. stage .. " is not one of the permitted") end
    if not contains(PERMITTED_SIMPLE_STATES, return_to) then error("return_to state " .. return_to .. " is not one of the permitted") end

    return { "strip", iteration, stage, return_to }
end

local function serialize_state(state)
    assert(state ~= nil, "serialize_state: state is nil")
    if type(state) == "string" then return state end
    local res = state[1]
    for i, part in ipairs(state) do
        if i ~= 1 then
            res = res .. " " .. part
        end
    end
    return res
end

local function retrieve_state()
    if fs.exists("tunnelstate") then
        local statefile = fs.open("tunnelstate", "r")
        local serialized = statefile.readLine()
        statefile.close()
        if not serialized then
            print("Empty tunnelstate?")
            return nil
        end

        local ok, state_or_error = pcall(parse_persisted_state, serialized)
        if not ok then
            print("Failed to parse state: ")
            print(state_or_error)
            return nil
        end

        print("Persisted state is", serialize_state(state_or_error))
        return state_or_error
    else
        print("No previous tunnelstate file")
        return nil
    end
end

local state = retrieve_state() or "facing-right-wall"

while true do
    print(serialize_state(state))
    state = execute_step(state)
    local statefile = fs.open("tunnelstate", "w")
    statefile.write(serialize_state(state))
    statefile.flush()
    statefile.close()
end
