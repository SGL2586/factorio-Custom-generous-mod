data:extend(
{
	{
		type = "bool-setting",
		name = "sgr-stacksize-edit",
		setting_type = "startup",
		default_value = true,
		order = "stacksize_a"
	},
	{
		type = "bool-setting",
		name = "sgr-should-multiply-stacksize",
		setting_type = "startup",
		default_value = true,
		order = "stacksize_b"
	},
	{
		type = "int-setting",
		name = "sgr-stacksize",
		setting_type = "startup",
		default_value = 50,
		order = "stacksize_b"
	},
	{
		type = "bool-setting",
		name = "sgr-output-edit",
		setting_type = "startup",
		default_value = true,
		order = "output_a"
	},
	{
	    type = "string-setting",
	    name = "sgr-output-type",
	    setting_type = "startup",
        default_value = "total-required-ingredients",
        allowed_values = {"custom", "total-required-ingredients", "stack-size"},
		order = "output_b"
	},
	{
	    type = "int-setting",
	    name = "sgr-output-custom-amount",
	    setting_type = "startup",
        default_value = 1,
        minimum_value = 1,
        maximum_value = 65535,
		order = "output_c",
	},
	{
	    type = "bool-setting",
	    name = "sgr-output-use-max-default",
	    setting_type = "startup",
		default_value = true,
		order = "output_d"
	},
	{
		type = "bool-setting",
		name = "sgr-requirements-edit",
		setting_type = "startup",
		default_value = true,
		order = "requirements_a"
	},
	{
	    type = "int-setting",
	    name = "sgr-requirement-amount",
	    setting_type = "startup",
        default_value = 1,
		order = "requirements_b"
	}
})
