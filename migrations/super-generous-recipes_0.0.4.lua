-- LUA to execute before migrating from classic to autoprototype version
-- Reload recipes and technologies
function dump(o)
    if o == nil then 
      return 'nil' 
    end

    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end


for i, force in pairs(game.forces) do
    local reset_tech = false
    for j, tech in pairs(force.technologies) do
      if tech.effects ~= nil then
        for j, effect in pairs(tech.effects) do
          if effect.type == "stack-inserter-capacity-bonus" then
            reset_tech = true
          elseif effect.type == "inserter-stack-size-bonus" then
            reset_tech = true
          end
        end
      end
    end

    if reset_tech == true then
      force.reset_technology_effects()
    end
end
