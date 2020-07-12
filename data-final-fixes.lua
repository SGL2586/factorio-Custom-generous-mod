-----------------------------
-- Helper functions
-----------------------------

local cached_items = {}
local cached_recipes = {}
local cached_ingredient_counts = {}
local cached_ingredient_depth = {}
local cached_recipe_uses = {}
local processedRecipes = {}

local enableLogs = false
local logIndents = 0;

function print(s)
	if enableLogs then
		for i = 1, logIndents, 1 do
			s = "  " .. s
		end

		log(s)
	end
end

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function dump(o)
	if enableLogs == false then
		return ''
	end


	if o == nil then
		return 'nil'
	end

	if type(o) == 'table' then
		local s = '{'
		local items_left = tablelength(o)
		for k,v in pairs(o) do
			k = '"' .. dump(k) .. '"'

			v_string = dump(v)
			if type(v) ~= 'table' and type(v) ~= 'number' and type(v) ~= 'boolean' then
				v_string = '"' .. v_string .. '"'
			end

			s = s .. k .. ":" .. v_string
			if items_left > 1 then
				items_left = items_left - 1
				s = s .. ','
			end

		end
		return s .. '}'
	else
		return tostring(o)
	end
end

function get_stack_size_of_item (item_name)
	local item = cached_items[item_name]
	if item == nil then
		--print("LOG: Unable to get stack_size for: " .. item_name)
		return 1
	else
		return item['stack_size']
	end
end

function get_recipe_name(recipe)
	if recipe.name then
		return recipe.name
	elseif recipe.result then
		return recipe.result
	elseif recipe.normal then
		return recipe.normal.result
	else 
		return nil
	end
end

function get_ingredient_name(ingredient)
	local ingredient_name = nil
	if ingredient["name"] ~= nil then
		ingredient_name = ingredient["name"]
	else
		ingredient_name = ingredient[1]
	end

	return ingredient_name
end

function get_recipe_ingredient_parent(recipe)
	if recipe.ingredients then
		return recipe
	elseif recipe.normal then -- for 0.15 for normal and expensive recipes 
		return recipe.normal
	end

	return nil
end


function get_recipe_ingredients(recipe)
	local ingredient_parent = get_recipe_ingredient_parent(recipe)
	if ingredient_parent ~= nil then
		return ingredient_parent.ingredients
	end

	return nil
end


function get_ingredient_depth(recipe, optional_recipes_being_calculated)
	local recipe_name = get_recipe_name(recipe)

	-- check if cached
	local depth = cached_ingredient_depth[recipe_name]
	if depth ~= nil then 
		return depth
	end

	-- calculate and cache
	--print("get_ingredient_depth: " .. dump(optional_recipes_being_calculated))
	return calculate_ingredient_depth(recipe, optional_recipes_being_calculated or {})
end

function get_total_recipies_using_this_recipe(recipe, optional_recipes_being_calculated)
	local recipe_name = get_recipe_name(recipe)

	-- get from cache
	local uses = cached_recipe_uses[recipe_name]
	if uses ~= nil then 
		return uses
	end

	-- calculate
	print("Calculating calculate_recipes_uses: " .. dump(recipe_name) .. " " .. dump(recipe))
	logIndents = logIndents + 1
	local uses = calculate_recipes_uses(recipe, optional_recipes_being_calculated or {})
	logIndents = logIndents - 1

	-- cache
	print("Calculated calculate_recipes_uses: " .. dump(recipe_name) .. ": " .. dump(uses))
	if recipe_name ~= nil then
		local cached = cached_recipe_uses[recipe_name]
		if cached ~= nil then
			cached_recipe_uses[recipe_name] = math.max(uses, cached)
		else
			cached_recipe_uses[recipe_name] = uses
		end
	end

	return uses
end

