-- min and max height for blocks to be generated
local MIN = 10000
local MAX = 20000
local DEBUG = false
local HSPACING = 4
local VSPACING = 5
local CHEST_CHANCE = 0.9
local SPAWNS = math.floor(31000/HSPACING/2)

local groups_ignore = {
    --"tnt",
    --"igniter"
}

gen = {}
gen.nodes = {}
gen.items = {}

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

    local chest_formspec =
     "size[8,9]" ..
     default.gui_bg ..
     default.gui_bg_img ..
     default.gui_slots ..
     "list[current_name;main;0,0.3;8,4;]" ..
     "list[current_player;main;0,4.85;8,1;]" ..
     "list[current_player;main;0,6.08;8,3;8]" ..
     "listring[current_name;main]" ..
     "listring[current_player;main]" ..
     default.get_hotbar_bg(0,4.85)
    
    meta:set_string("formspec", chest_formspec)
    meta:set_string("infotext", "Chest")
    local inv = meta:get_inventory()
    inv:set_size("main", 8*4)

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

	for x=minp.x,maxp.x do
		for z=minp.z,maxp.z do
			for y=minp.y,maxp.y do
                if x % HSPACING == 0 and z % HSPACING == 0 and y % VSPACING == 0 then
                    local node = gen.get_node()
                    data[area:index(x, y, z)] = minetest.get_content_id(node)
                    if math.random() > CHEST_CHANCE then
                        gen.fill_chest({x=x,y=y,z=z})
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

