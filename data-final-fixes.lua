-----------------------------
-- Setup
-----------------------------

-- max
local maxAmount = 100
local fluidMaxAmount = 3000
local energyMin = 0.002
-- settings
local globalCostMultiplier = settings.startup["cgr-Cost-Multiplier"].value
local globalOutputMultiplier = settings.startup["cgr-Output-Multiplier"].value
local globalTimeMultiplier = settings.startup["cgr-Time-Multiplier"].value
local globalPowerMultiplier = settings.startup["cgr-Power-Multiplier"].value
local powerStorageMultiplier = settings.startup["cgr-Power-Storage-Multiplier"].value

-- Function to check if an item is stackable
local function is_stackable(item_name)
  -- Check if item is a stackable "item" type
  local item = data.raw["item"][item_name]
  if item and item.stack_size and item.stack_size > 1 then
    return true
  end

  -- Check if item is a science pack (tool) type
  local tool = data.raw["tool"][item_name]
  if tool and tool.stack_size and tool.stack_size > 1 then
    return true
  end

  -- Fluids don’t stack, so we return false if it’s a fluid
  if data.raw["fluid"][item_name] then
    return false
  end

  -- Default to non-stackable if item type not found
  return false
end

function adjustPower(item)
	-- make sure we can edit the power
	local energy_source = item["energy_source"]
	if energy_source == nil then
		--print(item["name"] .. " power is not enabled... skipping power!")
		return
	end
	--print("[adjustPower] editting power for " .. dump(item["name"]) .. " " .. dump(item))

	convert_power("buffer_capacity", energy_source, powerStorageMultiplier) -- personal robotport
	convert_power("input_flow_limit", energy_source, powerStorageMultiplier) -- accumulator
	convert_power("output_flow_limit", energy_source, powerStorageMultiplier) -- accumulator

	convert_power("max_power_output", item, globalPowerMultiplier) -- max_power_output
	convert_power("min_power_output", item, globalPowerMultiplier) -- min_power_output
	convert_power("production", item, globalPowerMultiplier) -- production
	convert_power("power", item, globalPowerMultiplier) -- change power output for equipment

	-- power output for buildings to avoid changing temporature and whatnot
	local itemEffectivity = item["effectivity"]
	if itemEffectivity ~= nil then
		new_effectivity = itemEffectivity * globalPowerMultiplier
		--print("[adjustPower] itemEffectivity set to " .. dump(new_effectivity) .. " from " .. dump(itemEffectivity))
		item["effectivity"] = new_effectivity
	end

	-- nuclear reactor
	local sourceEffectivity = energy_source["effectivity"]
	if sourceEffectivity ~= nil then
		new_effectivity = sourceEffectivity * globalPowerMultiplier
		--print("[adjustPower] sourceEffectivity set to " .. dump(new_effectivity) .. " from " .. dump(sourceEffectivity))
		energy_source["effectivity"] = new_effectivity
	end


	--print("[adjustPower] finished editting power for " .. dump(item["name"]) .. " " .. dump(item))
end

function convert_power(key_name, item, multiplier)
	local input_string = item[key_name] -- "90mW"
	if input_string ~= nil then
		--print("[adjustPower] multiplying " .. key_name .. ": " .. dump(input_string))
		final_multiplier = globalPowerMultiplier
		new_input_string = scale_energy_string_using_multiplier(input_string, final_multiplier)

		--print("[adjustPower] " .. key_name .. " set to " .. dump(new_input_string) .. " from " .. dump(input_string))
		item[key_name] = new_input_string
	end
end

local watt_to_multiplier = {
	["k"] = 1, 
	["M"] = 1000, 
	["G"] = 1000000, 
	["T"] = 1000000000, 
	["P"] = 1000000000000, 
	["E"] = 1000000000000000, 
	["Z"] = 1000000000000000000, 
	["Y"] = 1000000000000000000000,
}

function scale_energy_string_using_multiplier(energy_string, multiplier)
	-- energy_string = 40MW
	energy_usage = tonumber(string.match(energy_string, '%d[%d.]*')) -- 40
	energy_usage = energy_usage * get_watt_multiplier_from_string(energy_string) -- 40,000
	new_energy_usage = energy_usage * multiplier -- 40,000,000
	--print("[scale_energy_string_using_multiplier] new_energy_usage " .. dump(new_energy_usage))

	new_energy_usage_string = convert_number_to_watt_string(new_energy_usage) -- 40G

	energy_usage_type = string.sub(energy_string, -1) -- W/J
	final_energy_string = new_energy_usage_string .. energy_usage_type -- 40GW/40GJ
	--print("[scale_energy_string_using_multiplier] final_energy_string: " .. dump(final_energy_string))
	return final_energy_string