function calculate_recipes_uses(recipe, recipes_tried)
	local recipe_name = get_recipe_name(recipe)
	recipes_tried[recipe] = true

	-- calculate
	local uses = 0
	for i, r in pairs(cached_recipes) do
		if r ~= nil then
			local r_name = get_recipe_name(r)
			if recipes_tried[r] == nil then
				local recipe_ingredients = get_recipe_ingredients(r)
				for i, ingredient in pairs(recipe_ingredients) do
					local ingredient_name = get_ingredient_name(ingredient)
					if ingredient_name == recipe_name then
						local ingredient_depth = get_total_recipies_using_this_recipe(r, recipes_tried)
						uses = uses + ingredient_depth + 1
						print(dump(recipe_name) .. " used by: " .. dump(r_name) .. " now " .. dump(uses))
					end
				end
			end
		end
	end

	-- return
	return math.max(uses, 1)
end

function calculate_ingredient_depth(recipe, recipes_tried)
	local recipe_name = get_recipe_name(recipe)
	print("Calculating calculate_ingredient_depth: " .. dump(recipe_name) .. " " .. dump(recipe))
	recipes_tried[recipe] = true

	-- calculate
	depth = 0
	local recipe_ingredients = get_recipe_ingredients(recipe)
	print("Ingredients: " .. dump(recipe_ingredients))
	for i, ingredient in pairs(recipe_ingredients) do
		local ingredient_name = get_ingredient_name(ingredient)
		local ingredient_recipe = cached_recipes[ingredient_name] -- steel bar recipe
		if ingredient_recipe then
			if recipes_tried[ingredient_recipe] ~= nil then
				print("LOG: Recursive recipe " .. dump(recipe_name) .. "->" .. dump(ingredient_name))
			else
				depth = math.max(depth, get_ingredient_depth(ingredient_recipe, recipes_tried) + 1)
			end
		end
	end

	-- cache
	print("Calculated max depth: " .. dump(recipe_name) .. ": " .. dump(depth))
	if recipe_name ~= nil then
		cached_ingredient_depth[recipe_name] = depth
	end

	-- return
	return math.max(depth, 1)
end

--- get_total_ingredients_required
-- Gets the total amount of ingredient types required to make this recipe throguh the entire tree
-- @param recipe The recipe we want to get the amount of
-- @param[opt] Used for calculating the amount if it's unknown.
-- @return Total amount required
function get_total_ingredients_required (recipe, optional_recipes_being_calculated)
	local recipe_name = get_recipe_name(recipe)

	-- get from cache if we can
	local total = cached_ingredient_counts[recipe_name]
	if total ~= nil then 
		return total
	end

	-- calculate 
	return calculate_total_ingredients(recipe, optional_recipes_being_calculated or {})
end

function calculate_total_ingredients(recipe, recipes_tried)
	-- flame ammo = crude oil + steel bar
	-- steel bar = iron bar
	local recipe_name = get_recipe_name(recipe)
	print("Calculating total ingredients for: " .. dump(recipe_name) .. " " .. dump(recipe))
	recipes_tried[recipe] = true
	logIndents = logIndents + 1

	-- calculate total ingredients
	total = 0
	local recipe_ingredients = get_recipe_ingredients(recipe)
	for i, ingredient in pairs(recipe_ingredients) do
		-- ingredient for recipe ( steel bar )
		local ingredient_name = get_ingredient_name(ingredient)
		local ingredient_recipe = cached_recipes[ingredient_name] -- steel bar recipe
		if ingredient_recipe then
			if recipes_tried[ingredient_recipe] ~= nil then
				-- this recipe is trying to get the recipe that another relies on. Just ignore it.
				print("LOG: Recursive recipe " .. dump(recipe_name) .. "->" .. dump(ingredient_name))
			else 
				-- not calculated yet
				total = total + calculate_total_ingredients(ingredient_recipe, recipes_tried) + 1
			end
		else
			print("LOG: Did not find recipe for ingredient " .. dump(ingredient_name) .. " for " .. dump(recipe_name))
			total = total + 1
		end
	end

	-- cache for next query
	if recipe_name ~= nil then
		cached_ingredient_counts[recipe_name] = total
	else
		print("No name for recipe to cache ingredient count: " .. dump(recipe))
	end


	print(dump(recipe_name) .. " calculated ingredients: " .. total)
	logIndents = logIndents - 1

	return math.max(total, 1)
