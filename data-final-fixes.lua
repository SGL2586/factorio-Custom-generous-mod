-----------------------------
-- Setup
-----------------------------

-- cache
local cached_items = {} -- https://wiki.factorio.com/Data.raw#item
local cached_recipes = {}
local cached_ingredient_counts = {} -- {recipe_name: x}}
local cached_recipe_ingredients = {} -- {recipe_name: {recipe_name: x}}
local cached_ingredient_depth = {}
local cached_recipe_uses = {}
local processedRecipes = {}

-- settings
local globalMultiplier = settings.startup["sgr-global-multiplier"].value
local globalTimeMultiplier = settings.startup["sgr-global-time-multiplier"].value
local globalCostMultiplier = settings.startup["sgr-global-cost-multiplier"].value
local globalOutputMultiplier = settings.startup["sgr-global-output-multiplier"].value
local globalOutputPrioritizeMax = settings.startup["sgr-global-output-prioritize-max"].value
local globalOutputEnsureExceedsRequirements = settings.startup["sgr-global-output-exceeds-requirements"].value

local outputItemEditingEnabled = settings.startup["sgr-output-item-edit"].value
local outputItemCalculationType = settings.startup["sgr-output-item-type"].value
local outputItemCustomAmount = settings.startup["sgr-output-item-custom-amount"].value
local outputItemMultiplier = settings.startup["sgr-output-item-multiplier"].value

local outputFluidEditingEnabled = settings.startup["sgr-output-fluid-edit"].value
local outputFluidCalculationType = settings.startup["sgr-output-fluid-type"].value
local outputFluidCustomAmount = settings.startup["sgr-output-fluid-custom-amount"].value
local outputFluidMultiplier = settings.startup["sgr-output-fluid-multiplier"].value

local requirementEditingEnabled = settings.startup["sgr-requirements-edit"].value
local requirementMultiplier = settings.startup["sgr-requirements-multiplier"].value
local requirementCalculationType = settings.startup["sgr-requirement-item-type"].value;
local requirementCustomItemAmount = settings.startup["sgr-requirement-item-amount"].value;
local requirementCustomFluidAmount = settings.startup["sgr-requirement-fluid-amount"].value;

local timeEditingEnabled = settings.startup["sgr-time-edit"].value
local timeMultiplier = settings.startup["sgr-time-multiplier"].value
local timeCalculationType = settings.startup["sgr-time-type"].value
local timeCustomAmount = settings.startup["sgr-time-custom-amount"].value

local stackSizeEditingEnabled = settings.startup["sgr-stacksize-item-edit"].value
local stackSizeItemAmount = settings.startup["sgr-stacksize-item"].value
local stackSizeMultiplyByTotalIngredients = settings.startup["sgr-should-multiply-stacksize"].value

local powerEditingEnabled = settings.startup["sgr-power-edit"].value
local powerMultiplier = settings.startup["sgr-power-multiplier"].value
local powerOutputMultiplier = settings.startup["sgr-power-output-multiplier"].value
local powerRequirementMultiplier = settings.startup["sgr-power-requirement-multiplier"].value
local powerStorageMultiplier = settings.startup["sgr-power-storage-multiplier"].value
local powerFuelConsumptionMultiplier = settings.startup["sgr-power-fuel-consumption-multiplier"].value
local powerRechargeMultiplier = settings.startup["sgr-power-recharge-multiplier"].value

local miningDrillEditingEnabled = settings.startup["sgr-mining-drill-edit"].value
local miningDrillSpeedMultiplier = settings.startup["sgr-mining-drill-speed-multiplier"].value
local miningDrillAreaMultiplier = settings.startup["sgr-mining-drill-area-multiplier"].value

local researchRobotEditingEnabled = settings.startup["sgr-stacksize-robot-stacksize-research-edit"].value
local researchRobotStacksizeBonus = settings.startup["sgr-stacksize-robot"].value

local researchInserterEditingEnabled = settings.startup["sgr-stacksize-inserter-stacksize-research-edit"].value
local researchInserterStacksizeBonus = settings.startup["sgr-stacksize-inserter"].value
local researchStackInserterStacksizeBonus = settings.startup["sgr-stacksize-stack-inserter"].value

