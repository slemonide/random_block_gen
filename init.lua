-- min and max height for blocks to be generated
local MIN = 10000
local MAX = 20000
local DEBUG = false
local HSPACING = 4
local VSPACING = 5
local SPAWNS = math.floor(31000/HSPACING/2)

local groups_ignore = {
    --"tnt",
    --"igniter"
	"not_in_creative_inventory",
	"bed"
}

gen = {}
gen.nodes = {}
gen.items = {}

function gen.ignore(name, props)
    local ignore = false
    for _, ignored_group in ipairs(groups_ignore) do
        if props.groups[ignored_group] then
--          print("ignoring " .. tostring(name))
            return true
        end
    end
end

minetest.after(0, function()
    print("Random Block Gen: Searching for nodes...")
    for name, props in pairs(minetest.registered_nodes) do
        if not gen.ignore(name, props) then
            table.insert(gen.nodes, name)
        end
    end
    print("Random Block Gen: " .. tostring(#gen.nodes) .. " nodes found")

    print("Random Block Gen: Searching for items...")
    for name, props in pairs(minetest.registered_items) do
        if not minetest.registered_nodes[name] then
            table.insert(gen.items, name)
        end
    end
    print("Random Block Gen: " .. tostring(#gen.items) .. " items found")
end)

function gen.get_node()
	return gen.nodes[math.random(#gen.nodes)]
end

function gen.get_item()
    return gen.items[math.random(#gen.items)]
end

-- fill chests
function gen.fill_chest(pos)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    -- fill inventory
    for i = 1,math.random(32) do
        inv:add_item("main", gen.get_item() .. " " .. tostring(math.random(99)))
    end
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
	local on_construct_tab = {}

	for x=minp.x,maxp.x do
		for z=minp.z,maxp.z do
			for y=minp.y,maxp.y do
                if x % HSPACING == 0 and z % HSPACING == 0 and y % VSPACING == 0 then
                    local node = gen.get_node()
                    local pos = {x=x,y=y,z=z}
                    data[area:index(x, y, z)] = minetest.get_content_id(node)
                    if minetest.registered_nodes[node].on_construct then
                        on_construct_tab[pos] = node
                    end
                end
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

	-- fix the nodes
	if next(on_construct_tab) then
		minetest.after(0.2, function(on_construct_tab)
			for pos, node in pairs(on_construct_tab) do
				minetest.registered_nodes[node].on_construct(pos)
				if node == 'default:chest' then
					minetest.after(0, gen.fill_chest, pos)
				end
			end
		end, on_construct_tab)
	end

	local t3 = os.clock()
	local geninfo = "[mg] done after ca.: "..calcdelay.." + "..string.format("%.2fs", t3 - t2).." = "..string.format("%.2fs", t3 - t1)
    if DEBUG then
        print(geninfo)
        minetest.chat_send_all(geninfo)
    end
end)

-- If player dies within the "Random Blocks Gen" region, respawn it in the same region
minetest.register_on_respawnplayer(function(player)
    local y = player:getpos().y
    if y < MAX and y > MIN then
        player:setpos({
            x = (math.random(SPAWNS)-SPAWNS)*HSPACING,
            y = MAX - 30,
            z = (math.random(SPAWNS)-SPAWNS)*HSPACING,
        })
        return true
    end
end)