end

-----------------------------
-----------------------------
-----------------------------

-- returns parsed data according to what was already in existent
-- returns the name of the recipe output as well as the original table reference
-- returns {name: "x", output: {...}}
function getRecipeResults(recipe)
	local ingredient_parent = get_recipe_ingredient_parent(recipe)
	logIndents = logIndents + 1

	if ingredient_parent.result ~= nil then
		local result = {}
		result[1] = {name=ingredient_parent.result, output=recipe}

		--print("Recipe result: " .. dump(result))
		logIndents = logIndents - 1
		return result
	elseif ingredient_parent.results then
		if next(ingredient_parent.results) ~= nil then
			--print("Recipe result parsing: " .. dump(ingredient_parent.results))
			local resultData = {}
			for i, result in pairs(ingredient_parent.results) do
				local name = result["name"] or result
				resultData[i] = {name=name, output=result}
			end

			--print("Recipe results: " .. dump(resultData))
			logIndents = logIndents - 1
			return resultData
		end
	end

	logIndents = logIndents - 1
	return nil
end

-- Set all amount of ingredients to 1
-- Set total output to total amount of ingredients required
-- Set stack_size to total output * 50
function processRecipe (recipe)
	if recipe == nil then
		return
	end

	local recipe_name = get_recipe_name(recipe)
	print("Processing Recipe: " .. dump(recipe_name) .. " " .. dump(recipe))
	logIndents = logIndents + 1

	-- change all ingredients to 1 if it's set in the settings
	adjustRequiredIngredientAmount(recipe)

	-- change crafting time if needed
	adjustCraftingTime(recipe)

	-- modify how many we get from the recipe 
	local recipeResults = getRecipeResults(recipe);
	if recipeResults ~= nil then
		local recipe_ingredients = get_recipe_ingredients(recipe)
		if recipe_ingredients ~= nil then
			for i, recipeOutputItem in pairs(recipeResults) do
				--print("- output: " .. dump(recipeOutputItem))
				local recipeOutput = recipeOutputItem["output"]
				local outputItem = cached_items[recipeOutputItem["name"]]
				if outputItem then
					-- assign how many of this outputItem we can keep in a single stack
					adjustItemStackSize(outputItem, recipe)

					-- assign total amount crafted
					adjustRecipeOutput(recipe, recipeOutput, outputItem)
				else
					print("No recipe for " .. dump(outputItemName))
				end
			end
		else
			print("Skipping ingredient modification for " .. dump(recipe_name) .. " because there are no ingredients.")
		end
	else
		print("Skipping ingredient modification for " .. dump(recipe_name) .. " because there is no result.")
	end

	logIndents = logIndents - 1
end

function adjustRequiredIngredientAmount(recipe)
	-- make sure we can edit the requirement amount
	local canEdit = settings.startup["sgr-requirements-edit"].value
	if canEdit == false then
		return
	end

	-- edit ingredient requirement amount
	local amount = settings.startup["sgr-requirement-amount"].value;
	local recipe_ingredients = get_recipe_ingredients(recipe)
	for i, ingredient in pairs(recipe_ingredients) do
		if ingredient["amount"] ~= nil then
			ingredient["amount"] = amount
		else
			ingredient[2] = amount
		end
	end

	print(dump(get_recipe_name(recipe)) .. " ingredients = " .. amount)
end

