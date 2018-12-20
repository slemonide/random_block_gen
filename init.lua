random_block_gen = {}

-- min and max height for blocks to be generated
random_block_gen.MIN_Y = 10000
random_block_gen.MAX_Y = 20000

random_block_gen.HSPACING = 4
random_block_gen.VSPACING = 5

random_block_gen.GROUPS_IGNORE = {
	--"tnt",
	--"igniter"
	--"bed"
}

random_block_gen.nodes = {}
random_block_gen.items = {}

local on_construct_names = {}
local on_construct_functions = {}

-- Add node or item to database.
-- Parameter "typ" is optional for autodetection
function random_block_gen.add_item(name, typ)
	local def = minetest.registered_items[name]
	local content_id = minetest.get_content_id(name)
	if (typ or def.type) == 'node' then
		table.insert(random_block_gen.nodes, content_id)
	else
		table.insert(random_block_gen.items, content_id)
	end
	if def.on_construct then
		on_construct_names[content_id] = name
		on_construct_functions[content_id] = def.on_construct
	end
end

-- Check ignored group
function random_block_gen.ignore(name, props)
	for _, ignored_group in ipairs(random_block_gen.GROUPS_IGNORE) do
		if props.groups[ignored_group] then
			return true
		end
	end
	return false
end


minetest.after(0, function()
	minetest.log("Random Block Gen: Searching for items and nodes...")
	for name, def in pairs(minetest.registered_items) do
		-- collect creative available stuff only
		if def.description and def.description ~= "" and
				not random_block_gen.ignore(name, def) and
				not def.groups.not_in_creative_inventory then
			random_block_gen.add_item(name)
		else
			minetest.log("verbose", "Random Block Gen: Skip"..name)
		end
	end
	minetest.log("Random Block Gen: " .. tostring(#random_block_gen.nodes) .. " nodes found")
	minetest.log("Random Block Gen: " .. tostring(#random_block_gen.items) .. " items found")
end)

function random_block_gen.get_node()
	return random_block_gen.nodes[math.random(#random_block_gen.nodes)]
end

function random_block_gen.get_item()
	return random_block_gen.items[math.random(#random_block_gen.items)]
end

-- fill chests
function random_block_gen.fill_chest(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	-- fill inventory
	for i = 1, math.random(inv:get_size("main")) do
		local stack = ItemStack(random_block_gen.get_item())
		stack:set_count(math.random(stack:get_stack_max()))
		inv:add_item("main", stack)
    end
end

local function do_on_construct(on_construct_tab)
	-- Check if chunk really processed
	local chk_pos = next(on_construct_tab)
	local chk_node = minetest.get_node(chk_pos)
	if chk_node.name == 'ignore' then
		minetest.after(0.1, do_on_construct, on_construct_tab)
		return -- try again in 0.1 seconds
	end

	-- Chunk is there, do it
	for pos, i in pairs(on_construct_tab) do
		on_construct_functions[i](pos)
		if on_construct_names[i] == 'default:chest' then
			minetest.after(0.1, random_block_gen.fill_chest, pos)
		end
	end
end


minetest.register_on_generated(function(minp, maxp, seed)
	-- Check right high
	if random_block_gen.MIN_Y > maxp.y or random_block_gen.MIN_Y < minp.y then
		return
	end
	local min_y, max_y
	if random_block_gen.MIN_Y > minp.y then
		min_y = random_block_gen.MIN_Y
	else
		min_y = minp.y
	end
	if random_block_gen.MAX_Y < maxp.y then
		max_y = random_block_gen.MAX_Y
	else
		max_y = maxp.y
	end

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local data = vm:get_data()
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local on_construct_tab = {}

	for x=minp.x, maxp.x, random_block_gen.HSPACING do
		for z=minp.z, maxp.z, random_block_gen.HSPACING do
			for y=min_y, max_y, random_block_gen.VSPACING do
				local pos = {x=x,y=y,z=z}
				local content_id = random_block_gen.get_node()
				 data[area:index(x, y, z)] = content_id
				if on_construct_functions[content_id] then
					on_construct_tab[pos] = content_id
				end
			end
		end
	end

	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:update_liquids()
	vm:write_to_map()

	-- fix the nodes
	if next(on_construct_tab) then
		minetest.after(0.1, do_on_construct, on_construct_tab)
	end
end)