local researchEditingEnabled = settings.startup["sgr-research-edit"].value
local researchMultiplier = settings.startup["sgr-research-multiplier"].value
local researchCostMultiplier = settings.startup["sgr-research-cost-multiplier"].value
local researchCostCalculationType = settings.startup["sgr-research-cost-type"].value
local researchCostCustomAmount = settings.startup["sgr-research-cost-custom-amount"].value
local researchCountMultiplier = settings.startup["sgr-research-count-multiplier"].value
local researchCountCalculationType = settings.startup["sgr-research-count-type"].value
local researchCountCustomAmount = settings.startup["sgr-research-count-custom-amount"].value
local researchTimeMultiplier = settings.startup["sgr-research-time-multiplier"].value
local researchTimeCalculationType = settings.startup["sgr-research-time-type"].value
local researchTimeCustomAmount = settings.startup["sgr-research-time-custom-amount"].value
local researchTimeInfiniteCustomAmount = settings.startup["sgr-research-time-infinite-custom-amount"].value


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
	--print("Calculating calculate_recipes_uses: " .. dump(recipe_name) .. " " .. dump(recipe))
	logIndents = logIndents + 1
	local uses = calculate_recipes_uses(recipe, optional_recipes_being_calculated or {})
	logIndents = logIndents - 1

	-- cache
	--print("Calculated calculate_recipes_uses: " .. dump(recipe_name) .. ": " .. dump(uses))
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
						--print(dump(recipe_name) .. " used by: " .. dump(r_name) .. " now " .. dump(uses))
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
	--print("Calculating calculate_ingredient_depth: " .. dump(recipe_name) .. " " .. dump(recipe))
	recipes_tried[recipe] = true

	-- calculate
	depth = 0
	local recipe_ingredients = get_recipe_ingredients(recipe)
	--print("Ingredients: " .. dump(recipe_ingredients))
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
	--print("Calculated max depth: " .. dump(recipe_name) .. ": " .. dump(depth))
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
	if total == nil then 
		-- calculate
		total = calculate_total_ingredients(recipe, optional_recipes_being_calculated or {})
		cached_ingredient_counts[recipe_name] = total
	end
 
	return total
end

function calculate_total_ingredients(recipe, recipes_tried)
	-- flame ammo = crude oil + steel bar
	-- steel bar = iron bar
	local recipe_name = get_recipe_name(recipe)
	--print("Calculating total ingredients for: " .. dump(recipe_name) .. " " .. dump(recipe))
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
				--print("LOG: Recursive recipe " .. dump(recipe_name) .. "->" .. dump(ingredient_name))
			else 
				-- not calculated yet
				total = total + get_total_ingredients_required(ingredient_recipe, recipes_tried) + 1
			end
		else
			--print("LOG: Did not find recipe for ingredient " .. dump(ingredient_name) .. " for " .. dump(recipe_name))
			total = total + 1
		end
	end

	-- cache for next query
	if recipe_name ~= nil then
		cached_ingredient_counts[recipe_name] = total
	else
		--print("No name for recipe to cache ingredient count: " .. dump(recipe))
	end


	--print(dump(recipe_name) .. " calculated ingredients: " .. total)
	logIndents = logIndents - 1

	return math.max(total, 1)
end

-- given an ingredient we want to know how much of said ingredient is required to make this recipe
function get_total_count_of_item_for_recipe (recipe, item_name, optional_recipes_being_calculated)
	local recipe_name = get_recipe_name(recipe)

	-- get from cache if we can
	local recipe_ingredient_data = cached_recipe_ingredients[recipe_name]
	if recipe_ingredient_data == nil then 
		-- calculate it if we haven't done that yet
		recipe_ingredient_data = calculate_total_ingredient_data(recipe, optional_recipes_being_calculated or {})
		--print("[get_total_count_of_item_for_recipe] calculated ingredient data: " .. dump(recipe_ingredient_data))
	end

	-- get all ingredients required to make this item
	local ingredients_data = recipe_ingredient_data["ingredients"]

	-- get amount of the given item_name 
	local ingredient_requirement_amount = ingredients_data[item_name] or 0
	--print("[get_total_count_of_item_for_recipe] " .. dump(get_recipe_name(recipe)) .. " requires: " .. dump(ingredient_requirement_amount) .. " of " .. dump(item_name))
	return ingredient_requirement_amount
end

