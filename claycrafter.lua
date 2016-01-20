--
-- Formspecs
--

local function active_formspec(fuel_percent, item_percent)
	local formspec = 
		"size[8,8.5]"..
		default.gui_bg..
		default.gui_bg_img..
		default.gui_slots..
		"list[current_name;src;2.75,0.5;1,1;]"..
		"list[current_name;fuel;2.75,2.5;1,1;]"..
		"image[2.75,1.5;1,1;claycrafter_claycrafter_water_bg.png^[lowpart:"..
		(100-fuel_percent)..":claycrafter_claycrafter_water_fg.png]"..
		"image[3.75,1.5;1,1;gui_claycrafter_arrow_bg.png^[lowpart:"..
		(item_percent)..":gui_claycrafter_arrow_fg.png^[transformR270]"..
		"list[current_name;dst;4.75,0.96;2,2;]"..
		"list[current_player;main;0,4.25;8,1;]"..
		"list[current_player;main;0,5.5;8,3;8]"..
		"listring[current_name;dst]"..
		"listring[current_player;main]"..
		"listring[current_name;src]"..
		"listring[current_player;main]"..
		default.get_hotbar_bg(0, 4.25)
	return formspec
end

local inactive_formspec =
	"size[8,8.5]"..
	default.gui_bg..
	default.gui_bg_img..
	default.gui_slots..
	"list[current_name;src;2.75,0.5;1,1;]"..
	"list[current_name;fuel;2.75,2.5;1,1;]"..
	"image[2.75,1.5;1,1;claycrafter_claycrafter_water_bg.png]"..
	"image[3.75,1.5;1,1;gui_claycrafter_arrow_bg.png^[transformR270]"..
	"list[current_name;dst;4.75,0.96;2,2;]"..
	"list[current_player;main;0,4.25;8,1;]"..
	"list[current_player;main;0,5.5;8,3;8]"..
	"listring[current_name;dst]"..
	"listring[current_player;main]"..
	"listring[current_name;src]"..
	"listring[current_player;main]"..
	default.get_hotbar_bg(0, 4.25)

--
-- Node callback functions that are the same for active and inactive claycrafter
--

local function can_dig(pos, player)
	local meta = minetest.get_meta(pos);
	local inv = meta:get_inventory()
	return inv:is_empty("fuel") and inv:is_empty("dst") and inv:is_empty("src")
end

local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	if listname == "fuel" then -- "Water"
		if minetest.get_item_group(stack:get_name(), "h2o") > 0 then
			if inv:is_empty("src") then
				meta:set_string("infotext", "Claycrafter is empty")
			end
			return stack:get_count()
		else
			return 0
		end
	elseif listname == "src" then
		return stack:get_count()
	elseif listname == "dst" then
		return 0
	end
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end

--
-- Node definitions
--

minetest.register_node("claycrafter:claycrafter", {
	description = "Claycrafter",
	tiles = {
		"claycrafter_claycrafter_top.png", "claycrafter_claycrafter_bottom.png",
		"claycrafter_claycrafter_side.png", "claycrafter_claycrafter_side.png",
		"claycrafter_claycrafter_back.png", "claycrafter_claycrafter_front.png"
	},
	paramtype2 = "facedir",
	groups = {choppy = 1, oddly_breakable_by_hand = 1},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
	
	can_dig = can_dig,
	
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take
})

minetest.register_node("claycrafter:claycrafter_active", {
	description = "Claycrafter",
	tiles = {
		"claycrafter_claycrafter_top.png", "claycrafter_claycrafter_bottom.png",
		"claycrafter_claycrafter_side.png", "claycrafter_claycrafter_side.png",
		"claycrafter_claycrafter_side.png",
		{
			image = "claycrafter_claycrafter_front_active.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 1.5
			}
		}
	},
	paramtype2 = "facedir",
	light_source = 8,
	drop = "claycrafter:claycrafter",
	groups = {choppy = 1, oddly_breakable_by_hand = 1, not_in_creative_inventory = 1},
	legacy_facedir_simple = true,
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
	
	can_dig = can_dig,
	
	allow_metadata_inventory_put = allow_metadata_inventory_put,
	allow_metadata_inventory_move = allow_metadata_inventory_move,
	allow_metadata_inventory_take = allow_metadata_inventory_take
})

--
-- ABM
--

