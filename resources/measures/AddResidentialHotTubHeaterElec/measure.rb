require "#{File.dirname(__FILE__)}/resources/schedules"
require "#{File.dirname(__FILE__)}/resources/constants"
require "#{File.dirname(__FILE__)}/resources/geometry"

#start the measure
class ResidentialHotTubHeaterElec < OpenStudio::Ruleset::ModelUserScript
  
  def name
    return "Set Residential Hot Tub Electric Heater"
  end
  
  def description
    return "Adds (or replaces) a residential hot tub heater with the specified efficiency and schedule. The hot tub is assumed to be outdoors. For multifamily buildings, the hot tub heater is set for all units of the building."
  end
  
  def modeler_description
    return "Since there is no Hot Tub Heater object in OpenStudio/EnergyPlus, we look for an ElectricEquipment or GasEquipment object with the name that denotes it is a residential hot tub heater. If one is found, it is replaced with the specified properties. Otherwise, a new such object is added to the model. Note: This measure requires the number of bedrooms/bathrooms to have already been assigned."
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
	#TODO: New argument for demand response for hot tub heaters (alternate schedules if automatic DR control is specified)
	
	#make a double argument for Base Energy Use
	base_energy = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("base_energy")
	base_energy.setDisplayName("Base Energy Use")
    base_energy.setUnits("kWh/yr")
	base_energy.setDescription("The national average (Building America Benchmark) energy use.")
	base_energy.setDefaultValue(1027.3)
	args << base_energy

	#make a double argument for Energy Multiplier
	mult = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("mult")
	mult.setDisplayName("Energy Multiplier")
	mult.setDescription("Sets the annual energy use equal to the base energy use times this multiplier.")
	mult.setDefaultValue(1)
	args << mult
	
    #make a boolean argument for Scale Energy Use
	scale_energy = OpenStudio::Ruleset::OSArgument::makeBoolArgument("scale_energy",true)
	scale_energy.setDisplayName("Scale Energy Use")
	scale_energy.setDescription("If true, scales the energy use relative to a 3-bedroom, 1920 sqft house using the following equation: Fscale = (0.5 + 0.25 x Nbr/3 + 0.25 x FFA/1920) where Nbr is the number of bedrooms and FFA is the finished floor area.")
	scale_energy.setDefaultValue(true)
	args << scale_energy

	#Make a string argument for 24 weekday schedule values
	weekday_sch = OpenStudio::Ruleset::OSArgument::makeStringArgument("weekday_sch")
	weekday_sch.setDisplayName("Weekday schedule")
	weekday_sch.setDescription("Specify the 24-hour weekday schedule.")
	weekday_sch.setDefaultValue("0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024")
	args << weekday_sch
    
	#Make a string argument for 24 weekend schedule values
	weekend_sch = OpenStudio::Ruleset::OSArgument::makeStringArgument("weekend_sch")
	weekend_sch.setDisplayName("Weekend schedule")
	weekend_sch.setDescription("Specify the 24-hour weekend schedule.")
	weekend_sch.setDefaultValue("0.024, 0.029, 0.024, 0.029, 0.047, 0.067, 0.057, 0.024, 0.024, 0.019, 0.015, 0.014, 0.014, 0.014, 0.024, 0.058, 0.126, 0.122, 0.068, 0.061, 0.051, 0.043, 0.024, 0.024")
	args << weekend_sch

	#Make a string argument for 12 monthly schedule values
	monthly_sch = OpenStudio::Ruleset::OSArgument::makeStringArgument("monthly_sch")
	monthly_sch.setDisplayName("Month schedule")
	monthly_sch.setDescription("Specify the 12-month schedule.")
	monthly_sch.setDefaultValue("0.837, 0.835, 1.084, 1.084, 1.084, 1.096, 1.096, 1.096, 1.096, 0.931, 0.925, 0.837")
	args << monthly_sch

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
    base_energy = runner.getDoubleArgumentValue("base_energy",user_arguments)
	mult = runner.getDoubleArgumentValue("mult",user_arguments)
    scale_energy = runner.getBoolArgumentValue("scale_energy",user_arguments)
	weekday_sch = runner.getStringArgumentValue("weekday_sch",user_arguments)
	weekend_sch = runner.getStringArgumentValue("weekend_sch",user_arguments)
	monthly_sch = runner.getStringArgumentValue("monthly_sch",user_arguments)
    
    #check for valid inputs
    if base_energy < 0
		runner.registerError("Base energy use must be greater than or equal to 0.")
		return false
    end
    if mult < 0
		runner.registerError("Energy multiplier must be greater than or equal to 0.")
		return false
    end

    # Get number of units
    num_units = Geometry.get_num_units(model, runner)
    if num_units.nil?
        return false
    end

    # Will we be setting multiple objects?
    set_multiple_objects = false
    if num_units > 1
        set_multiple_objects = true
    end

    #hard coded convective, radiative, latent, and lost fractions
    hth_lat = 0
    hth_rad = 0
    hth_conv = 0
    hth_lost = 1 - hth_lat - hth_rad - hth_conv
    
    tot_hth_ann = 0
    sch = nil
    (1..num_units).to_a.each do |unit_num|
    
        # Get unit beds/baths/spaces
        nbeds, nbaths, unit_spaces = Geometry.get_unit_beds_baths_spaces(model, unit_num, runner)
        if unit_spaces.nil?
            runner.registerError("Could not determine the spaces associated with unit #{unit_num}.")
            return false
        end
        if nbeds.nil? or nbaths.nil?
            runner.registerError("Could not determine number of bedrooms or bathrooms. Run the 'Add Residential Bedrooms And Bathrooms' measure first.")
            return false
        end
        
        # Get unit ffa
        ffa = Geometry.get_unit_finished_floor_area(model, unit_spaces, runner)
        if ffa.nil?
            return false
        end
        
        # Get space
        space = Geometry.get_space_from_string(unit_spaces, Constants.Auto)
        next if space.nil?

        unit_obj_name_e = Constants.ObjectNameHotTubHeater(Constants.FuelTypeElectric, unit_num)
        unit_obj_name_g = Constants.ObjectNameHotTubHeater(Constants.FuelTypeGas, unit_num)
    
        # Remove any existing hot tub heater
        hth_removed = false
        space.electricEquipment.each do |space_equipment|
            if space_equipment.name.to_s == unit_obj_name_e
                space_equipment.remove
                hth_removed = true
            end
        end
        space.gasEquipment.each do |space_equipment|
            if space_equipment.name.to_s == unit_obj_name_g
                space_equipment.remove
                hth_removed = true
            end
        end
        if hth_removed
            runner.registerInfo("Removed existing hot tub heater from outside.")
        end
    
        #Calculate annual energy use
        ann_elec = base_energy * mult # kWh/yr
        
        if scale_energy
            #Scale energy use by num beds and floor area
            constant = ann_elec/2
            nbr_coef = ann_elec/4/3
            ffa_coef = ann_elec/4/1920
            hth_ann = constant + nbr_coef * nbeds + ffa_coef * ffa # kWh/yr
        else
            hth_ann = ann_elec # kWh/yr
        end

        if hth_ann > 0
            
            if sch.nil?
                # Create schedule
                sch = MonthWeekdayWeekendSchedule.new(model, runner, Constants.ObjectNameHotTubHeater(Constants.FuelTypeElectric) + " schedule", weekday_sch, weekend_sch, monthly_sch)
                if not sch.validated?
                    return false
                end
            end
            
            design_level = sch.calcDesignLevelFromDailykWh(hth_ann/365.0)
                    
            #Add electric equipment for the hot tub heater
            hth_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
            hth = OpenStudio::Model::ElectricEquipment.new(hth_def)
            hth.setName(unit_obj_name_e)
            hth.setSpace(space)
            hth_def.setName(unit_obj_name_e)
            hth_def.setDesignLevel(design_level)
            hth_def.setFractionRadiant(hth_rad)
            hth_def.setFractionLatent(hth_lat)
            hth_def.setFractionLost(hth_lost)
            sch.setSchedule(hth)
            
            if set_multiple_objects
                # Report each assignment plus final condition
                runner.registerInfo("A hot tub heater with #{hth_ann.round} kWhs annual energy consumption has been assigned to outside.")
            end
            
            tot_hth_ann += hth_ann
        end
    
    end
	
    #reporting final condition of model
    if tot_hth_ann > 0
        if set_multiple_objects
            runner.registerFinalCondition("The building has been assigned hot tub heaters totaling #{tot_hth_ann.round} kWhs annual energy consumption across #{num_units} units.")
        else
            runner.registerFinalCondition("A hot tub heater with #{tot_hth_ann.round} kWhs annual energy consumption has been assigned to outside.")
        end
    else
        runner.registerFinalCondition("No hot tub heater has been assigned.")
    end
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ResidentialHotTubHeaterElec.new.registerWithApplication