function calculate_total_ingredient_data(recipe, recipes_tried)
	-- flame ammo = crude oil + steel bar
	-- steel bar = iron bar
	local recipe_name = get_recipe_name(recipe)

	recipes_tried[recipe] = true

	-- return cached data
	if recipe_name ~= nil then
		local temp = cached_recipe_ingredients[recipe_name]
		if temp ~= nil then
			return temp
		end
	end

	--print("[calculate_total_ingredient_data] " .. dump(recipe_name))
	local recipe_data = {total_ingredients_required=0, ingredients={}}
	logIndents = logIndents + 1

	-- calculate total ingredients
	local total = 0
	local recipe_ingredients = get_recipe_ingredients(recipe)
	for i, ingredient in pairs(recipe_ingredients) do
		-- ingredient for recipe ( steel bar )
		local ingredient_name = get_ingredient_name(ingredient)
		local ingredient_amount = getRequiredIngredientAmount(ingredient)
		--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " ingredient: " .. dump(ingredient_name) .. " = " .. dump(ingredient_amount))
		logIndents = logIndents + 1

		--print("LOG: Did not find recipe for ingredient " .. dump(ingredient_name) .. " for " .. dump(recipe_name))
		total = total + 1
		local cached_ingredient_amount = recipe_data["ingredients"][ingredient_name]
		if cached_ingredient_amount ~= nil then
			recipe_data["ingredients"][ingredient_name] = cached_ingredient_amount + ingredient_amount
		else
			recipe_data["ingredients"][ingredient_name] = ingredient_amount + 0
		end

		-- add ingredients
		local ingredient_recipe = cached_recipes[ingredient_name] -- steel bar recipe
		if ingredient_recipe then
			if ingredient_recipe ~= nil and recipes_tried[ingredient_recipe] ~= nil then
				-- this recipe is trying to get the recipe that another relies on. Just ignore it.
				--print("LOG: Recursive recipe " .. dump(recipe_name) .. "->" .. dump(ingredient_name))
			else 
				-- not calculated yet so calculate ingredient
				local ingredient_data = calculate_total_ingredient_data(ingredient_recipe, recipes_tried)
				--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " ingredient_data: " .. dump(ingredient_data))

				-- record total ingredients
				total = total + ingredient_data["total_ingredients_required"]
				--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " total: " .. dump(total))

				-- record ingredients of this ingredient
				local current_data_ingredients = recipe_data["ingredients"]
				local sub_ingredient_data = ingredient_data["ingredients"]
				--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " before ingredient: " .. dump(current_data_ingredients))
				--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " before sub ingredient: " .. dump(sub_ingredient_data))
				for sub_ingredient_name, sub_ingredient_amount in pairs(sub_ingredient_data) do
					--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " sub ingredient: " .. dump(sub_ingredient_name) .. ", " .. dump(sub_ingredient_amount))

					cached_ingredient_amount = current_data_ingredients[sub_ingredient_name]
					if cached_ingredient_amount ~= nil then
						current_data_ingredients[sub_ingredient_name] = cached_ingredient_amount + sub_ingredient_amount
					else
						current_data_ingredients[sub_ingredient_name] = sub_ingredient_amount + 0
					end
				end
				recipe_data["ingredients"] = current_data_ingredients
				--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " after ingredient: " .. dump(current_data_ingredients))
				--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " after sub ingredient: " .. dump(sub_ingredient_data))
			end
		end

		logIndents = logIndents - 1
	end

	total = math.max(total, 1)
	recipe_data["total_ingredients_required"] = total
	--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " total final: " .. dump(total))

	-- cache for next query
	if recipe_name ~= nil then
		cached_recipe_ingredients[recipe_name] = recipe_data
	else
		--print("No name for recipe to cache ingredient count: " .. dump(recipe))
	end


	logIndents = logIndents - 1
	--print("[calculate_total_ingredient_data] " .. dump(recipe_name) .. " Done = " .. dump(recipe_data))

	return recipe_data
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
	if processedRecipes[recipe_name] ~= nil then
		-- already processed
		return
	end

	--print("Processing Recipe: " .. dump(recipe_name) .. " " .. dump(recipe))
	logIndents = logIndents + 1

	-- mark as processed to avoid recursion
	processedRecipes[recipe_name] = true

	-- process dependencies first
	local recipe_ingredients = get_recipe_ingredients(recipe)
	for i, ingredient in pairs(recipe_ingredients) do
		local ingredientName = get_ingredient_name(ingredient)
		if processedRecipes[ingredientName] == nil then
			local ingredientRecipe = cached_recipes[ingredientName]
			--print("Processing dependency: " .. dump(ingredientName) .. " " .. dump(ingredientRecipe))
			processRecipe(ingredientRecipe)
		end
	end

	-- change all ingredients to 1 if it's set in the settings
	--print("Processing Requirements: " .. dump(recipe_name) .. " " .. dump(recipe))
	adjustRequiredIngredientAmount(recipe)

	-- change crafting time if needed
	--print("Processing Crafting time: " .. dump(recipe_name) .. " " .. dump(recipe))
	adjustCraftingTime(recipe)

	-- modify how many we get from the recipe 
	--print("Processing Output: " .. dump(recipe_name) .. " " .. dump(recipe))
	local recipeResults = getRecipeResults(recipe);
	if recipeResults ~= nil then
		if recipe_ingredients ~= nil then
			for i, recipeOutputItem in pairs(recipeResults) do
				--print("- output: " .. dump(recipeOutputItem))
				local recipeOutputName = getRecipeOutputItemName(recipeOutputItem)
				local recipeOutput = recipeOutputItem["output"]
				local outputItem = cached_items[recipeOutputName]
				if outputItem then
					--print("[processRecipe] Got recipe for " .. dump(recipeOutputName) .. " - " .. dump(recipeOutputItem["name"]) .. " = " .. dump(recipeOutputItem))

					-- assign how many of this outputItem we can keep in a single stack
					adjustItemStackSize(outputItem, recipe)

					-- assign total amount crafted
					adjustRecipeOutput(recipe, recipeOutput, outputItem)
				else
					--print("[processRecipe] No recipe for " .. dump(recipeOutputName) .. " - " .. dump(recipeOutput[1]) .. " = " .. dump(recipeOutputItem))
				end
			end
		else
			--print("Skipping ingredient modification for " .. dump(recipe_name) .. " because there are no ingredients.")
		end
	else
		--print("Skipping ingredient modification for " .. dump(recipe_name) .. " because there is no result.")
	end

	logIndents = logIndents - 1
