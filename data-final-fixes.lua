-----------------------------
-- Setup
-----------------------------

-- cache
local cached_items = {} -- https://wiki.factorio.com/Data.raw#item
local cached_recipes = {}
local cached_ingredient_counts = {}
local cached_ingredient_depth = {}
local cached_recipe_uses = {}
local processedRecipes = {}

-- settings
local outputItemEditingEnabled = settings.startup["sgr-output-item-edit"].value
local outputItemCalculationType = settings.startup["sgr-output-item-type"].value
local outputItemCustomAmount = settings.startup["sgr-output-item-custom-amount"].value
local outputFluidEditingEnabled = settings.startup["sgr-output-fluid-edit"].value
local outputFluidCalculationType = settings.startup["sgr-output-fluid-type"].value
local outputFluidCustomAmount = settings.startup["sgr-output-fluid-custom-amount"].value

local requirementEditingEnabled = settings.startup["sgr-requirements-edit"].value
local requirementCustomItemAmount = settings.startup["sgr-requirement-item-amount"].value;
local requirementCustomFluidAmount = settings.startup["sgr-requirement-fluid-amount"].value;

local timeEditingEnabled = settings.startup["sgr-time-edit"].value
local timeCalculationType = settings.startup["sgr-time-type"].value
local timeCustomAmount = settings.startup["sgr-time-custom-amount"].value

local stackSizeEditingEnabled = settings.startup["sgr-stacksize-item-edit"].value
local stackSizeItemAmount = settings.startup["sgr-stacksize-item"].value
local stackSizeMultiplyByTotalIngredients = settings.startup["sgr-should-multiply-stacksize"].value

local researchRobotEditingEnabled = settings.startup["sgr-stacksize-robot-stacksize-research-edit"].value
local researchRobotStacksizeBonus = settings.startup["sgr-stacksize-robot"].value

local researchInserterEditingEnabled = settings.startup["sgr-stacksize-inserter-stacksize-research-edit"].value
local researchInserterStacksizeBonus = settings.startup["sgr-stacksize-inserter"].value
local researchStackInserterStacksizeBonus = settings.startup["sgr-stacksize-stack-inserter"].value

-- debug
local enableLogs = false
local logIndents = 0;

-----------------------------
-- Helper functions
-----------------------------

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
	local ingredient_name = ingredient["name"]
	if ingredient_name ~= nil then
		return ingredient_name
	end

	if type(ingredient[1]) == "string" then
		return ingredient[1]
	else
		return ingredient[2]
	end
end

function get_ingredient_type(ingredient)
	local ingredient_type = ingredient["type"]
	if ingredient_type ~= nil then
		return ingredient_type
	end

	local ingredient_name = get_ingredient_name(ingredient)
	if ingredient_name == nil then
		return nil
	end

	local ingredient_item = cached_items[ingredient_name]
	if ingredient_item == nil then
		return nil
	end

	return ingredient_item["type"]
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

