-----------------------------
-- Helper functions
-----------------------------

local cached_items = {}
local cached_recipes = {}
local cached_ingredient_counts = {}
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
			k = '"' .. k .. '"'

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

function get_total_ingredients_required (recipe)
	-- flame ammo = crude oil + steel bar
	-- steel bar = iron bar
	local recipe_name = get_recipe_name(recipe)
	print("Getting total ingredients for: " .. dump(recipe_name))
	logIndents = logIndents + 1

	-- get from cache if we can
	local total = cached_ingredient_counts[get_recipe_name(recipe)]
	if total == nil then 
		-- calculate total ingredients
		total = 0	
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

				if ingredient_recipe == recipe then
					print("LOG: Recursive recipe " .. dump(recipe_name) .. "->" .. dump(ingredient_name))
				else
					local d = nil
					if ingredient_recipe.ingredients then
						d = ingredient_recipe
					elseif ingredient_recipe.normal.ingredients then -- for 0.15 for normal and expensive recipes 
						d = ingredient_recipe.normal 
					end

					total = total + get_total_ingredients_required(d) + 1
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
			print("recipe no name " .. dump(recipe))
		end
	end

	print("total ingredients: " .. total)
	logIndents = logIndents - 1

	-- return at least 1
	return math.max(total, 1)
end

-----------------------------
-----------------------------
-----------------------------

-- Set all amount of ingredients to 1
-- Set total output to total amount of ingredients required
-- Set stack_size to total output * 50
function modifyIngredients (recipe)
	if recipe == nil then
		return
	end

	print("Modifying Recipe: " .. dump(get_recipe_name(recipe)))
	logIndents = logIndents + 1

	-- change all ingredients to 1 if it's set in the settings
	adjustRequiredIngredientAmount(recipe)

	-- modify how many we get from the recipe 
	if recipe.result and recipe.ingredients then

		-- calculate total ingredients needed
		local item = cached_items[recipe.result]
		if item then
			-- get total ingredients needed to make this item
			local totalIngredientTypes = 1
			if item["equipment_grid"] == nil then
				totalIngredientTypes = get_total_ingredients_required(recipe)
			end

			-- assign how many of this item we can keep in a single stack
			adjustItemStackSize(item, totalIngredientTypes)

			-- assign total amount crafted
			adjustRecipeOutput(recipe, item, totalIngredientTypes)
		else
			print("No recipe for " .. dump(recipe.result))
		end
	else
		print("Skipping ingredient modification for " .. dump(get_recipe_name(recipe)))
	end

	logIndents = logIndents - 1
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

function adjustRequiredIngredientAmount(recipe)
	-- make sure we can edit the requirement amount
	local canEdit = settings.startup["sgr-requirements-edit"].value
	if canEdit == false then
		return
	end

	-- edit ingredient requirement amount
	local amount = settings.startup["sgr-requirement-amount"].value;
	for i, ingredient in pairs(recipe.ingredients) do
		if ingredient["amount"] ~= nil then
			ingredient["amount"] = amount
		else
			ingredient[2] = amount
		end
	end

	print(dump(get_recipe_name(recipe)) .. " ingredients = " .. amount)
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

function adjustItemStackSize(item, totalIngredientTypes)
	--print("Processing stack_size: " .. dump(item))
	if isItemStackable(item) == false then
		print(item["name"] .. " is not stackable... skipping stack size!")
        return
    end

	-- make sure we can edit the stack size
	local canEdit = settings.startup["sgr-stacksize-edit"].value
	if canEdit == false then
		return
	end

	-- get stack size according to settings
	local stack_size = settings.startup["sgr-stacksize"].value
	if settings.startup["sgr-should-multiply-stacksize"].value then
		stack_size = stack_size * totalIngredientTypes
	end
	
	-- change stack size
	local stack_size = math.max(1, math.min(stack_size, 4294967295))
	item["stack_size"] = stack_size

	print(dump(item["name"]) .. " stack_size = " .. stack_size)
end

function adjustRecipeOutput(recipe, item, totalIngredientTypes)
	if isItemStackable(item) == false then
		return
	end

	-- make sure we can edit the stack size
	local canEdit = settings.startup["sgr-output-edit"].value
	if canEdit == false then
		return
	end

	-- Get amount according to settings
	local outputType = settings.startup["sgr-output-type"].value
	local amount = recipe.result_count
	if outputType == "total-required-ingredients" then
		amount = totalIngredientTypes
	elseif outputType == "stack-size" then
		amount = item["stack_size"]
	elseif outputType == "custom" then
		amount = settings.startup["sgr-output-custom-amount"].value
	end


	-- change amount and clamp to caps
	local output = math.max(1, math.min(amount, 65535))
	recipe.result_count = output

	print(dump(get_recipe_name(recipe)) .. " output = " .. output)
end

-------------------------------------------
-------------------------------------------
-------------------------------------------


function cacheRecipes()
	for i, recipe in pairs(data.raw.recipe) do
		if recipe.type == "recipe" then
			local recipe_name = get_recipe_name(recipe)
			if recipe_name then
				print(dump(recipe.subgroup) .. " " .. dump(recipe.category))
				if recipe.subgroup == 'fluid-recipes' and recipe.category == 'oil-processing' then
					-- fluids
					for j, result in pairs(recipe.results) do
						print(dump(result.name) .. " " .. dump(recipe))
						cached_recipes[result.name] = recipe
					end
				else
					-- other
					print(dump(recipe_name) .. " " .. dump(recipe))
					cached_recipes[recipe_name] = recipe
				end
			else
				print("Skipped Recipe: " .. dump(recipe))
			end
		else
			print("Skipped Recipe: " .. dump(recipe))
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

print(dump(data.raw.recipe))

for i, recipe in pairs(data.raw.recipe) do
	local processed = processedRecipes[recipe.name]
	if recipe.type == "recipe" and processed ~= true then
		processedRecipe(recipe)

		recipe_name = recipe.name
		if recipe.subgroup == 'fluid-recipes' and recipe.category == 'oil-processing' then
			for j, result in pairs(recipe.results) do
				processedRecipes[result.name] = true
			end
		else
			processedRecipes[recipe.name] = true
		end
	end
end

--print("CACHED RECIPES: " .. dump(cached_recipes))
print("CACHED ITEMS: " .. dump(cached_items))

--
-- Change research
--
for i, tech in pairs(data.raw.technology) do
	if tech.effects ~= nil then
		for j, effect in pairs(tech.effects) do
			if effect.type == "stack-inserter-capacity-bonus" then
				effect.modifier = effect.modifier * 20
			elseif effect.type == "inserter-stack-size-bonus" then
				effect.modifier = effect.modifier * 50
			end
		end
	end
end