end

function adjustRequiredIngredientAmount(recipe)
	-- make sure we can edit the requirement amount
	local canEdit = requirementEditingEnabled
	if canEdit == false then
		return
	end

	--print("[adjustRequiredIngredientAmount] Adjusting Requirements for: " .. dump(get_recipe_name(recipe)))
	logIndents = logIndents + 1

	-- edit ingredient requirement amount
	local recipe_ingredients = get_recipe_ingredients(recipe)
	for i, ingredient in pairs(recipe_ingredients) do
		--print("[adjustRequiredIngredientAmount] Adjusting ingredient " .. dump(ingredient))
		-- get required amount
		local amount = 1
		if requirementCalculationType == "default" then
			amount = getRequiredIngredientAmount(ingredient)
		elseif requirementCalculationType == "custom" then
			if ingredient["type"] == "fluid" then
				amount = requirementCustomFluidAmount
			else
				amount = requirementCustomItemAmount
			end
		elseif requirementCalculationType == "total-required-ingredients" then
			amount = get_total_ingredients_required(recipe)
		else
			amount = getRequiredIngredientAmount(ingredient)
		end

		-- change ingredient amount
		setRequiredIngredientAmount(ingredient, amount)
	end

	logIndents = logIndents - 1
	--print("[adjustRequiredIngredientAmount] " .. dump(get_recipe_name(recipe)) .. " requirements adjusted to " .. dump(recipe))
end

function setRequiredIngredientAmount(ingredient, amount)
	local scaledAmount = amount * globalMultiplier * requirementMultiplier * globalCostMultiplier

	-- factorio requires minimum of 1
	local ingredientAmount = math.max(1, math.min(scaledAmount, 65535))

	-- true  = {"1":{"1":"stone-brick"}}
	-- false = {"1":{"name":"stone-brick", "amount":5}}
	local isSimpleTable = ingredient["name"] == nil -- {"1":{"1":"stone-brick"}}

	if isSimpleTable then
		if type(ingredient[1]) == "string" then
			ingredient[2] = ingredientAmount
			--print("[setRequiredIngredientAmount] adjusteda " .. dump(ingredient) .. " to " .. dump(ingredientAmount))
		else
			ingredient[1] = ingredientAmount
			--print("[setRequiredIngredientAmount] adjustedb " .. dump(ingredient) .. " to " .. dump(ingredientAmount))
		end
	else
		ingredient["amount"] = ingredientAmount
		--print("[setRequiredIngredientAmount] adjustedc " .. dump(ingredient) .. " to " .. dump(ingredientAmount))
	end

	--print("[adjustRequiredIngredientAmount] Adjusted ingredient " .. dump(ingredient) .. " to " .. dump(ingredientAmount))