function getRecipeOutputItemName(recipeOutputItem)
	local recipeOutput = recipeOutputItem["output"]
	if recipeOutput ~= nil then
		if type(recipeOutput) == 'table' then
			local outputName = recipeOutput["name"]
			if outputName ~= nil then
				return outputName
			else
				return recipeOutput[1]
			end
		else
			return recipeOutput
		end
	end


	local outputItem = cached_items[recipeOutputItem["name"]]
	if outputItem ~= nil then
		return outputItem
	end

	print("Could not find outputItemName for " .. dump(recipeOutputItem))
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
				local recipeOutputName = getRecipeOutputItemName(recipeOutputItem)
				local recipeOutput = recipeOutputItem["output"]
				local outputItem = cached_items[recipeOutputName]
				if outputItem then
					print("[processRecipe] Got recipe for " .. dump(recipeOutputName) .. " - " .. dump(recipeOutputItem["name"]) .. " = " .. dump(recipeOutputItem))

					-- assign how many of this outputItem we can keep in a single stack
					adjustItemStackSize(outputItem, recipe)

					-- assign total amount crafted
					adjustRecipeOutput(recipe, recipeOutput, outputItem)
				else
					print("[processRecipe] No recipe for " .. dump(recipeOutputName) .. " - " .. dump(recipeOutput[1]) .. " = " .. dump(recipeOutputItem))
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
	local canEdit = requirementEditingEnabled
	if canEdit == false then
		return
	end


	print("[adjustRequiredIngredientAmount] Adjusted Requirement for: " .. dump(get_recipe_name(recipe)))
	logIndents = logIndents + 1

	-- edit ingredient requirement amount
	local itemAmount = requirementCustomItemAmount
	local fluidAmount = requirementCustomFluidAmount
	local recipe_ingredients = get_recipe_ingredients(recipe)
	for i, ingredient in pairs(recipe_ingredients) do
		print("[adjustRequiredIngredientAmount] Adjusting ingredient " .. dump(ingredient))
		-- true  = {"1":{"1":"stone-brick"}}
		-- false = {"1":{"name":"stone-brick", "amount":5}}
		local isSimpleTable = ingredient["name"] == nil -- {"1":{"1":"stone-brick"}}
		local name = get_ingredient_name(ingredient)
		local ingredientType = get_ingredient_type(ingredient)


		local amount = requirementCustomItemAmount
		if ingredient["type"] == "fluid" then
			amount = requirementCustomFluidAmount
		end

		if isSimpleTable then
			if type(ingredient[1]) == "string" then
				ingredient[2] = amount
			else
				ingredient[1] = amount
			end
		else
			ingredient["amount"] = amount
		end
		print("[adjustRequiredIngredientAmount] Adjusted ingredient " .. dump(name) .. " to " .. amount)
	end

	logIndents = logIndents - 1
	print("[adjustRequiredIngredientAmount] " .. dump(get_recipe_name(recipe)) .. " requirements adjusted to " .. dump(recipe))
end

function adjustCraftingTime(recipe)
	-- make sure we can edit the crafting time
	local canEdit = timeEditingEnabled
	if canEdit == false then
		return
	end

	-- Get amount according to settings
	local outputType = timeCalculationType
	local currentAmount = getRecipeCraftingTime(recipe)
	local amount = currentAmount
	if outputType == "total-required-ingredients" then
		amount =  get_total_ingredients_required(recipe)
	elseif outputType == "custom" then
		amount = timeCustomAmount
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
	print(dump(get_recipe_name(recipe)) .. " crafting time = " .. amount .. " " .. dump(recipe))
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

    -- item, gun, ammo, armor, repair-tool, tool, item-with-entity-data, capsule, rail-planner, module, spidertron-remote


	-- make sure we can edit the stack size
	local canEdit = stackSizeEditingEnabled
	if canEdit == false then
		print(item["name"] .. " stacksize is not enabled... skipping stack size!")
		return
	end

	-- skip if this is not meant to change
	local currentAmount = item["stack_size"]
	if currentAmount == 0 then
		print("[adjustItemStackSize] stack_size set to 0... skipping in case this item is not meant to be obtained")
		return
	end

	-- get stack size according to settings
	local stack_size = stackSizeItemAmount
	if stackSizeMultiplyByTotalIngredients then
		stack_size = stack_size * math.max(1, get_total_ingredients_required(recipe))
	end
	
	-- change stack size
	local stack_size = math.max(1, math.min(stack_size, 4294967295))
	item["stack_size"] = stack_size

	print("[adjustItemStackSize] Setting stacksize of " .. dump(item["name"]) .. " to " .. dump(stack_size))
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
	local t = math.max(amount, 0.1)

	if recipe.normal then
		recipe.normal.energy_required = t
	end

	if recipe.energy_required then
		recipe.energy_required = t
	end
end

function setRecipeOutputAmount(recipe, recipeOutput, amount)
	local ingredient_parent = get_recipe_ingredient_parent(recipe)
	local isSet = false

	if type(recipeOutput) == 'table' and recipeOutput[2] ~= nil then
		recipeOutput[2] = amount
		isSet = false
	end

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