function adjustCraftingTime(recipe)
	-- make sure we can edit the crafting time
	local canEdit = settings.startup["sgr-time-edit"].value
	if canEdit == false then
		return
	end

	-- Get amount according to settings
	local outputType = settings.startup["sgr-time-type"].value
	local currentAmount = getRecipeCraftingTime(recipe)
	local amount = currentAmount
	if outputType == "total-required-ingredients" then
		amount =  get_total_ingredients_required(recipe)
	elseif outputType == "custom" then
		amount = settings.startup["sgr-time-custom-amount"].value
	elseif outputType == "max-recipe-depth" then
		local ingredient_depth = get_ingredient_depth(recipe)
		if ingredient_depth then
			amount = ingredient_depth + 1
		else
			amount = 1
		end
	elseif outputType == "max-recipe-uses" then
		amount = get_total_recipies_using_this_recipe(recipe)
	end

	-- edit ingredient requirement amount
	setRecipeCraftingTime(recipe, amount)
	print(dump(get_recipe_name(recipe)) .. " crafting time = " .. amount)
end

function isItemStackable(item)
	-- all grid items must be stack_size 1
	if item["equipment_grid"] ~= nil then
		return false
	end

	if item["flags"] ~= nil then
		for index, value in ipairs(item["flags"]) do
	        if value == "not-stackable" then
	            return false
	        end
	    end
    end

    return true
end

function adjustItemStackSize(item, recipe)
	--print("Processing stack_size: " .. dump(item))
	if isItemStackable(item) == false then
		print(item["name"] .. " is not stackable... skipping stack size!")
        return
    end

	-- make sure we can edit the stack size
	local canEdit = settings.startup["sgr-stacksize-edit"].value
	if canEdit == false then
		print(item["name"] .. " stacksize is not enabled... skipping stack size!")
		return
	end

	-- get stack size according to settings
	local stack_size = settings.startup["sgr-stacksize"].value
	if settings.startup["sgr-should-multiply-stacksize"].value then
		stack_size = stack_size * math.max(1, get_total_ingredients_required(recipe))
	end
	
	-- change stack size
	local stack_size = math.max(1, math.min(stack_size, 4294967295))
	item["stack_size"] = stack_size

	print(dump(item["name"]) .. " stack_size = " .. stack_size)
end

function getRecipeOutputAmount(recipe, recipeOutput)
	if recipe.result_count ~= nil then
		return recipe.result_count
	elseif recipe.amount ~= nil then
		return recipe.amount
	end

	if recipeOutput.result_count ~= nil then
		return recipeOutput.result_count
	elseif recipeOutput.amount ~= nil then
		return recipeOutput.amount
	end

	return 1
end

function getRecipeCraftingTime(recipe)
	return recipe.energy_required
end

function setRecipeCraftingTime(recipe, amount)
	recipe.energy_required = math.max(amount, 0.1)
end

function setRecipeOutputAmount(recipe, recipeOutput, amount)
	local ingredient_parent = get_recipe_ingredient_parent(recipe)
	local isSet = false

	if ingredient_parent.result_count ~= nil then
		ingredient_parent.result_count = amount
		isSet = true
	end

	local ingredient_buckets = nil
	if ingredient_parent.results then
		ingredient_buckets = ingredient_parent.results
	else
		ingredient_buckets = {}
		ingredient_buckets[1] = ingredient_parent
	end

	for i,bucket in ipairs(ingredient_buckets) do
		if bucket.amount ~= nil then
			bucket.amount = amount
			isSet = true
		end
	end
	
	
	-- fallback
	if isSet == false then
		ingredient_parent.result_count = amount
	end
end

function adjustRecipeOutput(recipe, recipeOutput, item)
	if isItemStackable(item) == false then
		return
	end

	-- make sure we can edit the stack size
	local canEdit = settings.startup["sgr-output-edit"].value
	if canEdit == false then
		print("[adjustRecipeOutput] output editting is disabled. skipping...")
		return
	end

	-- Get amount according to settings
	local outputType = settings.startup["sgr-output-type"].value
	local currentAmount = getRecipeOutputAmount(recipe, recipeOutput)
	if currentAmount == 0 then
		print("[adjustRecipeOutput] output set to 0... skipping in case this item is not meant to be obtained")
		return
	end


	local amount = currentAmount
	if outputType == "total-required-ingredients" then
		amount = get_total_ingredients_required(recipe)
	elseif outputType == "stack-size" then
		amount = item["stack_size"]
	elseif outputType == "custom" then
		amount = settings.startup["sgr-output-custom-amount"].value
	elseif outputType == "max-recipe-uses" then
		amount = get_total_recipies_using_this_recipe(recipe)
	end

	-- set the highest amount if we are allowed to
	-- uses default value if it's higher
	if settings.startup["sgr-output-use-max-default"].value then
		if amount <= currentAmount then
			print("[adjustRecipeOutput] expected amount " .. dump(amount) .. " <= " .. dump(currentAmount) .. ". skipping...")
			return
		end
	end

	-- change amount and clamp to caps
	local output = math.max(1, math.min(amount, 65535))
	setRecipeOutputAmount(recipe, recipeOutput, output)
	print("[adjustRecipeOutput] Output set to " .. dump(output) .. " of " .. dump(recipe))