end

function getRequiredIngredientAmount(ingredient)
	-- true  = {"1":{"1":"stone-brick"}}
	-- false = {"1":{"name":"stone-brick", "amount":5}}
	local isSimpleTable = ingredient["name"] == nil -- {"1":{"1":"stone-brick"}}

	if isSimpleTable then
		if type(ingredient[1]) == "string" then
			return ingredient[2]
		else
			return ingredient[1]
		end
	else
		return ingredient["amount"]
	end
end

function adjustCraftingTime(recipe)
	-- make sure we can edit the crafting time
	local canEdit = timeEditingEnabled
	if canEdit == false and globalTimeMultiplier == 1 then
		return
	end

	-- Get amount according to settings
	local outputType = timeCalculationType
	local currentAmount = getRecipeCraftingTime(recipe)
	local amount = currentAmount
	if canEdit then
		if outputType == "default" then
			amount = currentAmount
		elseif outputType == "total-required-ingredients" then
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
	end

	-- edit ingredient crafting time
	local scaledAmount = amount * globalTimeMultiplier
	setRecipeCraftingTime(recipe, scaledAmount)
end

function isItemStackable(item)
	if item.stack_size ~= nil then
		-- for some reason there is string type stack_size in some mod
		local stack_size = tonumber(item.stack_size)
		if stack_size == nil then
			return false
		end
		if stack_size <= 1 then
			return false
		end
	end
	
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
		--print(item["name"] .. " is not stackable... skipping stack size!")
        return
    end

    -- item, gun, ammo, armor, repair-tool, tool, item-with-entity-data, capsule, rail-planner, module, spidertron-remote


	-- make sure we can edit the stack size
	local canEdit = stackSizeEditingEnabled
	if canEdit == false then
		--print(item["name"] .. " stacksize is not enabled... skipping stack size!")
		return
	end

	-- skip if this is not meant to change
	local currentAmount = item["stack_size"]
	if currentAmount == 0 then
		--print("[adjustItemStackSize] stack_size set to 0... skipping in case this item is not meant to be obtained")
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

	--print("[adjustItemStackSize] Setting stacksize of " .. dump(item["name"]) .. " to " .. dump(stack_size))
end

function adjustMiningDrill(item)
	-- make sure we can edit the mining speed
	local mining_speed = item["mining_speed"]
	if mining_speed == nil then
		--print(item["name"] .. " has no mining speed!")
		return
	end
	
	local resource_searching_radius = item["resource_searching_radius"]
	if resource_searching_radius == nil then
		print(item["name"] .. " has no resource_searching_radius!")
		return
	end
	
	item["mining_speed"] = mining_speed * miningDrillSpeedMultiplier
	
	local mining_area = math.max(0.1, resource_searching_radius * miningDrillAreaMultiplier)
	item["resource_searching_radius"] = mining_area
	
end

