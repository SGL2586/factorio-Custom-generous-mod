-----------------------------
-- Helper functions
-----------------------------

local cached_items = {}
local cached_recipes = {}
local processedRecipes = {}

function dump(o)
	if o == nil then
		return 'nil'
	end

	if type(o) == 'table' then
	  local s = '{ '
	  for k,v in pairs(o) do
	     if type(k) ~= 'number' then k = '"'..k..'"' end
	     s = s .. '['..k..'] = ' .. dump(v) .. ','
	  end
	  return s .. '} '
	else
	  return tostring(o)
	end
end

function get_stack_size_of_item (item_name)
	local item = cached_items[item_name]
	if item == nil then
		--log("LOG: Unable to get stack_size for: " .. item_name)
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

function get_total_ingredients_required (recipe)
	-- flame ammo = crude oil + steel bar
	-- steel bar = iron bar

	local total = 0
	for i, ingredient in pairs(recipe.ingredients) do
		-- ingredient for recipe ( steel bar )
		local ingredient_name = nil
		if ingredient["name"] ~= nil then
			ingredient_name = ingredient["name"]
		else
			ingredient_name = ingredient[1]
		end


		local ingredient_recipe = cached_recipes[ingredient_name] -- steel bar recipe
		if ingredient_recipe then

			local d = nil
			if ingredient_recipe.ingredients then
				d = ingredient_recipe
			elseif ingredient_recipe.normal.ingredients then -- for 0.15 for normal and expensive recipes 
				d = ingredient_recipe.normal 
			end

			total = total + get_total_ingredients_required(d) + 1
		else
			--log("LOG: Did not find recipe for " .. (ingredient_name or 'nil'))
			total = total + 1
		end

	end

	return total
end

-----------------------------
-----------------------------
-----------------------------

-- Set all amount of ingredients to 1
-- Set total output to total amount of ingredients required
-- Set stack_size to total output * 50
function modifyIngredients (recipe)
	if recipe then
		-- change all ingredients to 1
		for i, ingredient in pairs(recipe.ingredients) do
			if ingredient["amount"] ~= nil then
				ingredient["amount"] = 1
			else
				ingredient[2] = 1
			end
		end

		-- modify how many we get from the recipe 
		if recipe.result and recipe.ingredients then

			-- calculate total ingredients needed
			local item = cached_items[recipe.result]
			local totalIngredientTypes = get_total_ingredients_required(recipe)
			local stack_size = item["stack_size"]
			if item["equipment_grid"] ~= nil then
				log("StackSize 1: " .. dump(item))
				stack_size = 1
				totalIngredientTypes = 1
			else
				stack_size = totalIngredientTypes * 50
			end

			-- assign total amount crafted
			item["stack_size"] = stack_size
			recipe.result_count = totalIngredientTypes
			log(get_recipe_name(recipe) .. " = " .. totalIngredientTypes)
		else
			--log("Skipping ingredient modification for " .. get_recipe_name(recipe))
		end
	end
end

function processedRecipe(recipe)
	local d = nil
	if recipe.ingredients then
		d = recipe
	elseif recipe.normal.ingredients then -- for 0.15 for normal and expensive recipes 
		d = recipe.normal 
	end

	-- modify recipe
	modifyIngredients(d)
end

-------------------------------------------
-------------------------------------------
-------------------------------------------


function cacheRecipes()
	for i, recipe in pairs(data.raw.recipe) do
		if recipe.type == "recipe" then
			local recipe_name = get_recipe_name(recipe)
			if recipe_name then
				cached_recipes[recipe_name] = recipe
			else
				--log("Skipped Recipe: " .. dump(recipe))
			end
		else
			--log("Skipped Recipe: " .. dump(recipe))
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
-- Start
-------------------------------------------

cacheRecipes()
cacheItems(data.raw)
--log("Finished storing Data:")
--log("CACHED RECIPES: " .. dump(cached_recipes))
--log("CACHED ITEMS: " .. dump(cached_items))

for i, recipe in pairs(data.raw.recipe) do
	local processed = processedRecipes[recipe.name]
	if recipe.type == "recipe" and processed ~= true then
		processedRecipe(recipe)
		processedRecipes[recipe.name] = true
	elseif(processed ~= true) then
		--log("LOG: Skipping: " .. dump(recipe) .. " -> " .. dump(processedRecipes[recipe.name]))
	end
end