end

-------------------------------------------
-------------------------------------------
-------------------------------------------


function cacheRecipes()
	for i, recipe in pairs(data.raw.recipe) do
		if recipe.type == "recipe" then
			local recipe_name = get_recipe_name(recipe)
			if recipe_name then
				--print(dump(recipe.subgroup) .. " " .. dump(recipe.category) .. " " .. dump(recipe.results))
				if recipe.subgroup == 'fluid-recipes' and recipe.category == 'oil-processing' then
					-- fluids
					if recipe.result ~= nil then
						--print(dump(recipe.result.name) .. " " .. dump(recipe))
						cached_recipes[recipe.result.name] = recipe
					elseif recipe.results ~= nil then
						for j, result in pairs(recipe.results) do
							--print(dump(result.name) .. " " .. dump(recipe))
							cached_recipes[result.name] = recipe
						end
					end
				else
					-- other
					--print(dump(recipe_name) .. " " .. dump(recipe))
					cached_recipes[recipe_name] = recipe
				end
			else
				--print("Skipped Recipe: " .. dump(recipe))
			end
		else
			--print("Skipped Recipe: " .. dump(recipe))
		end
	end
end

function cacheItems(d)
	for i, item in pairs(d) do
		local t = type(item);
		if t == "table" then
			if item["stack_size"] ~= nil then
				-- change total created amount to total amount of recipes required
				cached_items[item["name"]] = item
			else
				cacheItems(item)
			end
		end	
	end
end

-------------------------------------------
-------------------------------------------
-- Start
-------------------------------------------
-------------------------------------------

--
-- Change recipes
--
cacheRecipes()
cacheItems(data.raw)

--print(dump(data.raw.recipe))

for i, recipe in pairs(data.raw.recipe) do
	local recipe_name = get_recipe_name(recipe)
	local processed = processedRecipes[recipe]
	if recipe.type == "recipe" and processed ~= true then
		processRecipe(recipe)

		---if recipe.subgroup == 'fluid-recipes' and recipe.category == 'oil-processing' then
		---	for j, result in pairs(recipe.results) do
		---		processedRecipes[recipe_name] = true
		---	end
		---else
		processedRecipes[recipe] = true
		---end
	end
end

print("CACHED RECIPES: " .. dump(cached_recipes))
--print("CACHED ITEMS: " .. dump(cached_items))

--print("RESEARCH: " .. dump(data.raw.technology))

--
-- Change research
--


local canEditStackSize = settings.startup["sgr-stacksize-edit"].value
if canEditStackSize then
	for i, tech in pairs(data.raw.technology) do
		if tech.effects ~= nil then
			for j, effect in pairs(tech.effects) do
					-- increase inserter stack size bonus
					if effect.type == "stack-inserter-capacity-bonus" then
						effect.modifier = effect.modifier * settings.startup["sgr-stacksize-inserter"].value
					elseif effect.type == "inserter-stack-size-bonus" then
						effect.modifier = effect.modifier * settings.startup["sgr-stacksize-stack-inserter"].value

					-- robot stack size bonus
					else if effect.type == "worker-robot-storage" then
						effect.modifier = effect.modifier * settings.startup["sgr-stacksize-robot"].value
					end
				end
			end
		end
	end
end