function adjustPower(item)
	-- make sure we can edit the power
	local energy_source = item["energy_source"]
	if energy_source == nil then
		--print(item["name"] .. " power is not enabled... skipping power!")
		return
	end
	--print("[adjustPower] editting power for " .. dump(item["name"]) .. " " .. dump(item))
	logIndents = logIndents + 1

	convert_power("buffer_capacity", energy_source, powerStorageMultiplier) -- personal robotport
	convert_power("input_flow_limit", energy_source, powerStorageMultiplier) -- accumulator
	convert_power("output_flow_limit", energy_source, powerStorageMultiplier) -- accumulator

	convert_power("max_power_output", item, powerOutputMultiplier * globalOutputMultiplier) -- max_power_output
	convert_power("min_power_output", item, powerOutputMultiplier * globalOutputMultiplier) -- min_power_output
	convert_power("recharge_minimum", item, powerRechargeMultiplier * globalOutputMultiplier) -- recharge_minimum (roboport)
	convert_power("production", item, powerOutputMultiplier * globalOutputMultiplier) -- production
	convert_power("power", item, powerOutputMultiplier * globalOutputMultiplier) -- change power output for equipment
	convert_power("charging_energy", item, powerRechargeMultiplier * globalOutputMultiplier)

	convert_power("consumption", item, powerFuelConsumptionMultiplier * globalCostMultiplier) -- fuel consumption

	convert_power("energy_usage", item, powerRequirementMultiplier * globalCostMultiplier) -- change power required to run
	convert_power("drain", energy_source, powerRequirementMultiplier * globalCostMultiplier) -- inserters
	convert_power("energy_per_movement", item, powerRequirementMultiplier * globalCostMultiplier) -- inserters
	convert_power("energy_per_rotation", item, powerRequirementMultiplier * globalCostMultiplier) -- inserters

	-- power output for buildings to avoid changing temporature and whatnot
	local itemEffectivity = item["effectivity"]
	if itemEffectivity ~= nil then
		new_effectivity = itemEffectivity * powerMultiplier * powerOutputMultiplier
		--print("[adjustPower] itemEffectivity set to " .. dump(new_effectivity) .. " from " .. dump(itemEffectivity))
		item["effectivity"] = new_effectivity
	end

	-- nuclear reactor
	local sourceEffectivity = energy_source["effectivity"]
	if sourceEffectivity ~= nil then
		new_effectivity = sourceEffectivity * powerMultiplier * powerOutputMultiplier
		--print("[adjustPower] sourceEffectivity set to " .. dump(new_effectivity) .. " from " .. dump(sourceEffectivity))
		energy_source["effectivity"] = new_effectivity
	end

	-- change attack_parameters
	local attack_parameters = item["attack_parameters"]
	if attack_parameters ~= nil then
		local ammo_type = attack_parameters["ammo_type"]
		if ammo_type ~= nil then
			convert_power("energy_consumption", ammo_type, powerRequirementMultiplier) -- laser turret energy per shot
		end
	end

	logIndents = logIndents - 1
	--print("[adjustPower] finished editting power for " .. dump(item["name"]) .. " " .. dump(item))
end

function convert_power(key_name, item, multiplier)
	local input_string = item[key_name] -- "90mW"
	if input_string ~= nil then
		--print("[adjustPower] multiplying " .. key_name .. ": " .. dump(input_string))
		final_multiplier = powerMultiplier * multiplier
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

	return 1 -- factorio default
end

function getRecipeCraftingTime(recipe)
	if recipe.normal and recipe.normal.energy_required then
		return recipe.normal.energy_required
	elseif recipe.energy_required then
		return recipe.energy_required
	end

	return 0.5 -- factorio default
end

function setRecipeCraftingTime(recipe, amount)
	local scaledTime = amount * globalMultiplier * timeMultiplier
	local t = math.min(math.max(0.1, scaledTime), 65535)

	if recipe.normal then
		recipe.normal.energy_required = t
	else
		-- If the crafting time does not exist in the ingredient type then it's attached to the recipe
		recipe.energy_required = t
	end
	
	--print(dump(get_recipe_name(recipe)) .. " crafting time = " .. dump(t) .. " " .. dump(recipe))
end

function setRecipeOutputAmount(recipe, recipeOutput, outputAmount)
	-- recipeOutput = {"type":"item","name":"pamk3-battmk3","amount":5} 
	-- amount = 10
	-- receipe = {"type":"recipe","name":"rf-pamk3-pamk4","enabled":true,"energy_required":240,"ingredients":{"1":{"type":"item","name":"pamk3-pamk4","amount":2}},"requester_paste_multiplier":1,"icon":"__Power Armor MK3__/graphics/icons/pamk3-pamk4.png","icon_size":64,"icon_mipmaps":4,"category":"recycle-products","subgroup":"recycling","hidden":true,"allow_decomposition":false,"results":{"1":{"type":"item","name":"pamk3-pamk3","amount":1},"2":{"type":"item","name":"pamk3-battmk3","amount":5},"3":{"type":"item","name":"fusion-reactor-equipment","amount":2},"4":{"type":"item","name":"rocket-control-unit","amount":40},"5":{"type":"item","name":"low-density-structure","amount":200}}}
	--print("[adjustRecipeOutput] Pre Output " .. dump(outputAmount) .. " of " .. " output: " .. dump(recipeOutput) .. " recipe: " .. dump(recipe))
	logIndents = logIndents + 1

	if type(recipeOutput) == 'table' and recipeOutput[2] ~= nil then
		recipeOutput[2] = outputAmount
		--print("[adjustRecipeOutput] adjusteda " .. dump(recipeOutput))
	elseif type(recipeOutput) == 'table' and recipeOutput.amount ~= nil then
		recipeOutput.amount = outputAmount
		--print("[adjustRecipeOutput] adjustedb " .. dump(recipeOutput))
	else
		-- output tables that do not have 'amount' require the parent to have the 
		local ingredient_parent = get_recipe_ingredient_parent(recipe)
		--print("[adjustRecipeOutput] adjustedc ingredient_parent " .. dump(ingredient_parent))
		ingredient_parent.result_count = outputAmount
		--print("[adjustRecipeOutput] adjustedc " .. dump(recipeOutput))
	end

	logIndents = logIndents - 1
	--print("[adjustRecipeOutput] Post Output set to " .. dump(outputAmount))