end

function get_watt_multiplier_from_string(value_string)
	local energy_type = string.sub(string.sub(value_string, -2), 1, 1) -- W/J
	local multiplier = watt_to_multiplier[energy_type]
	if multiplier ~= nil then
		return multiplier
	end

	return 1
end

function convert_number_to_watt_string(value)
	--print("[convert_number_to_watt_string] converting " .. dump(value))

	-- convert 1900000 to 1.9mw
	local largest_multiplier_suffix = "k" --m
	local largest_multiplier = 1000 --1000000
	for key, multiplier in pairs(watt_to_multiplier) do
		if value > multiplier and value > largest_multiplier then
			largest_multiplier = multiplier
			largest_multiplier_suffix = key
		end
	end
	--print("[convert_number_to_watt_string] largest_multiplier " .. dump(largest_multiplier) .. dump(largest_multiplier_suffix))

	if largest_multiplier_suffix == "k" then
		final_string_value = tostring(value) .. tostring(largest_multiplier_suffix) -- 900k
		--print("[convert_number_to_watt_string] skipping convertion because too smaller than kw: " .. dump(final_string_value))
		return final_string_value
	end

	smaller_value = value / largest_multiplier --1.9
	final_value = math.min(math.max(1, smaller_value), 999)

	--print("[convert_number_to_watt_string] final_value " .. dump(final_value))
	final_string_value = tostring(final_value) .. tostring(largest_multiplier_suffix) -- 1.9m
	--print("[convert_number_to_watt_string] final_string_value " .. dump(final_string_value))
	return final_string_value
end


-- Loop through all recipes in the game's "data.raw" table
for i, recipe in pairs(data.raw.recipe) do
	-- Modify the ingredients (inputs)
	--log("Before final fixes: " .. serpent.block(data.raw.recipe["speed-module"]))
	if recipe.ingredients then
		for i, ingredient in pairs(recipe.ingredients) do
      -- Apply global multiplier to the ingredient amount
			--log(serpent.block(recipe))
			if ingredient.amount then
				local calcInput= ingredient.amount * globalCostMultiplier
				ingredient.amount = math.max(1, math.min(calcInput, maxAmount))
			else
				log("Missing amount for ingredient: " .. serpent.block(ingredient))
			end
		end
	end
	--log("After final fixes: " .. serpent.block(data.raw.recipe["speed-module"]))
  -- Modify the results (outputs)
  -- Modify results
	if recipe.results then
		for i, result in pairs(recipe.results) do
		--Fluids
			if data.raw["fluid"][result.name] then
				-- Apply multiplier to fluids directly
				local calcOutput = result.amount * globalOutputMultiplier
				result.amount = math.max(1, math.min(calcOutput, fluidMaxAmount))
			elseif data.raw["tool"][result.name] then
				-- Apply multiplier to science packs
				local calcOutput = result.amount * globalOutputMultiplier
				result.amount = math.max(1, math.min(calcOutput, maxAmount))
			elseif data.raw["ammo"][result.name] then
				-- Apply multiplier to ammunition
				local calcOutput = result.amount * globalOutputMultiplier
				result.amount = math.max(1, math.min(calcOutput, maxAmount))
			-- Default case for regular stackable items
			elseif is_stackable(result.name) then
				local calcOutput = result.amount * globalOutputMultiplier
				result.amount = math.max(1, math.min(calcOutput, maxAmount))
			
			-- Non-stackable items
			else
				result.amount = 1
			end
		end
	end
  -- Modify crafting time (energy_required)
	if recipe.energy_required then
		local calcTime = recipe.energy_required * globalTimeMultiplier
		recipe.energy_required = math.max(calcTime, energyMin)
	else
		local calcTime = 0.5 * globalTimeMultiplier
		recipe.energy_required = math.max(calcTime, energyMin)
	end
end

local entity_types = {"boiler", "generator", "fusion-generator", "generator-equipment", "solar-panel", "solar-panel-equipment", "accumulator", "battery-equipment"}

for i, entity_type in pairs(entity_types) do
    if data.raw[entity_type] then
        for key, item in pairs(data.raw[entity_type]) do
            if item.energy_source and item.energy_source.type then
                -- Check if the energy source type matches one of the ones you are interested in
                if item.energy_source.type == "electric" or 
                   item.energy_source.type == "burner" or 
                   item.energy_source.type == "heat" or 
                   item.energy_source.type == "fluid" or 
                   item.energy_source.type == "void" then
                    adjustPower(item)  -- Apply your power adjustment logic here
                end
            end
        end
    end
end



