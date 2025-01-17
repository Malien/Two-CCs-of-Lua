-- Making sure blaze burners don't run run when nothing can be brewed

local state = {
    awkward = {
        state = "pending",
        relay = {
            name = "redstone_relay_4",
            side = "right",
            default = "off"
        },
        basin = peripheral.wrap("basin_3"),
        drain = peripheral.wrap("create:item_drain_1")
    },
    poison = {
        state = "pending",
        relay = {
            name = "redstone_relay_3",
            side = "right",
            default = "off"
        },
        basin = peripheral.wrap("basin_2"),
        drain = peripheral.wrap("create:item_drain_2")
    },
    harm = {
        state = "pending",
        relay = {
            name = "redstone_relay_3",
            side = "left",
            default = "on"
        },
        basin = peripheral.wrap("basin_4"),
        drain = peripheral.wrap("create:item_drain_3")
    }
}

assert(state.awkward.basin, "Awkward poition basin not found")
assert(state.poison.basin, "Poison potion basin not found")
assert(state.harm.basin, "Harm potion basin not found")

assert(peripheral.isPresent(state.awkward.relay.name), "Awkward potion fluid valve controller not found")
assert(peripheral.isPresent(state.poison.relay.name), "Poison potion fluid valve controller not found")
assert(peripheral.isPresent(state.harm.relay.name), "Harm potion fluid valve controller not found")

assert(state.awkward.drain, "Awkward potion item drain not found")
assert(state.poison.drain, "Poison potion item drain not found")
assert(state.harm.drain, "Harm potion item drain not found")

local function next_state(component)
    local count = component.basin.getInventory()[1].count or 0
    local has_fluid = component.basin.getInputFluids()[1].amount == 1000
    local drain_tank = component.drain.tanks()[1]
    local drain_has_space = not drain_tank or drain_tank.amount <= 500

    if component.state == "pending" and count == 16 and has_fluid and drain_has_space then
        return "supplying"
    elseif component.state == "supplying" and (count == 0 or not has_fluid or not drain_has_space) then
        return "pending"
    else return component.state end
end

local function logic_xor(a, b)
    return (a and not b) or (not a and b)
end

local function apply_state(state, relay_description)
    local state = logic_xor(state == "supplying", relay_description.default == "on")

    peripheral.call(
        relay_description.name,
        "setOutput",
        relay_description.side,
        state
    )
end

local function tick(component_name)
    local component = state[component_name]

    local new_state = next_state(component)
    if new_state ~= component.state then
        print("Changing " .. component_name .. " state to", new_state)
    end
    apply_state(new_state, component.relay)
    component.state = new_state
end


while true do
    tick("awkward")
    tick("poison")
    tick("harm")

    sleep(1)
end