end


function adjustRecipeOutput(recipe, recipeOutput, outputItem)
	--print("[adjustRecipeOutput] outputItem " .. dump(outputItem))
	local outputItemName = get_recipe_name(outputItem)

	if isItemStackable(outputItem) == false then
		--print("[adjustRecipeOutput] skipping non-stackable: " .. dump(outputItem))
		return
	end

	local itemIsFluid = outputItem["type"] == "fluid"

	-- make sure we can edit the stack size
	local canEdit = outputItemEditingEnabled
	if itemIsFluid then
		canEdit = outputFluidEditingEnabled
	end

	if canEdit == false then
		--print("[adjustRecipeOutput] output editting is disabled. skipping...")
		return
	end

	-- Check if we should skip this recipe
	local currentAmount = getRecipeOutputAmount(recipe, recipeOutput)
	if currentAmount == 0 then
		--print("[adjustRecipeOutput] output set to 0... skipping in case this outputItem is not meant to be obtained")
		return
	end

	-- get output amount
	local amount = getAdjustRecipeOutputAmount(recipe, recipeOutput, outputItem, currentAmount)
	if amount == nil then
		--print("[adjustRecipeOutput] could not adjust type due to unknown case... ")
		return
	end
	--print("[adjustRecipeOutput] " .. dump(outputItemName) .. " amount = " .. dump(amount))

	-- scale with multipliers
	if itemIsFluid then
		amount = amount * outputFluidMultiplier * globalMultiplier * globalOutputMultiplier
	else
		amount = amount * outputItemMultiplier * globalMultiplier * globalOutputMultiplier
	end

	-- set the highest amount if we are allowed to
	if globalOutputPrioritizeMax == true then
		amount = math.max(amount, currentAmount)
	end

	-- Make sure we always get more than is required to craft
	if globalOutputEnsureExceedsRequirements == true then
		local maxRequirements = get_total_count_of_item_for_recipe(recipe, outputItemName)
		--print("[adjustRecipeOutput] " .. dump(outputItemName) .. " amount = " .. amount .. " maxRequirements = " .. dump(maxRequirements))
		if maxRequirements > 0 then
			amount = math.max(amount, maxRequirements + 1)
		end
	end

	-- change amount and clamp to caps
	local scaleOutput =  math.max(1, math.min(amount, 65535))
	--print("[adjustRecipeOutput] " .. dump(outputItemName) .. " = " .. scaleOutput)
	setRecipeOutputAmount(recipe, recipeOutput, scaleOutput)
end

function getTotalItemsRequired(recipe, item_name)
	-- make sure we can edit the requirement amount
	local canEdit = requirementEditingEnabled
	if canEdit == false then
		return
	end

	--print("[adjustRequiredIngredientAmount] Adjusting Requirements for: " .. dump(get_recipe_name(recipe)))
	logIndents = logIndents + 1

	-- edit ingredient requirement amount
	local recipe_ingredients = get_recipe_ingredients(recipe)
	for i, ingredient in pairs(recipe_ingredients) do
		--print("[adjustRequiredIngredientAmount] Adjusting ingredient " .. dump(ingredient))
		-- get required amount
		local amount = 1
		if requirementCalculationType == "default" then
			amount = getRequiredIngredientAmount(ingredient)
		elseif requirementCalculationType == "custom" then
			if ingredient["type"] == "fluid" then
				amount = requirementCustomFluidAmount
			else
				amount = requirementCustomItemAmount
			end
		else
			amount = getRequiredIngredientAmount(ingredient)
		end

		-- change ingredient amount
		setRequiredIngredientAmount(ingredient, amount)
	end

	logIndents = logIndents - 1
	--print("[adjustRequiredIngredientAmount] " .. dump(get_recipe_name(recipe)) .. " requirements adjusted to " .. dump(recipe))
end