local function swap_node(pos, name)
	local node = minetest.get_node(pos)
	if node.name == name then
		return
	end
	node.name = name
	minetest.swap_node(pos, node)
end

minetest.register_abm({
	nodenames = {"claycrafter:claycrafter", "claycrafter:claycrafter_active"},
	interval = 1.0,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		--
		-- Inizialize metadata
		--
		local meta = minetest.get_meta(pos)
		local fuel_time = meta:get_float("fuel_time") or 0
		local src_time = meta:get_float("src_time") or 0
		local fuel_totaltime = meta:get_float("fuel_totaltime") or 0
		
		--
		-- Inizialize inventory
		--
		local inv = meta:get_inventory()
		for listname, size in pairs({
				src = 1,
				fuel = 1,
				dst = 4,
		}) do
			if inv:get_size(listname) ~= size then
				inv:set_size(listname, size)
			end
		end
		local srclist = inv:get_list("src")
		local fuellist = inv:get_list("fuel")
		local dstlist = inv:get_list("dst")
		
		--
		-- Cooking
		--
	
		local cooktime = minetest.get_item_group(inv:get_stack("fuel", 1):get_name(), "h2o")
		local cookable = true
		if inv:get_stack("src", 1):get_name() ~= "claycrafter:compressed_dirt" then
			cookable = false
		end
		
		-- Check if we have enough fuel to burn
		if fuel_time < fuel_totaltime then
			-- The claycrafter is currently active and has enough fuel
			fuel_time = fuel_time + 1
			
			-- If there is a cookable item then check if it is ready yet
			if cookable then
				src_time = src_time + 1
				if src_time >= cooktime then
					-- Place result in dst list if possible
					if inv:room_for_item("dst", ItemStack({name = "default:clay", count = 4})) and inv:room_for_item("dst", ItemStack({name = "vessels:drinking_glass"})) then
						print("Apparently, there's room.")
						inv:add_item("dst", {name = "default:clay", count = 4})
						inv:remove_item("src", inv:get_stack("src", 1):get_name())
						src_time = 0
					end
				end
			end
		else
			-- Furnace ran out of fuel
			if cookable then
				-- We need to get new fuel
				local fueltime = minetest.get_item_group(inv:get_stack("fuel", 1):get_name(), "h2o")
				
				if fueltime == 0 then
					-- No valid fuel in fuel list
					fuel_totaltime = 0
					fuel_time = 0
					src_time = 0
				else
					-- Take fuel from fuel list

					if inv:room_for_item("dst", ItemStack({name = "vessels:drinking_glass"})) and inv:room_for_item("dst", ItemStack({name = "default:clay", count = 4})) then
						inv:remove_item("fuel", inv:get_stack("fuel", 1):get_name())
						inv:add_item("dst", {name = "vessels:drinking_glass"})
					end

					fuel_totaltime = fueltime
					fuel_time = 0
					
				end
			else
				-- We don't need to get new fuel since there is no cookable item
				fuel_totaltime = 0
				fuel_time = 0
				src_time = 0
			end
		end
		
		--
		-- Update formspec, infotext and node
		--
		local formspec = inactive_formspec
		local item_state = ""
		local item_percent = 0
		if cookable then
			item_percent =  math.floor(src_time / cooktime * 100)
			item_state = item_percent .. "%"
		else
			if srclist[1]:is_empty() then
				item_state = "Empty"
			else
				item_state = "No water"
			end
		end
		
		local fuel_state = "Empty"
		local active = "inactive "
		if fuel_time <= fuel_totaltime and fuel_totaltime ~= 0 then
			active = "active "
			local fuel_percent = math.floor(fuel_time / fuel_totaltime * 100)
			fuel_state = fuel_percent .. "%"
			formspec = active_formspec(fuel_percent, item_percent)
			swap_node(pos, "claycrafter:claycrafter_active")
		else
			if not fuellist[1]:is_empty() then
				fuel_state = "0%"
			end
			swap_node(pos, "claycrafter:claycrafter")
		end
		
		local infotext =  "Claycrafter " .. active .. "(Dirt: " .. item_state .. "; Water: " .. fuel_state .. ")"
		
		--
		-- Set meta values
		--
		meta:set_float("fuel_totaltime", fuel_totaltime)
		meta:set_float("fuel_time", fuel_time)
		meta:set_float("src_time", src_time)
		meta:set_string("formspec", formspec)
		meta:set_string("infotext", infotext)
	end
})
