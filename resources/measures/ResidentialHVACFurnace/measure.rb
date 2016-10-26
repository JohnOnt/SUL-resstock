#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require "#{File.dirname(__FILE__)}/resources/constants"
require "#{File.dirname(__FILE__)}/resources/geometry"
require "#{File.dirname(__FILE__)}/resources/util"
require "#{File.dirname(__FILE__)}/resources/unit_conversions"
require "#{File.dirname(__FILE__)}/resources/hvac"

#start the measure
class ProcessFurnace < OpenStudio::Ruleset::ModelUserScript

  class Supply
    def initialize
    end
    attr_accessor(:static, :cfm_ton, :HPCoolingOversizingFactor, :SpaceConditionedMult, :fan_power, :eff, :min_flow_ratio, :FAN_EIR_FPLR_SPEC_coefficients, :Heat_Capacity, :compressor_speeds, :Zone_Water_Remove_Cap_Ft_DB_RH_Coefficients, :Zone_Energy_Factor_Ft_DB_RH_Coefficients, :Zone_DXDH_PLF_F_PLR_Coefficients, :Number_Speeds, :fanspeed_ratio, :Heat_AirFlowRate, :Cool_AirFlowRate, :Fan_AirFlowRate, :htg_supply_air_temp)
  end

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Set Residential Furnace"
  end
  
  def description
    return "This measure removes any existing HVAC heating components from the building and adds a furnace along with an on/off supply fan to a unitary air loop. For multifamily buildings, the furnace can be set for all units of the building."
  end
  
  def modeler_description
    return "Any heating components or baseboard convective electrics/waters are removed from any existing air/plant loops or zones. Any existing air/plant loops are also removed. An electric or gas heating coil and an on/off supply fan are added to a unitary air loop. The unitary air loop is added to the supply inlet node of the air loop. This air loop is added to a branch for the living zone. A diffuser is added to the branch for the living zone as well as for the finished basement if it exists."
  end   
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a string argument for furnace fuel type
    fuel_display_names = OpenStudio::StringVector.new
    fuel_display_names << Constants.FuelTypeGas
    fuel_display_names << Constants.FuelTypeElectric
    fueltype = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("fuel_type", fuel_display_names, true)
    fueltype.setDisplayName("Fuel Type")
    fueltype.setDescription("Type of fuel used for heating.")
    fueltype.setDefaultValue(Constants.FuelTypeGas)
    args << fueltype
	
    #make an argument for entering furnace installed afue
    afue = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("afue",true)
    afue.setDisplayName("Installed AFUE")
    afue.setUnits("Btu/Btu")
    afue.setDescription("The installed Annual Fuel Utilization Efficiency (AFUE) of the furnace, which can be used to account for performance derating or degradation relative to the rated value.")
    afue.setDefaultValue(0.78)
    args << afue

    #make a string argument for furnace heating output capacity
    cap_display_names = OpenStudio::StringVector.new
    cap_display_names << Constants.SizingAuto
    (5..150).step(5) do |kbtu|
      cap_display_names << "#{kbtu} kBtu/hr"
    end
    furnacecap = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("capacity", cap_display_names, true)
    furnacecap.setDisplayName("Heating Output Capacity")
    furnacecap.setDefaultValue(Constants.SizingAuto)
    args << furnacecap

    #make an argument for entering furnace max supply temp
    maxtemp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_temp",true)
    maxtemp.setDisplayName("Max Supply Temp")
	  maxtemp.setUnits("F")
	  maxtemp.setDescription("Maximum supply air temperature.")
    maxtemp.setDefaultValue(120.0)
    args << maxtemp

    #make an argument for entering furnace installed supply fan power
    fanpower = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_power_installed",true)
    fanpower.setDisplayName("Installed Supply Fan Power")
    fanpower.setUnits("W/cfm")
    fanpower.setDescription("Fan power (in W) per delivered airflow rate (in cfm) of the indoor fan for the maximum fan speed under actual operating conditions.")
    fanpower.setDefaultValue(0.5)
    args << fanpower	
	
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
    furnaceFuelType = runner.getStringArgumentValue("fuel_type",user_arguments)
    furnaceInstalledAFUE = runner.getDoubleArgumentValue("afue",user_arguments)
    furnaceOutputCapacity = runner.getStringArgumentValue("capacity",user_arguments)
    if not furnaceOutputCapacity == Constants.SizingAuto
      furnaceOutputCapacity = OpenStudio::convert(furnaceOutputCapacity.split(" ")[0].to_f,"kBtu/h","Btu/h").get
    end
    furnaceMaxSupplyTemp = runner.getDoubleArgumentValue("max_temp",user_arguments)
    furnaceInstalledSupplyFanPower = runner.getDoubleArgumentValue("fan_power_installed",user_arguments)
    
    # Create the material class instances
    supply = Supply.new

    # _processAirSystem
    
    supply.static = UnitConversion.inH2O2Pa(0.5) # Pascal

    # Flow rate through AC units - hardcoded assumption of 400 cfm/ton
    supply.cfm_ton = 400 # cfm / ton

    supply.HPCoolingOversizingFactor = 1 # Default to a value of 1 (currently only used for MSHPs)
    supply.SpaceConditionedMult = 1 # Default used for central equipment

    # Before we allowed systems with no cooling equipment, the system
    # fan was defined by the cooling equipment option. For systems
    # with only a furnace, the system fan is (for the time being) hard
    # coded here.

    supply.fan_power = furnaceInstalledSupplyFanPower # Based on 2010 BA Benchmark
    supply.eff = OpenStudio::convert(supply.static / supply.fan_power,"cfm","m^3/s").get # Overall Efficiency of the Supply Fan, Motor and Drive
    # self.supply.delta_t = 0.00055000 / units.Btu2kWh(1.0) / (self.mat.air.inside_air_dens * self.mat.air.inside_air_sh * units.hr2min(1.0))
    supply.min_flow_ratio = 1.00000000
    supply.FAN_EIR_FPLR_SPEC_coefficients = [0.00000000, 1.00000000, 0.00000000, 0.00000000]

    supply.htg_supply_air_temp = furnaceMaxSupplyTemp

    hir = get_furnace_hir(furnaceInstalledAFUE)

    # Parasitic Electricity (Source: DOE. (2007). Technical Support Document: Energy Efficiency Program for Consumer Products: "Energy Conservation Standards for Residential Furnaces and Boilers". www.eere.energy.gov/buildings/appliance_standards/residential/furnaces_boilers.html)
    #             FurnaceParasiticElecDict = {Constants.FuelTypeGas     :  76, # W during operation
    #                                         Constants.FuelTypeOil     : 220}
    #             aux_elec = FurnaceParasiticElecDict[furnaceFuelType]
    aux_elec = 0.0 # set to zero until we figure out a way to distribute to the correct end uses (DOE-2 limitation?)    

    supply.compressor_speeds = nil   
    
    # Remove boiler hot water loop if it exists
    HVAC.remove_hot_water_loop(model, runner)    

    # Get building units
    units = Geometry.get_building_units(model, runner)
    if units.nil?
        return false
    end
    
    units.each do |unit|
      unit_num = Geometry.get_unit_number(model, unit, runner)
      thermal_zones = Geometry.get_thermal_zones_from_spaces(unit.spaces)

      control_slave_zones_hash = HVAC.get_control_and_slave_zones(thermal_zones)
      control_slave_zones_hash.each do |control_zone, slave_zones|
      
        # Remove existing equipment
        clg_coil = HVAC.remove_existing_hvac_equipment(model, runner, "Furnace", control_zone)
        
        # _processSystemHeatingCoil
        
        if furnaceFuelType == Constants.FuelTypeElectric

          htg_coil = OpenStudio::Model::CoilHeatingElectric.new(model)
          htg_coil.setName("Furnace Heating Coil_#{unit_num}")
          htg_coil.setEfficiency(1.0 / hir)
          if furnaceOutputCapacity != Constants.SizingAuto
            htg_coil.setNominalCapacity(OpenStudio::convert(furnaceOutputCapacity,"Btu/h","W").get)
          end

        elsif furnaceFuelType != Constants.FuelTypeElectric

          htg_coil = OpenStudio::Model::CoilHeatingGas.new(model)
          htg_coil.setName("Furnace Heating Coil_#{unit_num}")
          htg_coil.setGasBurnerEfficiency(1.0 / hir)
          if furnaceOutputCapacity != Constants.SizingAuto
            htg_coil.setNominalCapacity(OpenStudio::convert(furnaceOutputCapacity,"Btu/h","W").get)
          end

          htg_coil.setParasiticElectricLoad(aux_elec) # set to zero until we figure out a way to distribute to the correct end uses (DOE-2 limitation?)
          htg_coil.setParasiticGasLoad(0)

        end    
        
        # _processSystemFan
        
        supply_fan_availability = OpenStudio::Model::ScheduleConstant.new(model)
        supply_fan_availability.setName("SupplyFanAvailability_#{unit_num}")
        supply_fan_availability.setValue(1)

        fan = OpenStudio::Model::FanOnOff.new(model, supply_fan_availability)
        fan.setName("Supply Fan_#{unit_num}")
        fan.setEndUseSubcategory(Constants.EndUseHVACFan)
        fan.setFanEfficiency(supply.eff)
        fan.setPressureRise(supply.static)
        fan.setMotorEfficiency(1)
        fan.setMotorInAirstreamFraction(1)

        supply_fan_operation = OpenStudio::Model::ScheduleConstant.new(model)
        supply_fan_operation.setName("SupplyFanOperation_#{unit_num}")
        supply_fan_operation.setValue(0)    
      
        # _processSystemAir
        
        air_loop_unitary = OpenStudio::Model::AirLoopHVACUnitarySystem.new(model)
        air_loop_unitary.setName("Forced Air System_#{unit_num}")
        air_loop_unitary.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
        air_loop_unitary.setHeatingCoil(htg_coil)
        if not clg_coil.nil?
          # Add the existing DX central air back in
          air_loop_unitary.setCoolingCoil(clg_coil)
        else
          air_loop_unitary.setSupplyAirFlowRateDuringCoolingOperation(0.0000001) # this is when there is no cooling present
        end
        air_loop_unitary.setSupplyFan(fan)
        air_loop_unitary.setFanPlacement("BlowThrough")
        air_loop_unitary.setSupplyAirFanOperatingModeSchedule(supply_fan_operation)
        air_loop_unitary.setMaximumSupplyAirTemperature(OpenStudio::convert(supply.htg_supply_air_temp,"F","C").get)      
        air_loop_unitary.setSupplyAirFlowRateWhenNoCoolingorHeatingisRequired(0)

        air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
        air_loop.setName("Central Air System_#{unit_num}")
        air_supply_inlet_node = air_loop.supplyInletNode
        air_supply_outlet_node = air_loop.supplyOutletNode
        air_demand_inlet_node = air_loop.demandInletNode
        air_demand_outlet_node = air_loop.demandOutletNode

        air_loop_unitary.addToNode(air_supply_inlet_node)

        runner.registerInfo("Added on/off fan '#{fan.name}' to branch '#{air_loop_unitary.name}' of air loop '#{air_loop.name}'")
        runner.registerInfo("Added heating coil '#{htg_coil.name}' to branch '#{air_loop_unitary.name}' of air loop '#{air_loop.name}'")
        unless clg_coil.nil?
          runner.registerInfo("Added cooling coil '#{clg_coil.name}' to branch '#{air_loop_unitary.name}' of air loop '#{air_loop.name}'")
        end

        air_loop_unitary.setControllingZoneorThermostatLocation(control_zone)

        # _processSystemDemandSideAir
        # Demand Side

        # Supply Air
        zone_splitter = air_loop.zoneSplitter
        zone_splitter.setName("Zone Splitter_#{unit_num}")
        
        zone_mixer = air_loop.zoneMixer
        zone_mixer.setName("Zone Mixer_#{unit_num}")

        diffuser_living = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
        diffuser_living.setName("#{control_zone.name} direct air_#{unit_num}")
        # diffuser_living.setMaximumAirFlowRate(OpenStudio::convert(supply.Living_AirFlowRate,"cfm","m^3/s").get)
        air_loop.addBranchForZone(control_zone, diffuser_living.to_StraightComponent)

        air_loop.addBranchForZone(control_zone)
        runner.registerInfo("Added air loop '#{air_loop.name}' to thermal zone '#{control_zone.name}' of unit #{unit.name.to_s}")
      
        slave_zones.each do |slave_zone|
        
          # Remove existing equipment
          HVAC.remove_existing_hvac_equipment(model, runner, "Furnace", slave_zone)        
        
          diffuser_fbsmt = OpenStudio::Model::AirTerminalSingleDuctUncontrolled.new(model, model.alwaysOnDiscreteSchedule)
          diffuser_fbsmt.setName("#{slave_zone.name} direct air_#{unit_num}")
          # diffuser_fbsmt.setMaximumAirFlowRate(OpenStudio::convert(supply.Living_AirFlowRate,"cfm","m^3/s").get)
          air_loop.addBranchForZone(slave_zone, diffuser_fbsmt.to_StraightComponent)

          air_loop.addBranchForZone(slave_zone)
          runner.registerInfo("Added air loop '#{air_loop.name}' to thermal zone '#{slave_zone.name}' of unit #{unit.name.to_s}")
        
        end    
      
      end
      
    end
	
    return true
 
  end #end the run method

  def get_furnace_hir(furnaceInstalledAFUE)
    # Based on DOE2 Volume 5 Compliance Analysis manual.
    # This is not used until we have a better way of disaggregating AFUE
    # if FurnaceInstalledAFUE <= 0.835:
    #     hir = 1 / (0.2907 * FurnaceInstalledAFUE + 0.5787)
    # else:
    #     hir = 1 / (1.1116 * FurnaceInstalledAFUE - 0.098185)

    hir = 1.0 / furnaceInstalledAFUE
    return hir
  end  
  
end #end the measure

#this allows the measure to be use by the application
ProcessFurnace.new.registerWithApplication