function getAdjustRecipeOutputAmount(recipe, recipeOutput, outputItem, currentAmount)
	local itemIsFluid = outputItem["type"] == "fluid"

	-- fluid
	if itemIsFluid then
		if outputFluidCalculationType == "default" then
			return currentAmount
		elseif outputFluidCalculationType == "total-required-ingredients" then
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
	if outputItemCalculationType == "default" then
		return currentAmount
	elseif outputItemCalculationType == "total-required-ingredients" then
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

function getAdjustResearchTimeAmount(currentAmount)
	if researchTimeCalculationType == "default" then
		return currentAmount
	elseif researchTimeCalculationType == "custom" then
		return researchTimeCustomAmount
	end

	-- return nothing
	return nil
end

function getAdjustResearchTimeFormulaAmount(currentFormula)
	if researchTimeCalculationType == "default" then
		return currentFormula
	elseif researchTimeCalculationType == "custom" then
		return researchTimeInfiniteCustomAmount
	end

	-- return nothing
	return nil
end

function getAdjustResearchCostAmount(current_amount)
	if researchCostCalculationType == "default" then
		return current_amount
	elseif researchCostCalculationType == "custom" then
		return researchCostCustomAmount
	end

	-- return nothing
	return nil
end

function getAdjustResearchCountAmount(current_amount)
	if researchCountCalculationType == "default" then
		return current_amount
	elseif researchCountCalculationType == "custom" then
		return researchCountCustomAmount
	end

	-- return nothing
	return nil
end


function adjustResearch(tech)
	tech_unit = tech.unit -- https://wiki.factorio.com/Prototype/Technology#unit
		
	-- time
	local current_time = tech_unit.time
	local adjusted_time = getAdjustResearchTimeAmount(current_time) * researchTimeMultiplier * researchMultiplier * globalTimeMultiplier
	tech_unit.time = adjusted_time

	-- How many times we need to get craft the ingredients
	if tech_unit.count ~= nil then
		local current_count = tech_unit.count 
		local adjusted_count = getAdjustResearchCountAmount(current_count) * researchCountMultiplier * researchMultiplier
		tech_unit.count  = math.max(1, math.min(adjusted_count, 65535))
	else
		local current_formula = tech_unit.count_formula
		local adjusted_formula = getAdjustResearchTimeFormulaAmount(current_formula) .. "*" .. researchCountMultiplier .. "*" .. researchMultiplier
		tech_unit.count_formula = adjusted_formula
	end

	-- How many of each ingredient are required
	for index, ingredient in ipairs(tech_unit.ingredients) do
		local current_cost = ingredient[2]
		local adjusted_cost = getAdjustResearchCostAmount(current_cost) * researchCostMultiplier * researchMultiplier * globalCostMultiplier
		ingredient[2] = math.max(1, math.min(adjusted_cost, 65535))
	end
	
	-- Stack research changes
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

-------------------------------------------
-------------------------------------------
-------------------------------------------


function cacheRecipes()
	for i, recipe in pairs(data.raw.recipe) do
		if recipe.type == "recipe" then
			local recipe_name = get_recipe_name(recipe)
			if recipe_name then
				--print(dump(recipe.subgroup) .. " " .. dump(recipe.category) .. " " .. dump(recipe.results))
				cached_recipes[recipe_name] = recipe
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
-- Change Power
--
local canEdit = powerEditingEnabled or miningDrillEditingEnabled
if canEdit == true then
	for type_key, type_value in pairs(data.raw) do
		for key, item in pairs(type_value) do
			if powerEditingEnabled then
				adjustPower(item)
			end
			
			if miningDrillEditingEnabled then
				adjustMiningDrill(item)
			end
		end
	end
end


--
-- Change recipes
--
cacheRecipes()

local items_types_to_cache = {"item", "gun", "ammo", "armor", "repair-tool", "tool", "item-with-entity-data", "capsule", "rail-planner", "module", "spidertron-remote", "fluid", "container", "electric-pole"}
for i, value in ipairs(items_types_to_cache) do
	local item = data.raw[value]
	cacheItems(item)
end

--print(dump(data.raw.recipe))

for recipe_name, recipe in pairs(cached_recipes) do
	processRecipe(recipe)
end

--print("CACHED RECIPES: " .. dump(cached_recipes))
--print("CACHED ITEMS: " .. dump(cached_items))
--print("RESEARCH: " .. dump(data.raw.technology))

--
-- Change research
--
local needsToEditResearch = researchRobotEditingEnabled or researchInserterEditingEnabled or researchEditingEnabled
if needsToEditResearch then
	for i, tech in pairs(data.raw.technology) do
		adjustResearch(tech)
	end
end
