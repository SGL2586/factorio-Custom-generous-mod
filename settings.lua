data:extend(
{
	{
		type = "bool-setting",
		name = "sgr-global",
		setting_type = "startup",
		default_value = true,
		order = "1.0"
	},
	{
		type = "int-setting",
		name = "sgr-global-multiplier",
		setting_type = "startup",
		default_value = 1,
        minimum_value = 0,
		order = "1.1"
	},
	{
		type = "bool-setting",
		name = "sgr-global-output-prioritize-max",
		setting_type = "startup",
		default_value = true,
		order = "1.2"
	},
	{
		type = "bool-setting",
		name = "sgr-global-output-exceeds-requirements",
		setting_type = "startup",
		default_value = true,
		order = "1.3"
	},
	{
		type = "bool-setting",
		name = "sgr-stacksize-item-edit",
		setting_type = "startup",
		default_value = false,
		order = "2.0"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-item",
		setting_type = "startup",
		default_value = 50,
		order = "2.1"
	},
	{
		type = "bool-setting",
		name = "sgr-should-multiply-stacksize",
		setting_type = "startup",
		default_value = false,
		order = "2.2"
	},
	{
		type = "bool-setting",
		name = "sgr-stacksize-robot-stacksize-research-edit",
		setting_type = "startup",
		default_value = false,
		order = "2.3"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-robot",
		setting_type = "startup",
		default_value = 1,
        minimum_value = 1,
        maximum_value = 65535,
		order = "2.4"
	},
	{
		type = "bool-setting",
		name = "sgr-stacksize-inserter-stacksize-research-edit",
		setting_type = "startup",
		default_value = true,
		order = "2.5"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-inserter",
		setting_type = "startup",
		default_value = 20,
		order = "2.6"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize-stack-inserter",
		setting_type = "startup",
		default_value = 50,
		order = "2.7"
	},
	{
		type = "bool-setting",
		name = "sgr-output-item-edit",
		setting_type = "startup",
		default_value = true,
		order = "3.1"
	},
	{
	    type = "int-setting",
	    name = "sgr-output-item-multiplier",
	    setting_type = "startup",
        default_value = 10,
        minimum_value = 0,
        maximum_value = 65535,
		order = "3.1",
	},
	{
	    type = "string-setting",
	    name = "sgr-output-item-type",
	    setting_type = "startup",
        default_value = "default",
        allowed_values = {"default", "custom", "total-required-ingredients", "stack-size", "max-recipe-uses"},
		order = "3.2"
	},
	{
	    type = "int-setting",
	    name = "sgr-output-item-custom-amount",
	    setting_type = "startup",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 65535,
		order = "3.3",
	},
	{
		type = "bool-setting",
		name = "sgr-output-fluid-edit",
		setting_type = "startup",
		default_value = true,
		order = "4.0"
	},
	{
	    type = "int-setting",
	    name = "sgr-output-fluid-multiplier",
	    setting_type = "startup",
        default_value = 10,
        minimum_value = 0,
        maximum_value = 65535,
		order = "4.1",
	},
	{
	    type = "string-setting",
	    name = "sgr-output-fluid-type",
	    setting_type = "startup",
        default_value = "default",
        allowed_values = {"default", "custom", "total-required-ingredients", "stack-size", "max-recipe-uses"},
		order = "4.2"
	},
	{
	    type = "int-setting",
	    name = "sgr-output-fluid-custom-amount",
	    setting_type = "startup",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 65535,
		order = "4.3",
	},
	{
		type = "bool-setting",
		name = "sgr-requirements-edit",
		setting_type = "startup",
		default_value = true,
		order = "5.0"
	},
	{
	    type = "int-setting",
	    name = "sgr-requirements-multiplier",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 65535,
		order = "5.1",
	},
	{
	    type = "string-setting",
	    name = "sgr-requirement-item-type",
	    setting_type = "startup",
        default_value = "default",
        allowed_values = {"default", "custom", "total-required-ingredients"},
		order = "5.2"
	},
	{
	    type = "int-setting",
	    name = "sgr-requirement-item-amount",
	    setting_type = "startup",
        default_value = 1,
		order = "5.3"
	},
	{
	    type = "int-setting",
	    name = "sgr-requirement-fluid-amount",
	    setting_type = "startup",
        default_value = 1,
		order = "5.4"
	},
	{
		type = "bool-setting",
		name = "sgr-time-edit",
		setting_type = "startup",
		default_value = false,
		order = "6.0"
	},
	{
	    type = "int-setting",
	    name = "sgr-time-multiplier",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 65535,
		order = "6.1"
	},
	{
	    type = "string-setting",
	    name = "sgr-time-type",
	    setting_type = "startup",
        default_value = "default",
        allowed_values = {"default", "custom", "max-recipe-depth", "total-required-ingredients", "max-recipe-uses"},
		order = "6.2"
	},
	{
	    type = "double-setting",
	    name = "sgr-time-custom-amount",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0.1,
        maximum_value = 65535,
		order = "6.3",
	},
	{
		type = "bool-setting",
		name = "sgr-power-edit",
		setting_type = "startup",
		default_value = false,
		order = "7.0"
	},
	{
	    type = "double-setting",
	    name = "sgr-power-multiplier",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0.01,
        maximum_value = 65535,
		order = "7.1"
	},
	{
	    type = "double-setting",
	    name = "sgr-power-output-multiplier",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0.01,
        maximum_value = 65535,
		order = "7.2"
	},
	{
	    type = "double-setting",
	    name = "sgr-power-requirement-multiplier",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0.01,
        maximum_value = 65535,
		order = "7.3"
	},
	{
	    type = "double-setting",
	    name = "sgr-power-storage-multiplier",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0.01,
        maximum_value = 65535,
		order = "7.4"
	},
	{
	    type = "double-setting",
	    name = "sgr-power-fuel-consumption-multiplier",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 0.01,
        maximum_value = 65535,
		order = "7.5"
	},
})