function adjustRecipeOutput(recipe, recipeOutput, outputItem)
	if isItemStackable(outputItem) == false then
		print("[adjustRecipeOutput] skipping type: " .. dump(outputItem))
		return
	end

	local itemIsFluid = outputItem["type"] == "fluid"
	print("[adjustRecipeOutput] output type: " .. dump(outputItem["type"]))

	-- make sure we can edit the stack size
	local canEdit = outputItemEditingEnabled
	if itemIsFluid then
		canEdit = outputFluidEditingEnabled
	end

	if canEdit == false then
		print("[adjustRecipeOutput] output editting is disabled. skipping...")
		return
	end

	-- Check if we should skip this recipe
	local currentAmount = getRecipeOutputAmount(recipe, recipeOutput)
	if currentAmount == 0 then
		print("[adjustRecipeOutput] output set to 0... skipping in case this outputItem is not meant to be obtained")
		return
	end

	-- get output amount
	local amount = getAdjustRecipeOutputAmount(recipe, recipeOutput, outputItem)
	if amount == nil then
		print("[adjustRecipeOutput] could not adjust type due to unknown case... ")
		return
	end

	-- set the highest amount if we are allowed to
	if amount <= currentAmount then
		print("[adjustRecipeOutput] expected amount " .. dump(amount) .. " <= " .. dump(currentAmount) .. ". skipping...")
		return
	end

	-- change amount and clamp to caps
	local output = math.max(1, math.min(amount, 65535))
	setRecipeOutputAmount(recipe, recipeOutput, output)
	print("[adjustRecipeOutput] Output set to " .. dump(output) .. " of " .. dump(recipe))
end

function getAdjustRecipeOutputAmount(recipe, recipeOutput, outputItem)
	local itemIsFluid = outputItem["type"] == "fluid"

	-- fluid
	if itemIsFluid then
		local amount = currentAmount
		if outputFluidCalculationType == "total-required-ingredients" then
			return get_total_ingredients_required(recipe)
		elseif outputFluidCalculationType == "stack-size" then
			return outputItem["stack_size"]
		elseif outputFluidCalculationType == "custom" then
			return outputFluidCustomAmount
		elseif outputFluidCalculationType == "max-recipe-uses" then
			return get_total_recipies_using_this_recipe(recipe)
		end

		-- return nothing
		return nil
	end

	-- items/tools/ammo... etc
	local amount = currentAmount
	if outputItemCalculationType == "total-required-ingredients" then
		return get_total_ingredients_required(recipe)
	elseif outputItemCalculationType == "stack-size" then
		return outputItem["stack_size"]
	elseif outputItemCalculationType == "custom" then
		return outputItemCustomAmount
	elseif outputItemCalculationType == "max-recipe-uses" then
		return get_total_recipies_using_this_recipe(recipe)
	end

	-- return nothing
	return nil
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
		if type(item) == "table" then
			cached_items[item["name"]] = item
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

local items_types_to_cache = {"item", "gun", "ammo", "armor", "repair-tool", "tool", "item-with-entity-data", "capsule", "rail-planner", "module", "spidertron-remote", "fluid", "container", "electric-pole"}
for i, value in ipairs(items_types_to_cache) do
	cacheItems(data.raw[value])
end

--print(dump(data.raw.recipe))

for i, recipe in pairs(data.raw.recipe) do
	local recipe_name = get_recipe_name(recipe)
	local processed = processedRecipes[recipe]
	if recipe.type == "recipe" and processed ~= true then
		processRecipe(recipe)
		processedRecipes[recipe] = true
		---end
	end
end

--print("CACHED RECIPES: " .. dump(cached_recipes))
print("CACHED ITEMS: " .. dump(cached_items))
--print("RESEARCH: " .. dump(data.raw.technology))

--
-- Change research
--
local needsToEditResearch = researchRobotEditingEnabled or researchInserterEditingEnabled
if needsToEditResearch then
	for i, tech in pairs(data.raw.technology) do
		if tech.effects ~= nil then
			for j, effect in pairs(tech.effects) do
					if researchInserterEditingEnabled then
						-- increase inserter stack size bonus
						if effect.type == "stack-inserter-capacity-bonus" then
							effect.modifier = effect.modifier * researchInserterStacksizeBonus
						elseif effect.type == "inserter-stack-size-bonus" then
							effect.modifier = effect.modifier * researchStackInserterStacksizeBonus
					end

					if researchRobotEditingEnabled then
						-- robot stack size bonus
						if effect.type == "worker-robot-storage" then
							effect.modifier = effect.modifier * researchRobotStacksizeBonus
						end
					end
				end
			end
		end
	end
end

--print(dump(fill))