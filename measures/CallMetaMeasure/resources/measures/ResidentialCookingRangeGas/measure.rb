require "#{File.dirname(__FILE__)}/resources/schedules"
require "#{File.dirname(__FILE__)}/resources/constants"
require "#{File.dirname(__FILE__)}/resources/geometry"

#start the measure
class ResidentialCookingRange < OpenStudio::Ruleset::ModelUserScript
  
  def name
    return "Set Residential Gas Cooking Range"
  end
  
  def description
    return "Adds (or replaces) a residential cooking range with the specified efficiency, operation, and schedule in the given space."
  end
  
  def modeler_description
    return "Since there is no Cooking Range object in OpenStudio/EnergyPlus, we look for a GasEquipment or ElectricEquipment object with the name that denotes it is a residential cooking range. If one is found, it is replaced with the specified properties. Otherwise, a new such object is added to the model. Note: This measure requires the number of bedrooms/bathrooms to have already been assigned."
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
	#make a double argument for cooktop EF
	c_ef = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("C_ef", true)
	c_ef.setDisplayName("Cooktop Energy Factor")
	c_ef.setDescription("Cooktop energy factor determined by DOE test procedures for cooking appliances (DOE 1997).")
	c_ef.setDefaultValue(0.4)
	args << c_ef

	#make a double argument for oven EF
	o_ef = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("O_ef", true)
	o_ef.setDisplayName("Oven Energy Factor")
	o_ef.setDescription("Oven energy factor determined by DOE test procedures for cooking appliances (DOE 1997).")
	o_ef.setDefaultValue(0.058)
	args << o_ef
	
	#make a boolean argument for has electric ignition
	e_ignition = OpenStudio::Ruleset::OSArgument::makeBoolArgument("e_ignition", true)
	e_ignition.setDisplayName("Has Electronic Ignition")
	e_ignition.setDescription("For gas/propane cooking ranges with electronic ignition, an extra (40 + 13.3x(#BR)) kWh/yr of electricity will be included.")
	e_ignition.setDefaultValue(true)
	args << e_ignition

	#make a double argument for Occupancy Energy Multiplier
	mult = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("mult", true)
	mult.setDisplayName("Occupancy Energy Multiplier")
	mult.setDescription("Appliance energy use is multiplied by this factor to account for occupancy usage that differs from the national average.")
	mult.setDefaultValue(1)
	args << mult

	#Make a string argument for 24 weekday schedule values
	weekday_sch = OpenStudio::Ruleset::OSArgument::makeStringArgument("weekday_sch", true)
	weekday_sch.setDisplayName("Weekday schedule")
	weekday_sch.setDescription("Specify the 24-hour weekday schedule.")
	weekday_sch.setDefaultValue("0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011")
	args << weekday_sch
    
	#Make a string argument for 24 weekend schedule values
	weekend_sch = OpenStudio::Ruleset::OSArgument::makeStringArgument("weekend_sch", true)
	weekend_sch.setDisplayName("Weekend schedule")
	weekend_sch.setDescription("Specify the 24-hour weekend schedule.")
	weekend_sch.setDefaultValue("0.007, 0.007, 0.004, 0.004, 0.007, 0.011, 0.025, 0.042, 0.046, 0.048, 0.042, 0.050, 0.057, 0.046, 0.057, 0.044, 0.092, 0.150, 0.117, 0.060, 0.035, 0.025, 0.016, 0.011")
	args << weekend_sch

	#Make a string argument for 12 monthly schedule values
	monthly_sch = OpenStudio::Ruleset::OSArgument::makeStringArgument("monthly_sch", true)
	monthly_sch.setDisplayName("Month schedule")
	monthly_sch.setDescription("Specify the 12-month schedule.")
	monthly_sch.setDefaultValue("1.097, 1.097, 0.991, 0.987, 0.991, 0.890, 0.896, 0.896, 0.890, 1.085, 1.085, 1.097")
	args << monthly_sch

    #make a choice argument for space
    spaces = model.getSpaces
    space_args = OpenStudio::StringVector.new
    spaces.each do |space|
        space_args << space.name.to_s
    end
    if space_args.empty?
        space_args << Constants.LivingSpace(1)
    end
    space = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("space", space_args, true)
    space.setDisplayName("Location")
    space.setDescription("Select the space where the cooking range is located")
    if space_args.include?(Constants.LivingSpace(1))
        space.setDefaultValue(Constants.LivingSpace(1))
    end
    args << space

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
	c_ef = runner.getDoubleArgumentValue("C_ef",user_arguments)
	o_ef = runner.getDoubleArgumentValue("O_ef",user_arguments)
	e_ignition = runner.getBoolArgumentValue("e_ignition",user_arguments)
	mult = runner.getDoubleArgumentValue("mult",user_arguments)
	weekday_sch = runner.getStringArgumentValue("weekday_sch",user_arguments)
	weekend_sch = runner.getStringArgumentValue("weekend_sch",user_arguments)
	monthly_sch = runner.getStringArgumentValue("monthly_sch",user_arguments)
	space_r = runner.getStringArgumentValue("space",user_arguments)
	
    #Get space
    space = Geometry.get_space_from_string(model, space_r, runner)
    if space.nil?
        return false
    end

    # Get number of bedrooms/bathrooms
    nbeds, nbaths = Geometry.get_bedrooms_bathrooms(model, runner)
    if nbeds.nil? or nbaths.nil?
        return false
    end
	
	#if oef or cef is defined, must be > 0
	if o_ef <= 0
		runner.registerError("Oven energy factor must be greater than zero.")
		return false
	elsif c_ef <= 0
		runner.registerError("Cooktop energy factor must be greater than zero.")
		return false
	end
    if mult < 0
		runner.registerError("Occupancy energy multiplier must be greater than or equal to 0.")
		return false
    end
    
	#Calculate gas range daily energy use
    range_ann_g = ((2.64 + 0.88 * nbeds) / c_ef + (0.44 + 0.15 * nbeds) / o_ef)*mult # therm/yr
    if e_ignition == true
        range_ann_i = (40 + 13.3 * nbeds)*mult #kWh/yr
    else
        range_ann_i = 0
    end
	
    #hard coded convective, radiative, latent, and lost fractions
	range_lat_e = 0.3
	range_conv_e = 0.16
	range_rad_e = 0.24
	range_lost_e = 1 - range_lat_e - range_conv_e - range_rad_e
	range_lat_g = 0.2
	range_conv_g = 0.12
	range_rad_g = 0.18
	range_lost_g = 1 - range_lat_g - range_conv_g - range_rad_g

	obj_name = Constants.ObjectNameCookingRange
	obj_name_e = obj_name + "_" + Constants.FuelTypeElectric
	obj_name_g = obj_name + "_" + Constants.FuelTypeGas
	obj_name_i = obj_name + "_" + Constants.FuelTypeElectric + "_ignition"
	sch = MonthWeekdayWeekendSchedule.new(weekday_sch, weekend_sch, monthly_sch, model, obj_name, runner)
	if not sch.validated?
		return false
	end
    design_level_g = sch.calcDesignLevelFromDailyTherm(range_ann_g/365.0)
    design_level_i = sch.calcDesignLevelFromDailykWh(range_ann_i/365.0)
    
    # Remove any existing cooking range
    cr_removed = false
    space.electricEquipment.each do |space_equipment|
        if space_equipment.name.to_s == obj_name_e or space_equipment.name.to_s == obj_name_i
            space_equipment.remove
            cr_removed = true
        end
    end
    space.gasEquipment.each do |space_equipment|
        if space_equipment.name.to_s == obj_name_g
            space_equipment.remove
            cr_removed = true
        end
    end
    if cr_removed
        runner.registerInfo("Removed existing cooking range.")
    end

    #Add equipment for the range
    rng_def = OpenStudio::Model::GasEquipmentDefinition.new(model)
    rng = OpenStudio::Model::GasEquipment.new(rng_def)
    rng.setName(obj_name_g)
    rng.setSpace(space)
    rng_def.setName(obj_name_g)
    rng_def.setDesignLevel(design_level_g)
    rng_def.setFractionRadiant(range_rad_g)
    rng_def.setFractionLatent(range_lat_g)
    rng_def.setFractionLost(range_lost_g)
    sch.setSchedule(rng)
    
    if e_ignition == true
        rng_def2 = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
        rng2 = OpenStudio::Model::ElectricEquipment.new(rng_def2)
        rng2.setName(obj_name_i)
        rng2.setSpace(space)
        rng_def2.setName(obj_name_i)
        rng_def2.setDesignLevel(design_level_i)
        rng_def2.setFractionRadiant(range_rad_e)
        rng_def2.setFractionLatent(range_lat_e)
        rng_def2.setFractionLost(range_lost_e)
        sch.setSchedule(rng2)
    end

    #reporting final condition of model
    if e_ignition == true
        runner.registerFinalCondition("A gas range has been set with #{range_ann_g.round} therms and #{range_ann_i.round} kWhs annual energy consumption.")
    else
        runner.registerFinalCondition("A gas range has been set with #{range_ann_g.round} therms annual energy consumption.")
    end
	
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ResidentialCookingRange.new.registerWithApplication