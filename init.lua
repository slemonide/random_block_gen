-- min and max height for blocks to be generated
local MIN = 10000
local MAX = 20000
local DEBUG = false

local groups_ignore = {
    "tnt",
    "igniter"
}

gen = {}
gen.nodes = {}

function gen.ignore(name, props)
    local ignore = false

    for _, ignored_group in ipairs(groups_ignore) do
        for actual_group, val in pairs(props.groups) do
            if actual_group == ignored_group then
                print("ignoring " .. tostring(name))
                ignore = true
            end
        end
    end

    return ignore
end

minetest.after(0, function()
    print("Random Block Gen: Searching for nodes...")
    for name, props in pairs(minetest.registered_nodes) do
        if not gen.ignore(name, props) then
            table.insert(gen.nodes, name)
        end
    end

    print("Random Block Gen: " .. tostring(#gen.nodes) .. " nodes found")
end)

minetest.register_on_mapgen_init(function(params) -- Automatically turn on singlenode generator
    minetest.set_mapgen_params({
        mgname = "singlenode"
    })
end)


function gen.get_node()
	return gen.nodes[math.random(#gen.nodes)]
end

minetest.register_on_generated(function(minp, maxp, seed)
    if maxp.y > MAX or minp.y < MIN then
        return
    end

	local t1 = os.clock()
	local geninfo = "[mg] generates..."
    if DEBUG then
        minetest.chat_send_all(geninfo)
    end

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}

	for x=minp.x,maxp.x do
		for z=minp.z,maxp.z do
			for y=minp.y,maxp.y do
				local node = gen.get_node()
				data[area:index(x, y, z)] = minetest.get_content_id(node)
			end
		end
	end

	local t2 = os.clock()
	local calcdelay = string.format("%.2fs", t2 - t1)

	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:update_liquids()
	vm:write_to_map()

	local t3 = os.clock()
	local geninfo = "[mg] done after ca.: "..calcdelay.." + "..string.format("%.2fs", t3 - t2).." = "..string.format("%.2fs", t3 - t1)
    if DEBUG then
        print(geninfo)
        minetest.chat_send_all(geninfo)
    end
end)
