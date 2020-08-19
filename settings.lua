data:extend(
{
	{
		type = "bool-setting",
		name = "sgr-stacksize-item-edit",
		setting_type = "startup",
		default_value = true,
		order = "1.1"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-item",
		setting_type = "startup",
		default_value = 50,
		order = "1.2"
	},
	{
		type = "bool-setting",
		name = "sgr-should-multiply-stacksize",
		setting_type = "startup",
		default_value = true,
		order = "1.3"
	},
	{
		type = "bool-setting",
		name = "sgr-stacksize-robot-stacksize-research-edit",
		setting_type = "startup",
		default_value = true,
		order = "1.4"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-robot",
		setting_type = "startup",
		default_value = 50,
        minimum_value = 1,
        maximum_value = 65535,
		order = "1.5"
	},
	{
		type = "bool-setting",
		name = "sgr-stacksize-inserter-stacksize-research-edit",
		setting_type = "startup",
		default_value = true,
		order = "1.6"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-inserter",
		setting_type = "startup",
		default_value = 20,
		order = "1.7"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-stack-inserter",
		setting_type = "startup",
		default_value = 50,
		order = "1.8"
	},
	{
		type = "bool-setting",
		name = "sgr-output-item-edit",
		setting_type = "startup",
		default_value = true,
		order = "2.1"
	},
	{
	    type = "string-setting",
	    name = "sgr-output-item-type",
	    setting_type = "startup",
        default_value = "custom",
        allowed_values = {"custom", "total-required-ingredients", "stack-size", "max-recipe-uses"},
		order = "2.2"
	},
	{
	    type = "int-setting",
	    name = "sgr-output-item-custom-amount",
	    setting_type = "startup",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 65535,
		order = "2.3",
	},
	{
		type = "bool-setting",
		name = "sgr-output-fluid-edit",
		setting_type = "startup",
		default_value = true,
		order = "2.4"
	},
	{
	    type = "string-setting",
	    name = "sgr-output-fluid-type",
	    setting_type = "startup",
        default_value = "custom",
        allowed_values = {"custom", "total-required-ingredients", "stack-size", "max-recipe-uses"},
		order = "2.5"
	},
	{
	    type = "int-setting",
	    name = "sgr-output-fluid-custom-amount",
	    setting_type = "startup",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 65535,
		order = "2.6",
	},
	{
		type = "bool-setting",
		name = "sgr-requirements-edit",
		setting_type = "startup",
		default_value = true,
		order = "3.1"
	},
	{
	    type = "int-setting",
	    name = "sgr-requirement-item-amount",
	    setting_type = "startup",
        default_value = 1,
		order = "3.2"
	},
	{
	    type = "int-setting",
	    name = "sgr-requirement-fluid-amount",
	    setting_type = "startup",
        default_value = 1,
		order = "3.3"
	},
	{
		type = "bool-setting",
		name = "sgr-time-edit",
		setting_type = "startup",
		default_value = false,
		order = "4.1"
	},
	{
	    type = "string-setting",
	    name = "sgr-time-type",
	    setting_type = "startup",
        default_value = "custom",
        allowed_values = {"custom", "max-recipe-depth", "total-required-ingredients", "max-recipe-uses"},
		order = "4.2"
	},
	{
	    type = "double-setting",
	    name = "sgr-time-custom-amount",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0.1,
		order = "4.3",
	},
})
