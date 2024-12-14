local sm = require "statemachine"

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

local strip_mine = sm.define {
    [sm.START] = { "moved_forward", 0 },

    moved_forward = function(iteration)
        mine()
        return "mined", iteration + 1
    end,
    mined = function(iteration)
        if needs_dump() then
            place_container()
            return "placed_chest", iteration
        elseif iteration == TUNNEL_WIDTH then
            return sm.EXIT
        else
            force_forward()
            return "moved_forward", iteration
        end
    end,
    placed_chest = function(iteration)
        dump()
        return "mined", iteration
    end
}

local main_loop = sm.define {
    [sm.START] = { "facing_right_wall" },

    facing_right_wall = function()
        force_forward()
        return "within_right_wall"
    end,
    within_right_wall = function()
        turtle.turnRight()
        return "strip_mine", "finished_mining_right"
    end,
    finished_mining_right = function()
        turtle.turnLeft()
        return "facing_left_wall"
    end,
    facing_left_wall = function()
        force_forward()
        return "within_left_wall"
    end,
    within_left_wall = function()
        turtle.turnLeft()
        return "strip_mine", "finished_mining_left"
    end,
    finished_mining_left = function()
        turtle.turnRight()
        return "facing_right_wall"
    end,

    strip_mine = strip_mine
}

main_loop:resume_persisted("tunnelstate")
