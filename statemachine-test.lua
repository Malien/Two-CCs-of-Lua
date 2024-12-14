local sm = require "statemachine"

local machine = sm.define {
    [sm.START] = { "entry", 69 },
    entry = function(arg)
        print("I'm in entry, with arg", arg)
        if arg == 420 then
            return "branched"
        else
            return "next", arg, arg + 1
        end
    end,
    next = function(arg, next_arg)
        print("I'm in next, with arg", arg, next_arg)
        return sm.EXIT, next_arg, arg
    end,
    branched = function()
        print("I'm in branched")
        return sm.EXIT
    end
}

print(machine:run())

print(machine:run("next", 420))

print(machine:run("entry", 420))


local TUNNEL_WIDTH = 3

local strip_mine = sm.define {
    [sm.START] = { "moved_forward", 0 },

    moved_forward = function(iteration)
        print("mine()")
        return "mined", iteration + 1
    end,
    mined = function(iteration)
        if --[[ needs_dump() --]] false then
            print("place_container()")
            return "placed_chest", iteration
        elseif iteration == TUNNEL_WIDTH then
            return sm.EXIT
        else
            print("force_forward()")
            return "moved_forward", iteration
        end
    end,
    placed_chest = function(iteration)
        print("dump()")
        return "mined", iteration
    end
}

local main_loop = sm.define {
    [sm.START] = { "facing_right_wall" },

    facing_right_wall = function()
        print("force_forward()")
        return "within_right_wall"
    end,
    within_right_wall = function()
        print("turtle.turnRight()")
        return "strip_mine", "finished_mining_right"
    end,
    finished_mining_right = function()
        print("turtle.turnLeft()")
        return "facing_left_wall"
    end,
    facing_left_wall = function()
        print("force_forward()")
        return "within_left_wall"
    end,
    within_left_wall = function()
        print("turtle.turnLeft()")
        return "strip_mine", "finished_mining_left"
    end,
    finished_mining_left = function()
        print("turtle.turnRight()")
        print("SHOULD CYCLE BACK TO facing_right_wall")
        -- return "facing_right_wall"
        return sm.EXIT, "facing_right_wall"
    end,

    strip_mine = strip_mine
}

print(main_loop:run())