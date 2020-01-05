# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'openstudio'
require_relative "../HPXMLtoOpenStudio/measure"
require_relative "../HPXMLtoOpenStudio/resources/EPvalidator"
require_relative "../HPXMLtoOpenStudio/resources/constructions"
require_relative "../HPXMLtoOpenStudio/resources/hpxml"
require_relative "../HPXMLtoOpenStudio/resources/schedules"
require_relative "../HPXMLtoOpenStudio/resources/waterheater"

require_relative "../BuildResidentialHPXML/resources/geometry"
require_relative "../BuildResidentialHPXML/resources/schedules"
require_relative "../BuildResidentialHPXML/resources/waterheater"

# start the measure
class HPXMLExporter < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    return "HPXML Exporter"
  end

  # human readable description
  def description
    return "Exports residential modeling arguments to HPXML file"
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("weather_station_epw_filename", true)
    arg.setDisplayName("EnergyPlus Weather (EPW) File Path")
    arg.setDescription("Absolute (or relative) path to the EPW file.")
    arg.setDefaultValue("../HPXMLtoOpenStudio/weather/USA_CO_Denver.Intl.AP.725650_TMY3.epw")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("hpxml_output_path", true)
    arg.setDisplayName("HPXML Output File Path")
    arg.setDescription("Absolute (or relative) path of the output HPXML file.")
    args << arg

    arg = OpenStudio::Measure::OSArgument.makeStringArgument("schedules_output_path", true)
    arg.setDisplayName("Schedules Output File Path")
    arg.setDescription("Absolute (or relative) path of the output schedules file.")
    args << arg

    unit_type_choices = OpenStudio::StringVector.new
    unit_type_choices << "single-family detached"
    unit_type_choices << "single-family attached"
    unit_type_choices << "multifamily"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("unit_type", unit_type_choices, true)
    arg.setDisplayName("Geometry: Unit Type")
    arg.setDescription("The type of unit.")
    arg.setDefaultValue("single-family detached")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument("unit_multiplier", true)
    arg.setDisplayName("Geometry: Unit Multiplier")
    arg.setUnits("#")
    arg.setDescription("The number of actual units this single unit represents.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cfa", true)
    arg.setDisplayName("Geometry: Conditioned Floor Area")
    arg.setUnits("ft^2")
    arg.setDescription("The total floor area of the conditioned space (including any conditioned basement floor area).")
    arg.setDefaultValue(2000.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("wall_height", true)
    arg.setDisplayName("Geometry: Wall Height (Per Floor)")
    arg.setUnits("ft")
    arg.setDescription("The height of the living space (and garage) walls.")
    arg.setDefaultValue(8.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument("num_floors", true)
    arg.setDisplayName("Geometry: Number of Floors")
    arg.setUnits("#")
    arg.setDescription("The number of floors above grade.")
    arg.setDefaultValue(2)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("aspect_ratio", true)
    arg.setDisplayName("Geometry: Aspect Ratio")
    arg.setUnits("FB/LR")
    arg.setDescription("The ratio of the front/back wall length to the left/right wall length, excluding any protruding garage wall area.")
    arg.setDefaultValue(2.0)
    args << arg

    level_choices = OpenStudio::StringVector.new
    level_choices << "Bottom"
    level_choices << "Middle"
    level_choices << "Top"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("level", level_choices, true)
    arg.setDisplayName("Geometry: Level")
    arg.setDescription("The level of the unit.")
    arg.setDefaultValue("Bottom")
    args << arg

    horizontal_location_choices = OpenStudio::StringVector.new
    horizontal_location_choices << "Left"
    horizontal_location_choices << "Middle"
    horizontal_location_choices << "Right"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("horizontal_location", horizontal_location_choices, true)
    arg.setDisplayName("Geometry: Horizontal Location")
    arg.setDescription("The horizontal location of the unit when viewing the front of the building.")
    arg.setDefaultValue("Left")
    args << arg

    corridor_position_choices = OpenStudio::StringVector.new
    corridor_position_choices << "Double-Loaded Interior"
    corridor_position_choices << "Single Exterior (Front)"
    corridor_position_choices << "Double Exterior"
    corridor_position_choices << "None"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("corridor_position", corridor_position_choices, true)
    arg.setDisplayName("Geometry: Corridor Position")
    arg.setDescription("The position of the corridor.")
    arg.setDefaultValue("Double-Loaded Interior")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("corridor_width", true)
    arg.setDisplayName("Geometry: Corridor Width")
    arg.setUnits("ft")
    arg.setDescription("The width of the corridor.")
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("inset_width", true)
    arg.setDisplayName("Geometry: Inset Width")
    arg.setUnits("ft")
    arg.setDescription("The width of the inset.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("inset_depth", true)
    arg.setDisplayName("Geometry: Inset Depth")
    arg.setUnits("ft")
    arg.setDescription("The depth of the inset.")
    arg.setDefaultValue(0.0)
    args << arg

    inset_position_choices = OpenStudio::StringVector.new
    inset_position_choices << "Right"
    inset_position_choices << "Left"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("inset_position", inset_position_choices, true)
    arg.setDisplayName("Geometry: Inset Position")
    arg.setDescription("The position of the inset.")
    arg.setDefaultValue("Right")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("balcony_depth", true)
    arg.setDisplayName("Geometry: Balcony Depth")
    arg.setUnits("ft")
    arg.setDescription("The depth of the balcony.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("garage_width", true)
    arg.setDisplayName("Geometry: Garage Width")
    arg.setUnits("ft")
    arg.setDescription("The width of the garage.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("garage_depth", true)
    arg.setDisplayName("Geometry: Garage Depth")
    arg.setUnits("ft")
    arg.setDescription("The depth of the garage.")
    arg.setDefaultValue(20.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("garage_protrusion", true)
    arg.setDisplayName("Geometry: Garage Protrusion")
    arg.setUnits("frac")
    arg.setDescription("The fraction of the garage that is protruding from the living space.")
    arg.setDefaultValue(0.0)
    args << arg

    garage_position_choices = OpenStudio::StringVector.new
    garage_position_choices << "Right"
    garage_position_choices << "Left"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("garage_position", garage_position_choices, true)
    arg.setDisplayName("Geometry: Garage Position")
    arg.setDescription("The position of the garage.")
    arg.setDefaultValue("Right")
    args << arg

    foundation_type_choices = OpenStudio::StringVector.new
    foundation_type_choices << "slab"
    foundation_type_choices << "crawlspace - vented"
    foundation_type_choices << "crawlspace - unvented"
    foundation_type_choices << "basement - unconditioned"
    foundation_type_choices << "basement - conditioned"
    foundation_type_choices << "ambient"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("foundation_type", foundation_type_choices, true)
    arg.setDisplayName("Geometry: Foundation Type")
    arg.setDescription("The foundation type of the building.")
    arg.setDefaultValue("slab")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("foundation_height", true)
    arg.setDisplayName("Geometry: Foundation Height")
    arg.setUnits("ft")
    arg.setDescription("The height of the foundation (e.g., 3ft for crawlspace, 8ft for basement).")
    arg.setDefaultValue(3.0)
    args << arg

    attic_type_choices = OpenStudio::StringVector.new
    attic_type_choices << "attic - vented"
    attic_type_choices << "attic - unvented"
    attic_type_choices << "attic - conditioned"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("attic_type", attic_type_choices, true)
    arg.setDisplayName("Geometry: Attic Type")
    arg.setDescription("The attic type of the building. Ignored if the building has a flat roof.")
    arg.setDefaultValue("attic - vented")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("unconditioned_attic_ceiling_r", true)
    arg.setDisplayName("Unconditioned Attic: Ceiling Insulation Nominal R-value")
    arg.setUnits("h-ft^2-R/Btu")
    arg.setDescription("Refers to the R-value of the insulation and not the overall R-value of the assembly.")
    arg.setDefaultValue(30)
    args << arg

    roof_type_choices = OpenStudio::StringVector.new
    roof_type_choices << "gable"
    roof_type_choices << "hip"
    roof_type_choices << "flat"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("roof_type", roof_type_choices, true)
    arg.setDisplayName("Geometry: Roof Type")
    arg.setDescription("The roof type of the building.")
    arg.setDefaultValue("gable")
    args << arg

    roof_pitch_choices = OpenStudio::StringVector.new
    roof_pitch_choices << "1:12"
    roof_pitch_choices << "2:12"
    roof_pitch_choices << "3:12"
    roof_pitch_choices << "4:12"
    roof_pitch_choices << "5:12"
    roof_pitch_choices << "6:12"
    roof_pitch_choices << "7:12"
    roof_pitch_choices << "8:12"
    roof_pitch_choices << "9:12"
    roof_pitch_choices << "10:12"
    roof_pitch_choices << "11:12"
    roof_pitch_choices << "12:12"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("roof_pitch", roof_pitch_choices, true)
    arg.setDisplayName("Geometry: Roof Pitch")
    arg.setDescription("The roof pitch of the attic. Ignored if the building has a flat roof.")
    arg.setDefaultValue("6:12")
    args << arg

    roof_structure_choices = OpenStudio::StringVector.new
    roof_structure_choices << "truss, cantilever"
    roof_structure_choices << "rafter"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("roof_structure", roof_structure_choices, true)
    arg.setDisplayName("Geometry: Roof Structure")
    arg.setDescription("The roof structure of the building.")
    arg.setDefaultValue("truss, cantilever")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("eaves_depth", true)
    arg.setDisplayName("Geometry: Eaves Depth")
    arg.setUnits("ft")
    arg.setDescription("The eaves depth of the roof.")
    arg.setDefaultValue(2.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("num_bedrooms", true)
    arg.setDisplayName("Geometry: Number of Bedrooms")
    arg.setDescription("Specify the number of bedrooms. Used to determine the energy usage of appliances and plug loads, hot water usage, mechanical ventilation rate, etc.")
    arg.setDefaultValue(3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("num_bathrooms", true)
    arg.setDisplayName("Geometry: Number of Bathrooms")
    arg.setDescription("Specify the number of bathrooms.")
    arg.setDefaultValue(2)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("num_occupants", true)
    arg.setDisplayName("Geometry: Number of Occupants")
    arg.setDescription("Specify the number of occupants. A value of '#{Constants.Auto}' will calculate the average number of occupants from the number of bedrooms. Used to specify the internal gains from people only.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("neighbor_left_offset", true)
    arg.setDisplayName("Neighbor: Left Offset")
    arg.setUnits("ft")
    arg.setDescription("The minimum distance between the simulated house and the neighboring house to the left (not including eaves). A value of zero indicates no neighbors.")
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("neighbor_right_offset", true)
    arg.setDisplayName("Neighbor: Right Offset")
    arg.setUnits("ft")
    arg.setDescription("The minimum distance between the simulated house and the neighboring house to the right (not including eaves). A value of zero indicates no neighbors.")
    arg.setDefaultValue(10.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("neighbor_back_offset", true)
    arg.setDisplayName("Neighbor: Back Offset")
    arg.setUnits("ft")
    arg.setDescription("The minimum distance between the simulated house and the neighboring house to the back (not including eaves). A value of zero indicates no neighbors.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("neighbor_front_offset", true)
    arg.setDisplayName("Neighbor: Front Offset")
    arg.setUnits("ft")
    arg.setDescription("The minimum distance between the simulated house and the neighboring house to the front (not including eaves). A value of zero indicates no neighbors.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("orientation", true)
    arg.setDisplayName("Geometry: Azimuth")
    arg.setUnits("degrees")
    arg.setDescription("The house's azimuth is measured clockwise from due south when viewed from above (e.g., South=0, West=90, North=180, East=270).")
    arg.setDefaultValue(180.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("front_wwr", true)
    arg.setDisplayName("Windows: Front Window-to-Wall Ratio")
    arg.setDescription("The ratio of window area to wall area for the building's front facade. Enter 0 if specifying Front Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("back_wwr", true)
    arg.setDisplayName("Windows: Back Window-to-Wall Ratio")
    arg.setDescription("The ratio of window area to wall area for the building's back facade. Enter 0 if specifying Back Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("left_wwr", true)
    arg.setDisplayName("Windows: Left Window-to-Wall Ratio")
    arg.setDescription("The ratio of window area to wall area for the building's left facade. Enter 0 if specifying Left Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("right_wwr", true)
    arg.setDisplayName("Windows: Right Window-to-Wall Ratio")
    arg.setDescription("The ratio of window area to wall area for the building's right facade. Enter 0 if specifying Right Window Area instead.")
    arg.setDefaultValue(0.18)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("front_window_area", true)
    arg.setDisplayName("Windows: Front Window Area")
    arg.setDescription("The amount of window area on the building's front facade. Enter 0 if specifying Front Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("back_window_area", true)
    arg.setDisplayName("Windows: Back Window Area")
    arg.setDescription("The amount of window area on the building's back facade. Enter 0 if specifying Back Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("left_window_area", true)
    arg.setDisplayName("Windows: Left Window Area")
    arg.setDescription("The amount of window area on the building's left facade. Enter 0 if specifying Left Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("right_window_area", true)
    arg.setDisplayName("Windows: Right Window Area")
    arg.setDescription("The amount of window area on the building's right facade. Enter 0 if specifying Right Window-to-Wall Ratio instead.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("window_ufactor", true)
    arg.setDisplayName("Windows: U-Factor")
    arg.setUnits("Btu/hr-ft^2-R")
    arg.setDescription("The heat transfer coefficient of the windows.")
    arg.setDefaultValue(0.37)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("window_shgc", true)
    arg.setDisplayName("Windows: SHGC")
    arg.setDescription("The ratio of solar heat gain through a glazing system compared to that of an unobstructed opening, for windows.")
    arg.setDefaultValue(0.3)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("window_aspect_ratio", true)
    arg.setDisplayName("Windows: Aspect Ratio")
    arg.setDescription("Ratio of window height to width.")
    arg.setDefaultValue(1.333)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("overhangs_depth", true)
    arg.setDisplayName("Overhangs: Depth")
    arg.setUnits("ft")
    arg.setDescription("Depth of the overhang. The distance from the wall surface in the direction normal to the wall surface.")
    arg.setDefaultValue(2.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("overhangs_front_facade", true)
    arg.setDisplayName("Overhang: Front Facade")
    arg.setDescription("Overhangs: Specifies the presence of overhangs for windows on the front facade.")
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("overhangs_back_facade", true)
    arg.setDisplayName("Overhang: Back Facade")
    arg.setDescription("Overhangs: Specifies the presence of overhangs for windows on the back facade.")
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("overhangs_left_facade", true)
    arg.setDisplayName("Overhang: Left Facade")
    arg.setDescription("Overhangs: Specifies the presence of overhangs for windows on the left facade.")
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("overhangs_right_facade", true)
    arg.setDisplayName("Overhang: Right Facade")
    arg.setDescription("Overhangs: Specifies the presence of overhangs for windows on the right facade.")
    arg.setDefaultValue(true)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("front_skylight_area", true)
    arg.setDisplayName("Skylights: Front Roof Area")
    arg.setDescription("The amount of skylight area on the building's front conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("back_skylight_area", true)
    arg.setDisplayName("Skylights: Back Roof Area")
    arg.setDescription("The amount of skylight area on the building's back conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("left_skylight_area", true)
    arg.setDisplayName("Skylights: Left Roof Area")
    arg.setDescription("The amount of skylight area on the building's left conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("right_skylight_area", true)
    arg.setDisplayName("Skylights: Right Roof Area")
    arg.setDescription("The amount of skylight area on the building's right conditioned roof facade.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("skylight_ufactor", true)
    arg.setDisplayName("Skylights: U-Factor")
    arg.setUnits("Btu/hr-ft^2-R")
    arg.setDescription("The heat transfer coefficient of the skylights.")
    arg.setDefaultValue(0.33)
    args << arg

    skylight_shgc = OpenStudio::Measure::OSArgument::makeDoubleArgument("skylight_shgc", true)
    skylight_shgc.setDisplayName("Skylights: SHGC")
    skylight_shgc.setDescription("The ratio of solar heat gain through a glazing system compared to that of an unobstructed opening, for skylights.")
    skylight_shgc.setDefaultValue(0.45)
    args << skylight_shgc

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("door_area", true)
    arg.setDisplayName("Doors: Area")
    arg.setUnits("ft^2")
    arg.setDescription("The area of the opaque door(s).")
    arg.setDefaultValue(20.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("door_ufactor", true)
    arg.setDisplayName("Doors: U-Factor")
    arg.setUnits("Btu/hr-ft^2-R")
    arg.setDescription("The heat transfer coefficient of the doors adjacent to conditioned space.")
    arg.setDefaultValue(0.2)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("living_ach50", true)
    arg.setDisplayName("Air Leakage: Above-Grade Living ACH50")
    arg.setUnits("1/hr")
    arg.setDescription("Air exchange rate, in Air Changes per Hour at 50 Pascals (ACH50), for above-grade living space (including conditioned attic).")
    arg.setDefaultValue(7)
    args << arg

    heating_system_type_choices = OpenStudio::StringVector.new
    heating_system_type_choices << "none"
    heating_system_type_choices << "Furnace"
    heating_system_type_choices << "WallFurnace"
    heating_system_type_choices << "Boiler"
    heating_system_type_choices << "ElectricResistance"
    heating_system_type_choices << "Stove"
    heating_system_type_choices << "PortableHeater"

    heating_system_fuel_choices = OpenStudio::StringVector.new
    heating_system_fuel_choices << "electricity"
    heating_system_fuel_choices << "natural gas"
    heating_system_fuel_choices << "fuel oil"
    heating_system_fuel_choices << "propane"
    heating_system_fuel_choices << "wood"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heating_system_type_1", heating_system_type_choices, true)
    arg.setDisplayName("Heating System 1: Type")
    arg.setDescription("The type of the first heating (only) system.")
    arg.setDefaultValue("Furnace")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heating_system_fuel_1", heating_system_fuel_choices, true)
    arg.setDisplayName("Heating System 1: Fuel Type")
    arg.setDescription("The fuel type of the first heating (only) system.")
    arg.setDefaultValue("natural gas")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_system_heating_efficiency_1", true)
    arg.setDisplayName("Heating System 1: Rated Efficiency")
    arg.setDescription("The rated efficiency value of the first heating (only) system.")
    arg.setDefaultValue(0.78)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heating_system_heating_capacity_1", true)
    arg.setDisplayName("Heating System 1: Heating Capacity")
    arg.setDescription("The output heating capacity of the first heating system. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_system_fraction_heat_load_served_1", true)
    arg.setDisplayName("Heating System 1: Fraction Heat Load Served")
    arg.setDescription("The heat load served fraction of the first heating (only) system.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heating_system_type_2", heating_system_type_choices, true)
    arg.setDisplayName("Heating System 2: Type")
    arg.setDescription("The type of the second heating (only) system.")
    arg.setDefaultValue("none")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heating_system_fuel_2", heating_system_fuel_choices, true)
    arg.setDisplayName("Heating System 2: Fuel Type")
    arg.setDescription("The fuel type of the second heating (only) system.")
    arg.setDefaultValue("natural gas")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_system_heating_efficiency_2", true)
    arg.setDisplayName("Heating System 2: Rated Efficiency")
    arg.setDescription("The rated efficiency value of the second heating (only) system.")
    arg.setDefaultValue(0.78)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heating_system_heating_capacity_2", true)
    arg.setDisplayName("Heating System 2: Heating Capacity")
    arg.setDescription("The output heating capacity of the second heating system. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_system_fraction_heat_load_served_2", true)
    arg.setDisplayName("Heating System 2: Fraction Heat Load Served")
    arg.setDescription("The heat load served fraction of the second heating (only) system.")
    arg.setDefaultValue(1)
    args << arg

    cooling_system_type_choices = OpenStudio::StringVector.new
    cooling_system_type_choices << "none"
    cooling_system_type_choices << "central air conditioner"
    cooling_system_type_choices << "room air conditioner"
    cooling_system_type_choices << "evaporative cooler"

    cooling_system_fuel_choices = OpenStudio::StringVector.new
    cooling_system_fuel_choices << "electricity"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("cooling_system_type_1", cooling_system_type_choices, true)
    arg.setDisplayName("Cooling System 1: Type")
    arg.setDescription("The type of the first cooling (only) system.")
    arg.setDefaultValue("central air conditioner")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("cooling_system_fuel_1", cooling_system_fuel_choices, true)
    arg.setDisplayName("Cooling System 1: Fuel Type")
    arg.setDescription("The fuel type of the first cooling (only) system.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_system_cooling_efficiency_1", true)
    arg.setDisplayName("Cooling System 1: Rated Efficiency")
    arg.setDescription("The rated efficiency value of the first cooling (only) system. SEER for central air conditioner, EER for room air conditioner, and ignored for evaporative cooler.")
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("cooling_system_cooling_capacity_1", true)
    arg.setDisplayName("Cooling System 1: Cooling Capacity")
    arg.setDescription("The output cooling capacity of the first cooling system. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("tons")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_system_fraction_cool_load_served_1", true)
    arg.setDisplayName("Cooling System 1: Fraction Cool Load Served")
    arg.setDescription("The cool load served fraction of the first cooling (only) system.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("cooling_system_type_2", cooling_system_type_choices, true)
    arg.setDisplayName("Cooling System 2: Type")
    arg.setDescription("The type of the second cooling (only) system.")
    arg.setDefaultValue("none")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("cooling_system_fuel_2", cooling_system_fuel_choices, true)
    arg.setDisplayName("Cooling System 2: Fuel Type")
    arg.setDescription("The fuel type of the second cooling (only) system.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_system_cooling_efficiency_2", true)
    arg.setDisplayName("Cooling System 2: Rated Efficiency")
    arg.setDescription("The rated efficiency value of the second cooling (only) system. SEER for central air conditioner, EER for room air conditioner, and ignored for evaporative cooler.")
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("cooling_system_cooling_capacity_2", true)
    arg.setDisplayName("Cooling System 2: Cooling Capacity")
    arg.setDescription("The output cooling capacity of the second cooling system. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("tons")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_system_fraction_cool_load_served_2", true)
    arg.setDisplayName("Cooling System 2: Fraction Cool Load Served")
    arg.setDescription("The cool load served fraction of the second cooling (only) system.")
    arg.setDefaultValue(1)
    args << arg

    heat_pump_type_choices = OpenStudio::StringVector.new
    heat_pump_type_choices << "none"
    heat_pump_type_choices << "air-to-air"
    heat_pump_type_choices << "mini-split"
    heat_pump_type_choices << "ground-to-air"

    heat_pump_fuel_choices = OpenStudio::StringVector.new
    heat_pump_fuel_choices << "electricity"

    heat_pump_backup_fuel_choices = OpenStudio::StringVector.new
    heat_pump_backup_fuel_choices << "electricity"
    heat_pump_backup_fuel_choices << "natural gas"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heat_pump_type_1", heat_pump_type_choices, true)
    arg.setDisplayName("Heat Pump 1: Type")
    arg.setDescription("The type of the first heat pump.")
    arg.setDefaultValue("none")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heat_pump_fuel_1", heat_pump_fuel_choices, true)
    arg.setDisplayName("Heat Pump 1: Fuel Type")
    arg.setDescription("The fuel type of the first heat pump.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_heating_efficiency_1", true)
    arg.setDisplayName("Heat Pump 1: Rated Heating Efficiency")
    arg.setDescription("The rated heating efficiency value of the first heat pump. HSFP for air-to-air/mini-split and COP for ground-to-air.")
    arg.setDefaultValue(7.7)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_cooling_efficiency_1", true)
    arg.setDisplayName("Heat Pump 1: Rated Cooling Efficiency")
    arg.setDescription("The rated cooling efficiency value of the first heat pump. SEER for air-to-air/mini-split and EER for ground-to-air.")
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heat_pump_heating_capacity_1", true)
    arg.setDisplayName("Heat Pump 1: Heating Capacity")
    arg.setDescription("The output heating capacity of the first heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heat_pump_cooling_capacity_1", true)
    arg.setDisplayName("Heat Pump 1: Cooling Capacity")
    arg.setDescription("The output cooling capacity of the first heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("tons")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_fraction_heat_load_served_1", true)
    arg.setDisplayName("Heat Pump 1: Fraction Heat Load Served")
    arg.setDescription("The heat load served fraction of the first heat pump.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_fraction_cool_load_served_1", true)
    arg.setDisplayName("Heat Pump 1: Fraction Cool Load Served")
    arg.setDescription("The cool load served fraction of the first heat pump.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heat_pump_backup_fuel_1", heat_pump_backup_fuel_choices, true)
    arg.setDisplayName("Heat Pump 1: Backup Fuel Type")
    arg.setDescription("The backup fuel type of the first heat pump.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_backup_heating_efficiency_percent_1", true)
    arg.setDisplayName("Heat Pump 1: Backup Rated Percent")
    arg.setDescription("The backup rated percent value of the first heat pump.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heat_pump_backup_heating_capacity_1", true)
    arg.setDisplayName("Heat Pump 1: Backup Heating Capacity")
    arg.setDescription("The backup output heating capacity of the first heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heat_pump_type_2", heat_pump_type_choices, true)
    arg.setDisplayName("Heat Pump 2: Type")
    arg.setDescription("The type of the second heat pump.")
    arg.setDefaultValue("none")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heat_pump_fuel_2", heat_pump_fuel_choices, true)
    arg.setDisplayName("Heat Pump 2: Fuel Type")
    arg.setDescription("The fuel type of the second heat pump.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_heating_efficiency_2", true)
    arg.setDisplayName("Heat Pump 2: Rated Heating Efficiency")
    arg.setDescription("The rated heating efficiency value of the second heat pump. HSFP for air-to-air/mini-split and COP for ground-to-air.")
    arg.setDefaultValue(7.7)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_cooling_efficiency_2", true)
    arg.setDisplayName("Heat Pump 2: Rated Cooling Efficiency")
    arg.setDescription("The rated cooling efficiency value of the second heat pump. SEER for air-to-air/mini-split and EER for ground-to-air.")
    arg.setDefaultValue(13.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heat_pump_heating_capacity_2", true)
    arg.setDisplayName("Heat Pump 2: Heating Capacity")
    arg.setDescription("The output heating capacity of the second heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heat_pump_cooling_capacity_2", true)
    arg.setDisplayName("Heat Pump 2: Cooling Capacity")
    arg.setDescription("The output cooling capacity of the second heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("tons")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_fraction_heat_load_served_2", true)
    arg.setDisplayName("Heat Pump 2: Fraction Heat Load Served")
    arg.setDescription("The heat load served fraction of the second heat pump.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_fraction_cool_load_served_2", true)
    arg.setDisplayName("Heat Pump 2: Fraction Cool Load Served")
    arg.setDescription("The cool load served fraction of the second heat pump.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("heat_pump_backup_fuel_2", heat_pump_backup_fuel_choices, true)
    arg.setDisplayName("Heat Pump 2: Backup Fuel Type")
    arg.setDescription("The backup fuel type of the second heat pump.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heat_pump_backup_heating_efficiency_percent_2", true)
    arg.setDisplayName("Heat Pump 2: Backup Rated Percent")
    arg.setDescription("The backup rated percent value of the second heat pump.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("heat_pump_backup_heating_capacity_2", true)
    arg.setDisplayName("Heat Pump 2: Backup Heating Capacity")
    arg.setDescription("The backup output heating capacity of the second heat pump. If using '#{Constants.SizingAuto}', the autosizing algorithm will use ACCA Manual S to set the capacity.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_setpoint_temp", true)
    arg.setDisplayName("Heating Setpoint Temperature")
    arg.setDescription("Specify the heating setpoint temperature.")
    arg.setUnits("degrees F")
    arg.setDefaultValue(71)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_setback_temp", true)
    arg.setDisplayName("Heating Setback Temperature")
    arg.setDescription("Specify the heating setback temperature.")
    arg.setUnits("degrees F")
    arg.setDefaultValue(71)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_setback_hours_per_week", true)
    arg.setDisplayName("Heating Setback Hours per Week")
    arg.setDescription("Specify the heating setback number of hours per week value.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("heating_setback_start_hour", true)
    arg.setDisplayName("Heating Setback Start Hour")
    arg.setDescription("Specify the heating setback start hour value. 0 = midnight, 12 = noon")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_setpoint_temp", true)
    arg.setDisplayName("Cooling Setpoint Temperature")
    arg.setDescription("Specify the cooling setpoint temperature.")
    arg.setUnits("degrees F")
    arg.setDefaultValue(76)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_setup_temp", true)
    arg.setDisplayName("Cooling Setup Temperature")
    arg.setDescription("Specify the cooling setup temperature.")
    arg.setUnits("degrees F")
    arg.setDefaultValue(76)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_setup_hours_per_week", true)
    arg.setDisplayName("Cooling Setup Hours per Week")
    arg.setDescription("Specify the cooling setup number of hours per week value.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("cooling_setup_start_hour", true)
    arg.setDisplayName("Cooling Setup Start Hour")
    arg.setDescription("Specify the cooling setup start hour value. 0 = midnight, 12 = noon")
    arg.setDefaultValue(0)
    args << arg

    distribution_system_type_choices = OpenStudio::StringVector.new
    distribution_system_type_choices << "none"
    distribution_system_type_choices << "AirDistribution"
    distribution_system_type_choices << "HydronicDistribution"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("distribution_system_type_1", distribution_system_type_choices, true)
    arg.setDisplayName("Distribution System 1: Type")
    arg.setDescription("The type of the first distribution system.")
    arg.setDefaultValue("AirDistribution")
    args << arg

    duct_leakage_units_choices = OpenStudio::StringVector.new
    duct_leakage_units_choices << "CFM25"
    duct_leakage_units_choices << "Percent"

    duct_location_choices = OpenStudio::StringVector.new
    duct_location_choices << "living space"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("supply_duct_leakage_units_1", duct_leakage_units_choices, true)
    arg.setDisplayName("Supply Duct 1: Leakage Units")
    arg.setDescription("The leakage units of the first supply duct.")
    arg.setDefaultValue("CFM25")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("return_duct_leakage_units_1", duct_leakage_units_choices, true)
    arg.setDisplayName("Return Duct 1: Leakage Units")
    arg.setDescription("The leakage units of the first return duct.")
    arg.setDefaultValue("CFM25")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("supply_duct_leakage_value_1", true)
    arg.setDisplayName("Supply Duct 1: Leakage Value")
    arg.setDescription("The leakage value of the first supply duct.")
    arg.setDefaultValue(75)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("return_duct_leakage_value_1", true)
    arg.setDisplayName("Return Duct 1: Leakage Value")
    arg.setDescription("The leakage value of the first return duct.")
    arg.setDefaultValue(25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("supply_duct_insulation_r_value_1", true)
    arg.setDisplayName("Supply Duct 1: Insulation R-Value")
    arg.setDescription("The insulation r-value of the first supply duct.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("return_duct_insulation_r_value_1", true)
    arg.setDisplayName("Return Duct 2: Insulation R-Value")
    arg.setDescription("The insulation r-value of the first return duct.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("supply_duct_location_1", duct_location_choices, true)
    arg.setDisplayName("Supply Duct 1: Location")
    arg.setDescription("The location of the first supply duct.")
    arg.setDefaultValue("living space")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("return_duct_location_1", duct_location_choices, true)
    arg.setDisplayName("Return Duct 1: Location")
    arg.setDescription("The location of the first return duct.")
    arg.setDefaultValue("living space")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("supply_duct_surface_area_1", true)
    arg.setDisplayName("Supply Duct 1: Surface Area")
    arg.setDescription("The surface area of the first supply duct.")
    arg.setDefaultValue(150)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("return_duct_surface_area_1", true)
    arg.setDisplayName("Return Duct 1: Surface Area")
    arg.setDescription("The surface area of the first return duct.")
    arg.setDefaultValue(50)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("distribution_system_type_2", distribution_system_type_choices, true)
    arg.setDisplayName("Distribution System 2: Type")
    arg.setDescription("The type of the second distribution system.")
    arg.setDefaultValue("none")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("supply_duct_leakage_units_2", duct_leakage_units_choices, true)
    arg.setDisplayName("Supply Duct 2: Leakage Units")
    arg.setDescription("The leakage units of the second supply duct.")
    arg.setDefaultValue("CFM25")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("return_duct_leakage_units_2", duct_leakage_units_choices, true)
    arg.setDisplayName("Return Duct 2: Leakage Units")
    arg.setDescription("The leakage units of the second return duct.")
    arg.setDefaultValue("CFM25")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("supply_duct_leakage_value_2", true)
    arg.setDisplayName("Supply Duct 2: Leakage Value")
    arg.setDescription("The leakage value of the second supply duct.")
    arg.setDefaultValue(75)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("return_duct_leakage_value_2", true)
    arg.setDisplayName("Return Duct 2: Leakage Value")
    arg.setDescription("The leakage value of the second return duct.")
    arg.setDefaultValue(25)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("supply_duct_insulation_r_value_2", true)
    arg.setDisplayName("Supply Duct 2: Insulation R-Value")
    arg.setDescription("The insulation r-value of the second supply duct.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("return_duct_insulation_r_value_2", true)
    arg.setDisplayName("Return Duct 2: Insulation R-Value")
    arg.setDescription("The insulation r-value of the second return duct.")
    arg.setDefaultValue(0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("supply_duct_location_2", duct_location_choices, true)
    arg.setDisplayName("Supply Duct 2: Location")
    arg.setDescription("The location of the second supply duct.")
    arg.setDefaultValue("living space")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("return_duct_location_2", duct_location_choices, true)
    arg.setDisplayName("Return Duct 2: Location")
    arg.setDescription("The location of the second return duct.")
    arg.setDefaultValue("living space")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("supply_duct_surface_area_2", true)
    arg.setDisplayName("Supply Duct 2: Surface Area")
    arg.setDescription("The surface area of the second supply duct.")
    arg.setDefaultValue(150)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("return_duct_surface_area_2", true)
    arg.setDisplayName("Return Duct 2: Surface Area")
    arg.setDescription("The surface area of the second return duct.")
    arg.setDefaultValue(50)
    args << arg

    water_heater_type_choices = OpenStudio::StringVector.new
    water_heater_type_choices << "none"
    water_heater_type_choices << "storage water heater"
    water_heater_type_choices << "instantaneous water heater"
    water_heater_type_choices << "heat pump water heater"

    water_heater_fuel_choices = OpenStudio::StringVector.new
    water_heater_fuel_choices << "electricity"
    water_heater_fuel_choices << "natural gas"
    water_heater_fuel_choices << "fuel oil"
    water_heater_fuel_choices << "propane"

    location_choices = OpenStudio::StringVector.new
    location_choices << Constants.Auto
    location_choices << "living space"
    location_choices << "basement - conditioned"
    location_choices << "basement - unconditioned"
    location_choices << "garage"
    location_choices << "attic - vented"
    location_choices << "attic - unvented"
    location_choices << "crawlspace - vented"
    location_choices << "crawlspace - unvented"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("water_heater_type_1", water_heater_type_choices, true)
    arg.setDisplayName("Water Heater 1: Type")
    arg.setDescription("The type of the first water heater.")
    arg.setDefaultValue("storage water heater")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("water_heater_fuel_type_1", water_heater_fuel_choices, true)
    arg.setDisplayName("Water Heater 1: Fuel Type")
    arg.setDescription("The fuel type of the first water heater.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("water_heater_location_1", location_choices, true)
    arg.setDisplayName("Water Heater 1: Location")
    arg.setDescription("The location of the first water heater.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("water_heater_tank_volume_1", true)
    arg.setDisplayName("Water Heater 1: Tank Volume")
    arg.setDescription("Nominal volume of the of the first water heater tank. Set to #{Constants.Auto} to have volume autosized.")
    arg.setUnits("gal")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("water_heater_fraction_dhw_load_served_1", true)
    arg.setDisplayName("Water Heater 1: Fraction DHW Load Served")
    arg.setDescription("The dhw load served fraction of the first water heater.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("water_heater_heating_capacity_1", true)
    arg.setDisplayName("Water Heater 1: Input Capacity")
    arg.setDescription("The maximum energy input rating of the first water heater. Set to #{Constants.SizingAuto} to have this field autosized.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("water_heater_energy_factor_1", true)
    arg.setDisplayName("Water Heater 1: Rated Energy Factor")
    arg.setDescription("Ratio of useful energy output from the first water heater to the total amount of energy delivered from the water heater.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("water_heater_recovery_efficiency_1", true)
    arg.setDisplayName("Water Heater 1: Recovery Efficiency")
    arg.setDescription("Ratio of energy delivered to the first water to the energy content of the fuel consumed by the water heater. Only used for non-electric water heaters.")
    arg.setUnits("Frac")
    arg.setDefaultValue(0.76)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("water_heater_type_2", water_heater_type_choices, true)
    arg.setDisplayName("Water Heater 2: Type")
    arg.setDescription("The type of the second water heater.")
    arg.setDefaultValue("none")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("water_heater_fuel_type_2", water_heater_fuel_choices, true)
    arg.setDisplayName("Water Heater 2: Fuel Type")
    arg.setDescription("The fuel type of the second water heater.")
    arg.setDefaultValue("electricity")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("water_heater_location_2", location_choices, true)
    arg.setDisplayName("Water Heater 2: Location")
    arg.setDescription("The location of the second water heater.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("water_heater_tank_volume_2", true)
    arg.setDisplayName("Water Heater 2: Tank Volume")
    arg.setDescription("Nominal volume of the of the second water heater tank. Set to #{Constants.Auto} to have volume autosized.")
    arg.setUnits("gal")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("water_heater_fraction_dhw_load_served_2", true)
    arg.setDisplayName("Water Heater 2: Fraction DHW Load Served")
    arg.setDescription("The dhw load served fraction of the second water heater.")
    arg.setDefaultValue(1)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("water_heater_heating_capacity_2", true)
    arg.setDisplayName("Water Heater 2: Input Capacity")
    arg.setDescription("The maximum energy input rating of the second water heater. Set to #{Constants.SizingAuto} to have this field autosized.")
    arg.setUnits("Btu/hr")
    arg.setDefaultValue(Constants.SizingAuto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("water_heater_energy_factor_2", true)
    arg.setDisplayName("Water Heater 2: Rated Energy Factor")
    arg.setDescription("Ratio of useful energy output from the second water heater to the total amount of energy delivered from the water heater.")
    arg.setDefaultValue(Constants.Auto)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("water_heater_recovery_efficiency_2", true)
    arg.setDisplayName("Water Heater 2: Recovery Efficiency")
    arg.setDescription("Ratio of energy delivered to the second water to the energy content of the fuel consumed by the water heater. Only used for non-electric water heaters.")
    arg.setUnits("Frac")
    arg.setDefaultValue(0.76)
    args << arg

    hot_water_distribution_system_type_choices = OpenStudio::StringVector.new
    hot_water_distribution_system_type_choices << "Standard"
    hot_water_distribution_system_type_choices << "Recirculation"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("hot_water_distribution_system_type", hot_water_distribution_system_type_choices, true)
    arg.setDisplayName("Hot Water Distribution: System Type")
    arg.setDescription("The type of the hot water distribution system.")
    arg.setDefaultValue("Standard")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("standard_piping_length", true)
    arg.setDisplayName("Hot Water Distribution: Standard Piping Length")
    arg.setUnits("ft")
    arg.setDescription("The length of the standard piping.")
    arg.setDefaultValue(50)
    args << arg

    recirculation_control_type_choices = OpenStudio::StringVector.new
    recirculation_control_type_choices << "no control"
    recirculation_control_type_choices << "timer"
    recirculation_control_type_choices << "temperature"
    recirculation_control_type_choices << "presence sensor demand control"
    recirculation_control_type_choices << "manual demand control"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("recirculation_control_type", recirculation_control_type_choices, true)
    arg.setDisplayName("Hot Water Distribution: Recirculation Control Type")
    arg.setDescription("The type of hot water recirculation control, if any.")
    arg.setDefaultValue("no control")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("recirculation_piping_length", true)
    arg.setDisplayName("Hot Water Distribution: Recirculation Piping Length")
    arg.setUnits("ft")
    arg.setDescription("The length of the recirculation piping.")
    arg.setDefaultValue(50)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("recirculation_branch_piping_length", true)
    arg.setDisplayName("Hot Water Distribution: Recirculation Branch Piping Length")
    arg.setUnits("ft")
    arg.setDescription("The length of the recirculation branch piping.")
    arg.setDefaultValue(50)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("recirculation_pump_power", true)
    arg.setDisplayName("Hot Water Distribution: Recirculation Pump Power")
    arg.setUnits("W")
    arg.setDescription("The power of the recirculation pump.")
    arg.setDefaultValue(50)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("hot_water_distribution_pipe_r_value", true)
    arg.setDisplayName("Hot Water Distribution: Insulation Nominal R-Value")
    arg.setUnits("h-ft^2-R/Btu")
    arg.setDescription("Nominal R-value of the insulation on the DHW distribution system.")
    arg.setDefaultValue(0.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("shower_low_flow", true)
    arg.setDisplayName("Hot Water Fixtures: Is Shower Low Flow")
    arg.setDescription("Whether the shower fixture is low flow.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("sink_low_flow", true)
    arg.setDisplayName("Hot Water Fixtures: Is Sink Low Flow")
    arg.setDescription("Whether the sink fixture is low flow.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("clothes_washer_location", location_choices, true)
    arg.setDisplayName("Clothes Washer: Location")
    arg.setDescription("The space type for the clothes washer location.")
    arg.setDefaultValue("living space")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("clothes_washer_integrated_modified_energy_factor", true)
    arg.setDisplayName("Clothes Washer: Integrated Modified Energy Factor")
    arg.setUnits("ft^3/kWh-cycle")
    arg.setDescription("The Integrated Modified Energy Factor (IMEF) is the capacity of the clothes container divided by the total clothes washer energy consumption per cycle, where the energy consumption is the sum of the machine electrical energy consumption, the hot water energy consumption, the energy required for removal of the remaining moisture in the wash load, standby energy, and off-mode energy consumption. If only a Modified Energy Factor (MEF) is available, convert using the equation: IMEF = (MEF - 0.503) / 0.95.")
    arg.setDefaultValue(0.95)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("clothes_washer_rated_annual_kwh", true)
    arg.setDisplayName("Clothes Washer: Rated Annual Consumption")
    arg.setUnits("kWh")
    arg.setDescription("The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.")
    arg.setDefaultValue(387.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("clothes_washer_label_electric_rate", true)
    arg.setDisplayName("Clothes Washer: Label Electric Rate")
    arg.setUnits("kWh")
    arg.setDescription("The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.")
    arg.setDefaultValue(0.1065)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("clothes_washer_label_gas_rate", true)
    arg.setDisplayName("Clothes Washer: Label Gas Rate")
    arg.setUnits("kWh")
    arg.setDescription("The annual energy consumed by the clothes washer, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.")
    arg.setDefaultValue(1.218)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("clothes_washer_label_annual_gas_cost", true)
    arg.setDisplayName("Clothes Washer: Annual Cost with Gas DHW")
    arg.setUnits("$")
    arg.setDescription("The annual cost of using the system under test conditions. Input is obtained from the EnergyGuide label.")
    arg.setDefaultValue(24.0)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("clothes_washer_capacity", true)
    arg.setDisplayName("Clothes Washer: Drum Volume")
    arg.setUnits("ft^3")
    arg.setDescription("Volume of the washer drum. Obtained from the EnergyStar website or the manufacturer's literature.")
    arg.setDefaultValue(3.5)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("clothes_dryer_location", location_choices, true)
    arg.setDisplayName("Clothes Dryer: Location")
    arg.setDescription("The space type for the clothes dryer location.")
    arg.setDefaultValue("living space")
    args << arg

    clothes_dryer_fuel_choices = OpenStudio::StringVector.new
    clothes_dryer_fuel_choices << "none"
    clothes_dryer_fuel_choices << "electricity"
    clothes_dryer_fuel_choices << "natural gas"
    clothes_dryer_fuel_choices << "fuel oil"
    clothes_dryer_fuel_choices << "propane"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("clothes_dryer_fuel_type", clothes_dryer_fuel_choices, true)
    arg.setDisplayName("Fuel Type")
    arg.setDescription("Type of fuel used by the clothes dryer.")
    arg.setDefaultValue("natural gas")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("clothes_dryer_combined_energy_factor", true)
    arg.setDisplayName("Clothes Dryer: Combined Energy Factor")
    arg.setDescription("The Combined Energy Factor (CEF) measures the pounds of clothing that can be dried per kWh (Fuel equivalent) of electricity, including energy consumed during Stand-by and Off modes. If only an Energy Factor (EF) is available, convert using the equation: CEF = EF / 1.15.")
    arg.setDefaultValue(2.4)
    arg.setUnits("lb/kWh")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("dishwasher_rated_annual_kwh", true)
    arg.setDisplayName("Dishwasher: Rated Annual Consumption")
    arg.setUnits("kWh")
    arg.setDescription("The annual energy consumed by the dishwasher, as rated, obtained from the EnergyGuide label. This includes both the appliance electricity consumption and the energy required for water heating.")
    arg.setDefaultValue(290)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument("dishwasher_place_setting_capacity", true)
    arg.setDisplayName("Dishwasher: Number of Place Settings")
    arg.setUnits("#")
    arg.setDescription("The number of place settings for the unit. Data obtained from manufacturer's literature.")
    arg.setDefaultValue(12)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("refrigerator_location", location_choices, true)
    arg.setDisplayName("Refrigerator: Location")
    arg.setDescription("The space type for the refrigerator location.")
    arg.setDefaultValue("living space")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("refrigerator_rated_annual_kwh", true)
    arg.setDisplayName("Refrigerator: Rated Annual Consumption")
    arg.setUnits("kWh/yr")
    arg.setDescription("The EnergyGuide rated annual energy consumption for a refrigerator.")
    arg.setDefaultValue(434)
    args << arg

    cooking_range_fuel_choices = OpenStudio::StringVector.new
    cooking_range_fuel_choices << "none"
    cooking_range_fuel_choices << "electricity"
    cooking_range_fuel_choices << "natural gas"
    cooking_range_fuel_choices << "fuel oil"
    cooking_range_fuel_choices << "propane"

    arg = OpenStudio::Measure::OSArgument::makeChoiceArgument("cooking_range_fuel_type", cooking_range_fuel_choices, true)
    arg.setDisplayName("Cooking Range: Fuel Type")
    arg.setDescription("Type of fuel used by the cooking range.")
    arg.setDefaultValue("natural gas")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("cooking_range_is_induction", true)
    arg.setDisplayName("Cooking Range: Is Induction")
    arg.setDescription("Whether the cooking range is induction.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("oven_is_convection", true)
    arg.setDisplayName("Oven: Is Convection")
    arg.setDescription("Whether the oven is convection.")
    arg.setDefaultValue(false)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("ceiling_fan_efficiency", true)
    arg.setDisplayName("Ceiling Fan: Efficiency")
    arg.setUnits("CFM/watt")
    arg.setDescription("The efficiency rating of the ceiling fan at medium speed.")
    arg.setDefaultValue(100)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("ceiling_fan_quantity", true)
    arg.setDisplayName("Ceiling Fan: Quantity")
    arg.setUnits("#")
    arg.setDescription("Total number of ceiling fans.")
    arg.setDefaultValue(2)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("plug_loads_frac_sensible", true)
    arg.setDisplayName("Plug Loads: Sensible Fraction")
    arg.setDescription("Fraction of internal gains that are sensible.")
    arg.setDefaultValue(0.93)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("plug_loads_frac_latent", true)
    arg.setDisplayName("Plug Loads: Latent Fraction")
    arg.setDescription("Fraction of internal gains that are latent.")
    arg.setDefaultValue(0.021)
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("plug_loads_weekday_fractions", true)
    arg.setDisplayName("Plug Loads: Weekday Schedule")
    arg.setDescription("Specify the 24-hour weekday schedule.")
    arg.setDefaultValue("0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("plug_loads_weekend_fractions", true)
    arg.setDisplayName("Plug Loads: Weekend Schedule")
    arg.setDescription("Specify the 24-hour weekend schedule.")
    arg.setDefaultValue("0.035, 0.033, 0.032, 0.031, 0.032, 0.033, 0.037, 0.042, 0.043, 0.043, 0.043, 0.044, 0.045, 0.045, 0.044, 0.046, 0.048, 0.052, 0.053, 0.05, 0.047, 0.045, 0.04, 0.036")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeStringArgument("plug_loads_monthly_multipliers", true)
    arg.setDisplayName("Plug Loads: Month Schedule")
    arg.setDescription("Specify the 12-month schedule.")
    arg.setDefaultValue("1.248, 1.257, 0.993, 0.989, 0.993, 0.827, 0.821, 0.821, 0.827, 0.99, 0.987, 1.248")
    args << arg

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # Check for correct versions of OS
    os_version = "2.9.1"
    if OpenStudio.openStudioVersion != os_version
      fail "OpenStudio version #{os_version} is required."
    end

    # assign the user inputs to variables
    args = { :weather_station_epw_filename => runner.getStringArgumentValue("weather_station_epw_filename", user_arguments),
             :hpxml_output_path => runner.getStringArgumentValue("hpxml_output_path", user_arguments),
             :schedules_output_path => runner.getStringArgumentValue("schedules_output_path", user_arguments),
             :unit_type => runner.getStringArgumentValue("unit_type", user_arguments),
             :unit_multiplier => runner.getIntegerArgumentValue("unit_multiplier", user_arguments),
             :cfa => runner.getDoubleArgumentValue("cfa", user_arguments),
             :wall_height => runner.getDoubleArgumentValue("wall_height", user_arguments),
             :num_floors => runner.getIntegerArgumentValue("num_floors", user_arguments),
             :aspect_ratio => runner.getDoubleArgumentValue("aspect_ratio", user_arguments),
             :level => runner.getStringArgumentValue("level", user_arguments),
             :horizontal_location => runner.getStringArgumentValue("horizontal_location", user_arguments),
             :corridor_position => runner.getStringArgumentValue("corridor_position", user_arguments),
             :corridor_width => runner.getDoubleArgumentValue("corridor_width", user_arguments),
             :inset_width => runner.getDoubleArgumentValue("inset_width", user_arguments),
             :inset_depth => runner.getDoubleArgumentValue("inset_depth", user_arguments),
             :inset_position => runner.getStringArgumentValue("inset_position", user_arguments),
             :balcony_depth => runner.getDoubleArgumentValue("balcony_depth", user_arguments),
             :garage_width => runner.getDoubleArgumentValue("garage_width", user_arguments),
             :garage_depth => runner.getDoubleArgumentValue("garage_depth", user_arguments),
             :garage_protrusion => runner.getDoubleArgumentValue("garage_protrusion", user_arguments),
             :garage_position => runner.getStringArgumentValue("garage_position", user_arguments),
             :foundation_type => runner.getStringArgumentValue("foundation_type", user_arguments),
             :foundation_height => runner.getDoubleArgumentValue("foundation_height", user_arguments),
             :attic_type => runner.getStringArgumentValue("attic_type", user_arguments),
             :unconditioned_attic_ceiling_r => runner.getDoubleArgumentValue("unconditioned_attic_ceiling_r", user_arguments),
             :roof_type => runner.getStringArgumentValue("roof_type", user_arguments),
             :roof_pitch => { "1:12" => 1.0 / 12.0, "2:12" => 2.0 / 12.0, "3:12" => 3.0 / 12.0, "4:12" => 4.0 / 12.0, "5:12" => 5.0 / 12.0, "6:12" => 6.0 / 12.0, "7:12" => 7.0 / 12.0, "8:12" => 8.0 / 12.0, "9:12" => 9.0 / 12.0, "10:12" => 10.0 / 12.0, "11:12" => 11.0 / 12.0, "12:12" => 12.0 / 12.0 }[runner.getStringArgumentValue("roof_pitch", user_arguments)],
             :roof_structure => runner.getStringArgumentValue("roof_structure", user_arguments),
             :eaves_depth => UnitConversions.convert(runner.getDoubleArgumentValue("eaves_depth", user_arguments), "ft", "m"),
             :num_bedrooms => runner.getDoubleArgumentValue("num_bedrooms", user_arguments),
             :num_bathrooms => runner.getDoubleArgumentValue("num_bathrooms", user_arguments),
             :num_occupants => runner.getStringArgumentValue("num_occupants", user_arguments),
             :neighbor_left_offset => runner.getDoubleArgumentValue("neighbor_left_offset", user_arguments),
             :neighbor_right_offset => runner.getDoubleArgumentValue("neighbor_right_offset", user_arguments),
             :neighbor_back_offset => runner.getDoubleArgumentValue("neighbor_back_offset", user_arguments),
             :neighbor_front_offset => runner.getDoubleArgumentValue("neighbor_front_offset", user_arguments),
             :orientation => runner.getDoubleArgumentValue("orientation", user_arguments),
             :front_wwr => runner.getDoubleArgumentValue("front_wwr", user_arguments),
             :back_wwr => runner.getDoubleArgumentValue("back_wwr", user_arguments),
             :left_wwr => runner.getDoubleArgumentValue("left_wwr", user_arguments),
             :right_wwr => runner.getDoubleArgumentValue("right_wwr", user_arguments),
             :front_window_area => runner.getDoubleArgumentValue("front_window_area", user_arguments),
             :back_window_area => runner.getDoubleArgumentValue("back_window_area", user_arguments),
             :left_window_area => runner.getDoubleArgumentValue("left_window_area", user_arguments),
             :right_window_area => runner.getDoubleArgumentValue("right_window_area", user_arguments),
             :window_ufactor => runner.getDoubleArgumentValue("window_ufactor", user_arguments),
             :window_shgc => runner.getDoubleArgumentValue("window_shgc", user_arguments),
             :window_aspect_ratio => runner.getDoubleArgumentValue("window_aspect_ratio", user_arguments),
             :overhangs_depth => runner.getDoubleArgumentValue("overhangs_depth", user_arguments),
             :overhangs_front_facade => runner.getBoolArgumentValue("overhangs_front_facade", user_arguments),
             :overhangs_back_facade => runner.getBoolArgumentValue("overhangs_back_facade", user_arguments),
             :overhangs_left_facade => runner.getBoolArgumentValue("overhangs_left_facade", user_arguments),
             :overhangs_right_facade => runner.getBoolArgumentValue("overhangs_right_facade", user_arguments),
             :front_skylight_area => runner.getDoubleArgumentValue("front_skylight_area", user_arguments),
             :back_skylight_area => runner.getDoubleArgumentValue("back_skylight_area", user_arguments),
             :left_skylight_area => runner.getDoubleArgumentValue("left_skylight_area", user_arguments),
             :right_skylight_area => runner.getDoubleArgumentValue("right_skylight_area", user_arguments),
             :skylight_ufactor => runner.getDoubleArgumentValue("skylight_ufactor", user_arguments),
             :skylight_shgc => runner.getDoubleArgumentValue("skylight_shgc", user_arguments),
             :door_area => runner.getDoubleArgumentValue("door_area", user_arguments),
             :door_ufactor => runner.getDoubleArgumentValue("door_ufactor", user_arguments),
             :living_ach50 => runner.getDoubleArgumentValue("living_ach50", user_arguments),
             :heating_system_type => [runner.getStringArgumentValue("heating_system_type_1", user_arguments), runner.getStringArgumentValue("heating_system_type_2", user_arguments)],
             :heating_system_fuel => [runner.getStringArgumentValue("heating_system_fuel_1", user_arguments), runner.getStringArgumentValue("heating_system_fuel_2", user_arguments)],
             :heating_system_heating_efficiency => [runner.getDoubleArgumentValue("heating_system_heating_efficiency_1", user_arguments), runner.getDoubleArgumentValue("heating_system_heating_efficiency_2", user_arguments)],
             :heating_system_heating_capacity => [runner.getStringArgumentValue("heating_system_heating_capacity_1", user_arguments), runner.getStringArgumentValue("heating_system_heating_capacity_2", user_arguments)],
             :heating_system_fraction_heat_load_served => [runner.getDoubleArgumentValue("heating_system_fraction_heat_load_served_1", user_arguments), runner.getDoubleArgumentValue("heating_system_fraction_heat_load_served_2", user_arguments)],
             :cooling_system_type => [runner.getStringArgumentValue("cooling_system_type_1", user_arguments), runner.getStringArgumentValue("cooling_system_type_2", user_arguments)],
             :cooling_system_fuel => [runner.getStringArgumentValue("cooling_system_fuel_1", user_arguments), runner.getStringArgumentValue("cooling_system_fuel_2", user_arguments)],
             :cooling_system_cooling_efficiency => [runner.getDoubleArgumentValue("cooling_system_cooling_efficiency_1", user_arguments), runner.getDoubleArgumentValue("cooling_system_cooling_efficiency_2", user_arguments)],
             :cooling_system_cooling_capacity => [runner.getStringArgumentValue("cooling_system_cooling_capacity_1", user_arguments), runner.getStringArgumentValue("cooling_system_cooling_capacity_2", user_arguments)],
             :cooling_system_fraction_cool_load_served => [runner.getDoubleArgumentValue("cooling_system_fraction_cool_load_served_1", user_arguments), runner.getDoubleArgumentValue("cooling_system_fraction_cool_load_served_2", user_arguments)],
             :heat_pump_type => [runner.getStringArgumentValue("heat_pump_type_1", user_arguments), runner.getStringArgumentValue("heat_pump_type_2", user_arguments)],
             :heat_pump_fuel => [runner.getStringArgumentValue("heat_pump_fuel_1", user_arguments), runner.getStringArgumentValue("heat_pump_fuel_2", user_arguments)],
             :heat_pump_heating_efficiency => [runner.getDoubleArgumentValue("heat_pump_heating_efficiency_1", user_arguments), runner.getDoubleArgumentValue("heat_pump_heating_efficiency_2", user_arguments)],
             :heat_pump_cooling_efficiency => [runner.getDoubleArgumentValue("heat_pump_cooling_efficiency_1", user_arguments), runner.getDoubleArgumentValue("heat_pump_cooling_efficiency_2", user_arguments)],
             :heat_pump_heating_capacity => [runner.getStringArgumentValue("heat_pump_heating_capacity_1", user_arguments), runner.getStringArgumentValue("heat_pump_heating_capacity_2", user_arguments)],
             :heat_pump_cooling_capacity => [runner.getStringArgumentValue("heat_pump_cooling_capacity_1", user_arguments), runner.getStringArgumentValue("heat_pump_cooling_capacity_2", user_arguments)],
             :heat_pump_fraction_heat_load_served => [runner.getDoubleArgumentValue("heat_pump_fraction_heat_load_served_1", user_arguments), runner.getDoubleArgumentValue("heat_pump_fraction_heat_load_served_2", user_arguments)],
             :heat_pump_fraction_cool_load_served => [runner.getDoubleArgumentValue("heat_pump_fraction_cool_load_served_1", user_arguments), runner.getDoubleArgumentValue("heat_pump_fraction_cool_load_served_2", user_arguments)],
             :heat_pump_backup_fuel => [runner.getStringArgumentValue("heat_pump_backup_fuel_1", user_arguments), runner.getStringArgumentValue("heat_pump_backup_fuel_2", user_arguments)],
             :heat_pump_backup_heating_efficiency_percent => [runner.getStringArgumentValue("heat_pump_backup_heating_efficiency_percent_1", user_arguments), runner.getStringArgumentValue("heat_pump_backup_heating_efficiency_percent_2", user_arguments)],
             :heat_pump_backup_heating_capacity => [runner.getStringArgumentValue("heat_pump_backup_heating_capacity_1", user_arguments), runner.getStringArgumentValue("heat_pump_backup_heating_capacity_2", user_arguments)],
             :heating_setpoint_temp => runner.getDoubleArgumentValue("heating_setpoint_temp", user_arguments),
             :heating_setback_temp => runner.getDoubleArgumentValue("heating_setback_temp", user_arguments),
             :heating_setback_hours_per_week => runner.getDoubleArgumentValue("heating_setback_hours_per_week", user_arguments),
             :heating_setback_start_hour => runner.getDoubleArgumentValue("heating_setback_start_hour", user_arguments),
             :cooling_setpoint_temp => runner.getDoubleArgumentValue("cooling_setpoint_temp", user_arguments),
             :cooling_setup_temp => runner.getDoubleArgumentValue("cooling_setup_temp", user_arguments),
             :cooling_setup_hours_per_week => runner.getDoubleArgumentValue("cooling_setup_hours_per_week", user_arguments),
             :cooling_setup_start_hour => runner.getDoubleArgumentValue("cooling_setup_start_hour", user_arguments),
             :distribution_system_type => [runner.getStringArgumentValue("distribution_system_type_1", user_arguments), runner.getStringArgumentValue("distribution_system_type_2", user_arguments)],
             :supply_duct_leakage_units => [runner.getStringArgumentValue("supply_duct_leakage_units_1", user_arguments), runner.getStringArgumentValue("supply_duct_leakage_units_2", user_arguments)],
             :return_duct_leakage_units => [runner.getStringArgumentValue("return_duct_leakage_units_1", user_arguments), runner.getStringArgumentValue("return_duct_leakage_units_2", user_arguments)],
             :supply_duct_leakage_value => [runner.getDoubleArgumentValue("supply_duct_leakage_value_1", user_arguments), runner.getDoubleArgumentValue("supply_duct_leakage_value_2", user_arguments)],
             :return_duct_leakage_value => [runner.getDoubleArgumentValue("return_duct_leakage_value_1", user_arguments), runner.getDoubleArgumentValue("return_duct_leakage_value_2", user_arguments)],
             :supply_duct_insulation_r_value => [runner.getDoubleArgumentValue("supply_duct_insulation_r_value_1", user_arguments), runner.getDoubleArgumentValue("supply_duct_insulation_r_value_2", user_arguments)],
             :return_duct_insulation_r_value => [runner.getDoubleArgumentValue("return_duct_insulation_r_value_1", user_arguments), runner.getDoubleArgumentValue("return_duct_insulation_r_value_2", user_arguments)],
             :supply_duct_location => [runner.getStringArgumentValue("supply_duct_location_1", user_arguments), runner.getStringArgumentValue("supply_duct_location_2", user_arguments)],
             :return_duct_location => [runner.getStringArgumentValue("return_duct_location_1", user_arguments), runner.getStringArgumentValue("return_duct_location_2", user_arguments)],
             :supply_duct_surface_area => [runner.getDoubleArgumentValue("supply_duct_surface_area_1", user_arguments), runner.getDoubleArgumentValue("supply_duct_surface_area_2", user_arguments)],
             :return_duct_surface_area => [runner.getDoubleArgumentValue("return_duct_surface_area_1", user_arguments), runner.getDoubleArgumentValue("return_duct_surface_area_2", user_arguments)],
             :water_heater_type => [runner.getStringArgumentValue("water_heater_type_1", user_arguments), runner.getStringArgumentValue("water_heater_type_2", user_arguments)],
             :water_heater_fuel_type => [runner.getStringArgumentValue("water_heater_fuel_type_1", user_arguments), runner.getStringArgumentValue("water_heater_fuel_type_2", user_arguments)],
             :water_heater_location => [runner.getStringArgumentValue("water_heater_location_1", user_arguments), runner.getStringArgumentValue("water_heater_location_2", user_arguments)],
             :water_heater_tank_volume => [runner.getStringArgumentValue("water_heater_tank_volume_1", user_arguments), runner.getStringArgumentValue("water_heater_tank_volume_2", user_arguments)],
             :water_heater_fraction_dhw_load_served => [runner.getDoubleArgumentValue("water_heater_fraction_dhw_load_served_1", user_arguments), runner.getDoubleArgumentValue("water_heater_fraction_dhw_load_served_2", user_arguments)],
             :water_heater_heating_capacity => [runner.getStringArgumentValue("water_heater_heating_capacity_1", user_arguments), runner.getStringArgumentValue("water_heater_heating_capacity_2", user_arguments)],
             :water_heater_energy_factor => [runner.getStringArgumentValue("water_heater_energy_factor_1", user_arguments), runner.getStringArgumentValue("water_heater_energy_factor_2", user_arguments)],
             :water_heater_recovery_efficiency => [runner.getDoubleArgumentValue("water_heater_recovery_efficiency_1", user_arguments), runner.getDoubleArgumentValue("water_heater_recovery_efficiency_2", user_arguments)],
             :hot_water_distribution_system_type => runner.getStringArgumentValue("hot_water_distribution_system_type", user_arguments),
             :standard_piping_length => runner.getStringArgumentValue("standard_piping_length", user_arguments),
             :recirculation_control_type => runner.getStringArgumentValue("recirculation_control_type", user_arguments),
             :recirculation_piping_length => runner.getDoubleArgumentValue("recirculation_piping_length", user_arguments),
             :recirculation_branch_piping_length => runner.getDoubleArgumentValue("recirculation_branch_piping_length", user_arguments),
             :recirculation_pump_power => runner.getDoubleArgumentValue("recirculation_pump_power", user_arguments),
             :hot_water_distribution_pipe_r_value => runner.getDoubleArgumentValue("hot_water_distribution_pipe_r_value", user_arguments),
             :shower_low_flow => runner.getBoolArgumentValue("shower_low_flow", user_arguments),
             :sink_low_flow => runner.getBoolArgumentValue("sink_low_flow", user_arguments),
             :clothes_washer_location => runner.getStringArgumentValue("clothes_washer_location", user_arguments),
             :clothes_washer_integrated_modified_energy_factor => runner.getDoubleArgumentValue("clothes_washer_integrated_modified_energy_factor", user_arguments),
             :clothes_washer_rated_annual_kwh => runner.getDoubleArgumentValue("clothes_washer_rated_annual_kwh", user_arguments),
             :clothes_washer_label_electric_rate => runner.getDoubleArgumentValue("clothes_washer_label_electric_rate", user_arguments),
             :clothes_washer_label_gas_rate => runner.getDoubleArgumentValue("clothes_washer_label_gas_rate", user_arguments),
             :clothes_washer_label_annual_gas_cost => runner.getDoubleArgumentValue("clothes_washer_label_annual_gas_cost", user_arguments),
             :clothes_washer_capacity => runner.getDoubleArgumentValue("clothes_washer_capacity", user_arguments),
             :clothes_dryer_location => runner.getStringArgumentValue("clothes_dryer_location", user_arguments),
             :clothes_dryer_fuel_type => runner.getStringArgumentValue("clothes_dryer_fuel_type", user_arguments),
             :clothes_dryer_combined_energy_factor => runner.getDoubleArgumentValue("clothes_dryer_combined_energy_factor", user_arguments),
             :dishwasher_rated_annual_kwh => runner.getDoubleArgumentValue("dishwasher_rated_annual_kwh", user_arguments),
             :dishwasher_place_setting_capacity => runner.getIntegerArgumentValue("dishwasher_place_setting_capacity", user_arguments),
             :refrigerator_location => runner.getStringArgumentValue("refrigerator_location", user_arguments),
             :refrigerator_rated_annual_kwh => runner.getDoubleArgumentValue("refrigerator_rated_annual_kwh", user_arguments),
             :cooking_range_fuel_type => runner.getStringArgumentValue("cooking_range_fuel_type", user_arguments),
             :cooking_range_is_induction => runner.getStringArgumentValue("cooking_range_is_induction", user_arguments),
             :oven_is_convection => runner.getStringArgumentValue("oven_is_convection", user_arguments),
             :ceiling_fan_efficiency => runner.getDoubleArgumentValue("ceiling_fan_efficiency", user_arguments),
             :ceiling_fan_quantity => runner.getDoubleArgumentValue("ceiling_fan_quantity", user_arguments),
             :plug_loads_frac_sensible => runner.getDoubleArgumentValue("plug_loads_frac_sensible", user_arguments),
             :plug_loads_frac_latent => runner.getDoubleArgumentValue("plug_loads_frac_latent", user_arguments),
             :plug_loads_weekday_fractions => runner.getStringArgumentValue("plug_loads_weekday_fractions", user_arguments),
             :plug_loads_weekend_fractions => runner.getStringArgumentValue("plug_loads_weekend_fractions", user_arguments),
             :plug_loads_monthly_multipliers => runner.getStringArgumentValue("plug_loads_monthly_multipliers", user_arguments) }

    # Create HPXML file
    hpxml_doc = HPXMLFile.create(runner, model, args)
    if not hpxml_doc
      runner.registerError("Unsuccessful creation of HPXML file.")
      return false
    end

    # Check for invalid HPXML file
    schemas_dir = File.join(File.dirname(__FILE__), "../HPXMLtoOpenStudio/hpxml_schemas")
    skip_validation = false
    if not skip_validation
      if not validate_hpxml(runner, args[:hpxml_output_path], hpxml_doc, schemas_dir)
        return false
      end
    end

    XMLHelper.write_file(hpxml_doc, args[:hpxml_output_path])
    runner.registerInfo("Wrote file: #{args[:hpxml_output_path]}")
  end

  def validate_hpxml(runner, hpxml_path, hpxml_doc, schemas_dir)
    is_valid = true

    if schemas_dir
      unless (Pathname.new schemas_dir).absolute?
        schemas_dir = File.expand_path(File.join(File.dirname(__FILE__), schemas_dir))
      end
      unless Dir.exists?(schemas_dir)
        runner.registerError("'#{schemas_dir}' does not exist.")
        return false
      end
    else
      schemas_dir = nil
    end

    # Validate input HPXML against schema
    if not schemas_dir.nil?
      XMLHelper.validate(hpxml_doc.to_s, File.join(schemas_dir, "HPXML.xsd"), runner).each do |error|
        puts error
        runner.registerError("#{hpxml_path}: #{error.to_s}")
        is_valid = false
      end
      runner.registerInfo("#{hpxml_path}: Validated against HPXML schema.")
    else
      runner.registerWarning("#{hpxml_path}: No schema dir provided, no HPXML validation performed.")
    end

    # Validate input HPXML against EnergyPlus Use Case
    errors = EnergyPlusValidator.run_validator(hpxml_doc)
    errors.each do |error|
      puts error
      runner.registerError("#{hpxml_path}: #{error}")
      is_valid = false
    end
    runner.registerInfo("#{hpxml_path}: Validated against HPXML EnergyPlus Use Case.")

    return is_valid
  end
end

class HPXMLFile
  def self.create(runner, model, args)
    hpxml_values = { :xml_type => "HPXML",
                     :xml_generated_by => "BuildResidentialHPXML",
                     :transaction => "create",
                     :building_id => "MyBuilding",
                     :event_type => "proposed workscope" }

    hpxml_doc = HPXML.create_hpxml(**hpxml_values)
    hpxml = hpxml_doc.elements["HPXML"]

    success = create_geometry_envelope(runner, model, args)
    return false if not success

    success = create_schedules(runner, model, args)
    return false if not success

    site_values = get_site_values(runner, args)
    site_neighbors_values = get_site_neighbors_values(runner, args)
    building_occupancy_values = get_building_occupancy_values(runner, args)
    building_construction_values = get_building_construction_values(runner, args)
    climate_and_risk_zones_values = get_climate_and_risk_zones_values(runner, args)
    air_infiltration_measurement_values = get_air_infiltration_measurement_values(runner, args)
    attic_values = get_attic_values(runner, model, args)
    foundation_values = get_foundation_values(runner, model, args)
    roofs_values = get_roofs_values(runner, model, args)
    rim_joists_values = get_rim_joists_values(runner, model, args)
    walls_values = get_walls_values(runner, model, args)
    foundation_walls_values = get_foundation_walls_values(runner, model, args)
    framefloors_values = get_framefloors_values(runner, model, args)
    slabs_values = get_slabs_values(runner, model, args)
    windows_values = get_windows_values(runner, model, args)
    skylights_values = get_skylights_values(runner, model, args)
    doors_values = get_doors_values(runner, model, args)
    hvac_distributions_values = get_hvac_distributions_values(runner, args)
    heating_systems_values = get_heating_systems_values(runner, args, hvac_distributions_values)
    cooling_systems_values = get_cooling_systems_values(runner, args, hvac_distributions_values)
    heat_pumps_values = get_heat_pumps_values(runner, args, hvac_distributions_values)
    hvac_control_values = get_hvac_control_values(runner, args)
    duct_leakage_measurements_values = get_duct_leakage_measurements_values(runner, args)
    ducts_values = get_ducts_values(runner, args)
    ventilation_fans_values = get_ventilation_fan_values(runner, args)
    water_heating_systems_values = get_water_heating_system_values(runner, args)
    hot_water_distribution_values = get_hot_water_distribution_values(runner, args)
    water_fixtures_values = get_water_fixtures_values(runner, args)
    pv_systems_values = get_pv_system_values(runner, args)
    clothes_washer_values = get_clothes_washer_values(runner, args)
    clothes_dryer_values = get_clothes_dryer_values(runner, args)
    dishwasher_values = get_dishwasher_values(runner, args)
    refrigerator_values = get_refrigerator_values(runner, args)
    cooking_range_values = get_cooking_range_values(runner, args)
    oven_values = get_oven_values(runner, args)
    lighting_values = get_lighting_values(runner, args)
    ceiling_fans_values = get_ceiling_fan_values(runner, args)
    plug_loads_values = get_plug_loads_values(runner, args)
    misc_load_schedule_values = get_misc_load_schedule_values(runner, args)

    HPXML.add_site(hpxml: hpxml, **site_values) unless site_values.nil?
    site_neighbors_values.each do |site_neighbor_values|
      HPXML.add_site_neighbor(hpxml: hpxml, **site_neighbor_values)
    end
    HPXML.add_building_occupancy(hpxml: hpxml, **building_occupancy_values) unless building_occupancy_values.empty?
    HPXML.add_building_construction(hpxml: hpxml, **building_construction_values)
    HPXML.add_climate_and_risk_zones(hpxml: hpxml, **climate_and_risk_zones_values)
    HPXML.add_air_infiltration_measurement(hpxml: hpxml, **air_infiltration_measurement_values)
    HPXML.add_attic(hpxml: hpxml, **attic_values) unless attic_values.empty?
    HPXML.add_foundation(hpxml: hpxml, **foundation_values) unless foundation_values.empty?
    roofs_values.each do |roof_values|
      HPXML.add_roof(hpxml: hpxml, **roof_values)
    end
    rim_joists_values.each do |rim_joist_values|
      HPXML.add_rim_joist(hpxml: hpxml, **rim_joist_values)
    end
    walls_values.each do |wall_values|
      HPXML.add_wall(hpxml: hpxml, **wall_values)
    end
    foundation_walls_values.each do |foundation_wall_values|
      HPXML.add_foundation_wall(hpxml: hpxml, **foundation_wall_values)
    end
    framefloors_values.each do |framefloor_values|
      HPXML.add_framefloor(hpxml: hpxml, **framefloor_values)
    end
    slabs_values.each do |slab_values|
      HPXML.add_slab(hpxml: hpxml, **slab_values)
    end
    windows_values.each do |window_values|
      HPXML.add_window(hpxml: hpxml, **window_values)
    end
    skylights_values.each do |skylight_values|
      HPXML.add_skylight(hpxml: hpxml, **skylight_values)
    end
    doors_values.each do |door_values|
      HPXML.add_door(hpxml: hpxml, **door_values)
    end
    heating_systems_values.each do |heating_system_values|
      HPXML.add_heating_system(hpxml: hpxml, **heating_system_values)
    end
    cooling_systems_values.each do |cooling_system_values|
      HPXML.add_cooling_system(hpxml: hpxml, **cooling_system_values)
    end
    heat_pumps_values.each do |heat_pump_values|
      HPXML.add_heat_pump(hpxml: hpxml, **heat_pump_values)
    end
    HPXML.add_hvac_control(hpxml: hpxml, **hvac_control_values) unless hvac_control_values.empty?
    hvac_distributions_values.each_with_index do |hvac_distribution_values, i|
      hvac_distribution = HPXML.add_hvac_distribution(hpxml: hpxml, **hvac_distribution_values)
      air_distribution = hvac_distribution.elements["DistributionSystemType/AirDistribution"]
      next if air_distribution.nil?

      duct_leakage_measurements_values[i].each do |duct_leakage_measurement_values|
        HPXML.add_duct_leakage_measurement(air_distribution: air_distribution, **duct_leakage_measurement_values)
      end
      ducts_values[i].each do |duct_values|
        HPXML.add_ducts(air_distribution: air_distribution, **duct_values)
      end
    end
    ventilation_fans_values.each do |ventilation_fan_values|
      HPXML.add_ventilation_fan(hpxml: hpxml, **ventilation_fan_values)
    end
    water_heating_systems_values.each do |water_heating_system_values|
      HPXML.add_water_heating_system(hpxml: hpxml, **water_heating_system_values)
    end
    HPXML.add_hot_water_distribution(hpxml: hpxml, **hot_water_distribution_values) unless hot_water_distribution_values.empty?
    water_fixtures_values.each do |water_fixture_values|
      HPXML.add_water_fixture(hpxml: hpxml, **water_fixture_values)
    end
    pv_systems_values.each do |pv_system_values|
      HPXML.add_pv_system(hpxml: hpxml, **pv_system_values)
    end
    HPXML.add_clothes_washer(hpxml: hpxml, **clothes_washer_values) unless clothes_washer_values.empty?
    HPXML.add_clothes_dryer(hpxml: hpxml, **clothes_dryer_values) unless clothes_dryer_values.empty?
    HPXML.add_dishwasher(hpxml: hpxml, **dishwasher_values) unless dishwasher_values.empty?
    HPXML.add_refrigerator(hpxml: hpxml, **refrigerator_values) unless refrigerator_values.empty?
    HPXML.add_cooking_range(hpxml: hpxml, **cooking_range_values) unless cooking_range_values.empty?
    HPXML.add_oven(hpxml: hpxml, **oven_values) unless oven_values.empty?
    HPXML.add_lighting(hpxml: hpxml, **lighting_values) unless lighting_values.empty?
    ceiling_fans_values.each do |ceiling_fan_values|
      HPXML.add_ceiling_fan(hpxml: hpxml, **ceiling_fan_values)
    end
    plug_loads_values.each do |plug_load_values|
      HPXML.add_plug_load(hpxml: hpxml, **plug_load_values)
    end
    HPXML.add_misc_loads_schedule(hpxml: hpxml, **misc_load_schedule_values) unless misc_load_schedule_values.empty?

    HPXML.add_extension(parent: hpxml_doc.elements["/HPXML/Building/BuildingDetails"],
                        extensions: { "UnitMultiplier": args[:unit_multiplier] })

    success = remove_geometry_envelope(model)
    return false if not success

    return hpxml_doc
  end

  def self.create_geometry_envelope(runner, model, args)
    if args[:unit_type] == "single-family detached"
      success = Geometry2.create_single_family_detached(runner: runner, model: model, **args)
    elsif args[:unit_type] == "single-family attached"
      success = Geometry2.create_single_family_attached(runner: runner, model: model, **args)
    elsif args[:unit_type] == "multifamily"
      success = Geometry2.create_multifamily(runner: runner, model: model, **args)
    end
    return false if not success

    success = Geometry2.create_windows_and_skylights(runner: runner, model: model, **args)
    return false if not success

    success = Geometry2.create_doors(runner: runner, model: model, **args)
    return false if not success

    return true
  end

  def self.remove_geometry_envelope(model)
    model.getSpaces.each do |space|
      space.surfaces.each do |surface|
        surface.remove
      end
      if space.thermalZone.is_initialized
        space.thermalZone.get.remove
      end
      if space.spaceType.is_initialized
        space.spaceType.get.remove
      end
      space.remove
    end

    return true
  end

  def self.create_schedules(runner, model, args)
    schedule_file = SchedulesFile.new(runner: runner, model: model, **args)

    success = schedule_file.create_occupant_schedule
    return false if not success

    success = schedule_file.create_refrigerator_schedule
    return false if not success

    success = schedule_file.export
    return false if not success

    return true
  end

  def self.get_site_values(runner, args)
    site_values = {}
    return site_values
  end

  def self.get_site_neighbors_values(runner, args)
    # FIXME: Need to incorporate building orientation
    site_neighbors_values = [{ :azimuth => 0,
                               :distance => args[:neighbor_front_offset] },
                             { :azimuth => 90,
                               :distance => args[:neighbor_left_offset] },
                             { :azimuth => 180,
                               :distance => args[:neighbor_back_offset] },
                             { :azimuth => 270,
                               :distance => args[:neighbor_right_offset] }]
    return site_neighbors_values
  end

  def self.get_building_occupancy_values(runner, args)
    building_occupancy_values = {}
    unless args[:num_occupants] == Constants.Auto
      building_occupancy_values = { :number_of_residents => args[:num_occupants] }
    end
    building_occupancy_values[:schedules_output_path] = args[:schedules_output_path]
    building_occupancy_values[:schedules_column_name] = "occupants"
    return building_occupancy_values
  end

  def self.get_building_construction_values(runner, args)
    number_of_conditioned_floors_above_grade = args[:num_floors]
    number_of_conditioned_floors = number_of_conditioned_floors_above_grade
    if args[:foundation_type] == "basement - conditioned"
      number_of_conditioned_floors += 1
    end
    conditioned_building_volume = args[:cfa] * args[:wall_height]
    building_construction_values = { :number_of_conditioned_floors => number_of_conditioned_floors,
                                     :number_of_conditioned_floors_above_grade => number_of_conditioned_floors_above_grade,
                                     :number_of_bedrooms => args[:num_bedrooms],
                                     :number_of_bathrooms => args[:num_bathrooms],
                                     :conditioned_floor_area => args[:cfa],
                                     :conditioned_building_volume => conditioned_building_volume }
    return building_construction_values
  end

  def self.get_climate_and_risk_zones_values(runner, args)
    climate_and_risk_zones_values = { :weather_station_id => "WeatherStation",
                                      :weather_station_name => File.basename(args[:weather_station_epw_filename]),
                                      :weather_station_epw_filename => args[:weather_station_epw_filename] }
    return climate_and_risk_zones_values
  end

  def self.get_attic_values(runner, model, args)
    attic_values = {}
    if args[:attic_type] == "attic - vented"
      attic_values[:attic_type] = "VentedAttic"
    elsif args[:attic_type] == "attic - unvented"
      attic_values[:attic_type] = "UnventedAttic"
    end
    attic_values[:id] = attic_values[:attic_type] unless attic_values[:attic_type].nil?
    return attic_values
  end

  def self.get_foundation_values(runner, model, args)
    foundation_values = {}
    if args[:foundation_type] == "slab"
      foundation_values[:foundation_type] = "SlabOnGrade"
    elsif args[:foundation_type] == "crawlspace - vented"
      foundation_values[:foundation_type] = "VentedCrawlspace"
    elsif args[:foundation_type] == "crawlspace - unvented"
      foundation_values[:foundation_type] = "UnventedCrawlspace"
    elsif args[:foundation_type] == "basement - unconditioned"
      foundation_values[:foundation_type] = "UnconditionedBasement"
    elsif args[:foundation_type] == "basement - conditioned"
      foundation_values[:foundation_type] = "ConditionedBasement"
    elsif args[:foundation_type] == "ambient"
      foundation_values[:foundation_type] = "Ambient"
    end
    foundation_values[:id] = foundation_values[:foundation_type]
    return foundation_values
  end

  def self.get_air_infiltration_measurement_values(runner, args)
    air_infiltration_measurement_values = { :id => "InfiltrationMeasurement",
                                            :house_pressure => 50,
                                            :unit_of_measure => "ACH",
                                            :air_leakage => args[:living_ach50] }
    return air_infiltration_measurement_values
  end

  def self.get_adjacent_to(model, surface)
    space = surface.space.get
    st = space.spaceType.get
    space_type = st.standardsSpaceType.get

    if ["vented crawlspace"].include? space_type
      return "crawlspace - vented"
    elsif ["unvented crawlspace"].include? space_type
      return "crawlspace - unvented"
    elsif ["garage"].include? space_type
      return "garage"
    elsif ["living"].include? space_type
      if Geometry2.space_is_below_grade(space)
        return "basement - conditioned"
      else
        return "living space"
      end
    elsif ["vented attic"].include? space_type
      return "attic - vented"
    elsif ["unvented attic"].include? space_type
      return "attic - unvented"
    elsif ["unconditioned basement"].include? space_type
      return "basement - unconditioned"
    elsif ["corridor"].include? space_type
      return "living space" # FIXME: update to handle new enum
    else
      fail "Unhandled SpaceType value (#{space_type}) for surface '#{surface.name}'."
    end
  end

  def self.get_roofs_values(runner, model, args)
    roofs_values = []
    model.getSurfaces.each do |surface|
      next unless ["Outdoors"].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != "RoofCeiling"

      roofs_values << { :id => surface.name.to_s,
                        :interior_adjacent_to => get_adjacent_to(model, surface),
                        :area => UnitConversions.convert(surface.netArea, "m^2", "ft^2"),
                        :azimuth => nil, # FIXME: Get from model
                        :solar_absorptance => 0.7, # FIXME: Get from roof material
                        :emittance => 0.92, # FIXME: Get from roof material
                        :pitch => args[:roof_pitch],
                        :radiant_barrier => false, # FIXME: Get from radiant barrier
                        :insulation_assembly_r_value => 0 } # FIXME: Calculate
    end
    return roofs_values
  end

  def self.get_rim_joists_values(runner, model, args)
    rim_joists_values = []
    model.getSurfaces.each do |surface|
    end
    return rim_joists_values
  end

  def self.get_walls_values(runner, model, args)
    walls_values = []
    model.getSurfaces.each do |surface|
      next unless ["Outdoors"].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != "Wall"
      next if ["ambient"].include? surface.space.get.spaceType.get.standardsSpaceType.get # FIXME

      walls_values << { :id => surface.name.to_s,
                        :exterior_adjacent_to => "outside",
                        :interior_adjacent_to => get_adjacent_to(model, surface),
                        :wall_type => "WoodStud", # FIXME: Get from wall construction
                        :area => UnitConversions.convert(surface.netArea, "m^2", "ft^2"),
                        :azimuth => nil, # FIXME: Get from model
                        :solar_absorptance => 0.7, # FIXME: Get from exterior finish
                        :emittance => 0.92, # FIXME: Get from exterior finish
                        :insulation_id => nil,
                        :insulation_assembly_r_value => 13 } # FIXME: Calculate
    end
    return walls_values
  end

  def self.get_foundation_walls_values(runner, model, args)
    foundation_walls_values = []
    model.getSurfaces.each do |surface|
      next unless ["Foundation"].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != "Wall"

      foundation_walls_values << { :id => surface.name.to_s,
                                   :exterior_adjacent_to => "ground",
                                   :interior_adjacent_to => get_adjacent_to(model, surface),
                                   :height => args[:foundation_height],
                                   :area => UnitConversions.convert(surface.netArea, "m^2", "ft^2"),
                                   :azimuth => nil, # FIXME: Get from model
                                   :thickness => 8,
                                   :depth_below_grade => args[:foundation_height], # TODO: Add as input?
                                   :insulation_assembly_r_value => 0 } # FIXME: Calculate
    end
    return foundation_walls_values
  end

  def self.get_framefloors_values(runner, model, args)
    framefloors_values = []
    model.getSurfaces.each do |surface|
      next if surface.outsideBoundaryCondition == "Foundation"
      next unless ["Floor", "RoofCeiling"].include? surface.surfaceType
      next if ["ambient"].include? surface.space.get.spaceType.get.standardsSpaceType.get # FIXME

      interior_adjacent_to = get_adjacent_to(model, surface)
      next if interior_adjacent_to != "living space"

      exterior_adjacent_to = "outside"
      if surface.adjacentSurface.is_initialized
        next if ["ambient"].include? surface.adjacentSurface.get.space.get.spaceType.get.standardsSpaceType.get # FIXME

        exterior_adjacent_to = get_adjacent_to(model, surface.adjacentSurface.get)
      end
      next if interior_adjacent_to == exterior_adjacent_to
      next if surface.surfaceType == "RoofCeiling" and exterior_adjacent_to == "outside"

      framefloor_values = { :id => surface.name.to_s,
                            :exterior_adjacent_to => exterior_adjacent_to,
                            :interior_adjacent_to => interior_adjacent_to,
                            :area => UnitConversions.convert(surface.netArea, "m^2", "ft^2") }

      if interior_adjacent_to == "living space" and exterior_adjacent_to.include? "attic"
        framefloor_values[:insulation_assembly_r_value] = args[:unconditioned_attic_ceiling_r] # FIXME: Calculate
      elsif interior_adjacent_to == "living space" and exterior_adjacent_to.include? "basement"
        framefloor_values[:insulation_assembly_r_value] = 30.0 # FIXME: Calculate
      end

      framefloors_values << framefloor_values
    end
    return framefloors_values
  end

  def self.get_slabs_values(runner, model, args)
    slabs_values = []
    model.getSurfaces.each do |surface|
      next unless ["Foundation"].include? surface.outsideBoundaryCondition
      next if surface.surfaceType != "Floor"
      next if ["ambient"].include? surface.space.get.spaceType.get.standardsSpaceType.get # FIXME

      interior_adjacent_to = get_adjacent_to(model, surface)
      next if interior_adjacent_to.include? "crawlspace"

      slabs_values << { :id => surface.name.to_s,
                        :interior_adjacent_to => interior_adjacent_to,
                        :area => UnitConversions.convert(surface.netArea, "m^2", "ft^2"),
                        :thickness => 4,
                        :exposed_perimeter => 150, # FIXME: Get from model
                        :perimeter_insulation_depth => 0, # FIXME: Get from construction
                        :under_slab_insulation_width => 0, # FIXME: Get from construction
                        :depth_below_grade => 0,
                        :perimeter_insulation_r_value => 0, # FIXME: Get from construction
                        :under_slab_insulation_r_value => 0, # FIXME: Get from construction
                        :carpet_fraction => 0, # TODO: Revisit
                        :carpet_r_value => 0 } # TODO: Revisit
    end
    return slabs_values
  end

  def self.get_windows_values(runner, model, args)
    windows_values = []
    model.getSurfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        next if sub_surface.subSurfaceType != "FixedWindow"

        sub_surface_facade = Geometry.get_facade_for_surface(sub_surface)
        if (sub_surface_facade == Constants.FacadeFront and args[:overhangs_front_facade]) or
           (sub_surface_facade == Constants.FacadeBack and args[:overhangs_back_facade]) or
           (sub_surface_facade == Constants.FacadeLeft and args[:overhangs_left_facade]) or
           (sub_surface_facade == Constants.FacadeRight and args[:overhangs_right_facade])
          overhangs_depth = args[:overhangs_depth]
          overhangs_distance_to_top_of_window = 0.5 # FIXME: Calculate from model
          overhangs_distance_to_bottom_of_window = overhangs_distance_to_top_of_window + Geometry.surface_height(sub_surface)
        end

        windows_values << { :id => sub_surface.name.to_s,
                            :area => UnitConversions.convert(sub_surface.netArea, "m^2", "ft^2"),
                            :azimuth => 0, # FIXME: Get from model
                            :ufactor => args[:window_ufactor],
                            :shgc => args[:window_shgc],
                            :overhangs_depth => overhangs_depth,
                            :overhangs_distance_to_top_of_window => overhangs_distance_to_top_of_window,
                            :overhangs_distance_to_bottom_of_window => overhangs_distance_to_bottom_of_window,
                            :wall_idref => surface.name }
      end
    end
    return windows_values
  end

  def self.get_skylights_values(runner, model, args)
    skylights_values = []
    model.getSurfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        next if sub_surface.subSurfaceType != "Skylight"

        skylights_values << { :id => sub_surface.name.to_s,
                              :area => UnitConversions.convert(sub_surface.netArea, "m^2", "ft^2"),
                              :azimuth => 0, # FIXME: Get from model
                              :ufactor => args[:skylight_ufactor],
                              :shgc => args[:skylight_shgc],
                              :roof_idref => surface.name }
      end
    end
    return skylights_values
  end

  def self.get_doors_values(runner, model, args)
    doors_values = []
    model.getSurfaces.each do |surface|
      surface.subSurfaces.each do |sub_surface|
        next if sub_surface.subSurfaceType != "Door"

        doors_values << { :id => sub_surface.name.to_s,
                          :wall_idref => surface.name,
                          :area => UnitConversions.convert(sub_surface.netArea, "m^2", "ft^2"),
                          :azimuth => 0, # FIXME: Get from model
                          :r_value => 1.0 / args[:door_ufactor] }
      end
    end
    return doors_values
  end

  def self.get_heating_systems_values(runner, args, hvac_distributions_values)
    heating_systems_values = []
    args[:heating_system_type].each_with_index do |heating_system_type, i|
      next if heating_system_type == "none"

      heating_capacity = args[:heating_system_heating_capacity][i]
      if heating_capacity == Constants.SizingAuto
        heating_capacity = -1
      end

      distribution_system_idref = nil
      unless hvac_distributions_values[i].nil?
        distribution_system_idref = hvac_distributions_values[i][:id]
      end

      heating_system_values = { :id => "HeatingSystem#{i + 1}",
                                :distribution_system_idref => distribution_system_idref,
                                :heating_system_type => heating_system_type,
                                :heating_system_fuel => args[:heating_system_fuel][i],
                                :heating_capacity => heating_capacity,
                                :fraction_heat_load_served => args[:heating_system_fraction_heat_load_served][i] }

      if ["Furnace", "WallFurnace", "Boiler"].include? heating_system_type
        heating_system_values[:heating_efficiency_afue] = args[:heating_system_heating_efficiency][i]
      elsif ["ElectricResistance", "Stove", "PortableHeater"]
        heating_system_values[:heating_efficiency_percent] = args[:heating_system_heating_efficiency][i]
      end

      heating_systems_values << heating_system_values
    end
    return heating_systems_values
  end

  def self.get_cooling_systems_values(runner, args, hvac_distributions_values)
    cooling_systems_values = []
    args[:cooling_system_type].each_with_index do |cooling_system_type, i|
      next if cooling_system_type == "none"

      cooling_capacity = args[:cooling_system_cooling_capacity][i]
      if cooling_capacity == Constants.SizingAuto
        cooling_capacity = -1
      end
      if cooling_system_type == "evaporative cooler"
        cooling_capacity = nil
      end

      distribution_system_idref = nil
      unless hvac_distributions_values[i].nil?
        distribution_system_idref = hvac_distributions_values[i][:id]
      end

      cooling_system_values = { :id => "CoolingSystem#{i + 1}",
                                :distribution_system_idref => distribution_system_idref,
                                :cooling_system_type => cooling_system_type,
                                :cooling_system_fuel => args[:cooling_system_fuel][i],
                                :cooling_capacity => cooling_capacity,
                                :fraction_cool_load_served => args[:cooling_system_fraction_cool_load_served][i] }

      if ["central air conditioner"].include? cooling_system_type
        cooling_system_values[:cooling_efficiency_seer] = args[:cooling_system_cooling_efficiency][i]
      elsif ["room air conditioner"].include? cooling_system_type
        cooling_system_values[:cooling_efficiency_eer] = args[:cooling_system_cooling_efficiency][i]
      end

      cooling_systems_values << cooling_system_values
    end
    return cooling_systems_values
  end

  def self.get_heat_pumps_values(runner, args, hvac_distributions_values)
    heat_pumps_values = []
    args[:heat_pump_type].each_with_index do |heat_pump_type, i|
      next if heat_pump_type == "none"

      heating_capacity = args[:heat_pump_heating_capacity][i]
      if heating_capacity == Constants.SizingAuto
        heating_capacity = -1
      end

      cooling_capacity = args[:heat_pump_cooling_capacity][i]
      if cooling_capacity == Constants.SizingAuto
        cooling_capacity = -1
      end

      backup_heating_capacity = args[:heat_pump_backup_heating_capacity][i]
      if backup_heating_capacity == Constants.SizingAuto
        backup_heating_capacity = -1
      end

      distribution_system_idref = nil
      unless hvac_distributions_values[i].nil?
        distribution_system_idref = hvac_distributions_values[i][:id]
      end

      heat_pump_values = { :id => "HeatPump#{i + 1}",
                           :distribution_system_idref => distribution_system_idref,
                           :heat_pump_type => heat_pump_type,
                           :heat_pump_fuel => args[:heat_pump_fuel][i],
                           :heating_capacity => heating_capacity,
                           :cooling_capacity => cooling_capacity,
                           :fraction_heat_load_served => args[:heat_pump_fraction_heat_load_served][i],
                           :fraction_cool_load_served => args[:heat_pump_fraction_cool_load_served][i] }

      if ["air-to-air", "mini-split"].include? heat_pump_type
        heat_pump_values[:heating_efficiency_hspf] = args[:heat_pump_heating_efficiency][i]
        heat_pump_values[:cooling_efficiency_seer] = args[:heat_pump_cooling_efficiency][i]
      elsif ["ground-to-air"].include? heat_pump_type
        heat_pump_values[:heating_efficiency_cop] = args[:heat_pump_heating_efficiency][i]
        heat_pump_values[:cooling_efficiency_eer] = args[:heat_pump_cooling_efficiency][i]
      end

      next if args[:heat_pump_backup_fuel] == "none"

      heat_pump_values[:backup_heating_fuel] = args[:heat_pump_backup_fuel][i]
      heat_pump_values[:backup_heating_efficiency_percent] = args[:heat_pump_backup_heating_efficiency_percent][i]
      heat_pump_values[:backup_heating_capacity] = backup_heating_capacity

      heat_pumps_values << heat_pump_values
    end
    return heat_pumps_values
  end

  def self.get_hvac_control_values(runner, args)
    hvac_control_values = { :id => "HVACControl",
                            :heating_setpoint_temp => args[:heating_setpoint_temp],
                            :cooling_setpoint_temp => args[:cooling_setpoint_temp] }

    if args[:heating_setpoint_temp] != args[:heating_setback_temp]
      hvac_control_values[:heating_setback_temp] = args[:heating_setback_temp]
      hvac_control_values[:heating_setback_hours_per_week] = args[:heating_setback_hours_per_week]
      hvac_control_values[:heating_setback_start_hour] = args[:heating_setback_start_hour]
    end
    if args[:cooling_setpoint_temp] != args[:cooling_setup_temp]
      hvac_control_values[:cooling_setup_temp] = args[:cooling_setup_temp]
      hvac_control_values[:cooling_setup_hours_per_week] = args[:cooling_setup_hours_per_week]
      hvac_control_values[:cooling_setup_start_hour] = args[:cooling_setup_start_hour]
    end
    return hvac_control_values
  end

  def self.get_hvac_distributions_values(runner, args)
    hvac_distributions_values = []
    args[:distribution_system_type].each_with_index do |distribution_system_type, i|
      next if distribution_system_type == "none"

      hvac_distributions_values << { :id => "HVACDistribution#{i + 1}",
                                     :distribution_system_type => distribution_system_type }
    end
    return hvac_distributions_values
  end

  def self.get_duct_leakage_measurements_values(runner, args)
    duct_leakage_measurements_values = []
    args[:distribution_system_type].each_with_index do |distribution_system_type, i|
      next if distribution_system_type != "AirDistribution"

      duct_leakage_measurements_values << [{ :duct_type => "supply",
                                             :duct_leakage_units => args[:supply_duct_leakage_units][i],
                                             :duct_leakage_value => args[:supply_duct_leakage_value][i] },
                                           { :duct_type => "return",
                                             :duct_leakage_units => args[:return_duct_leakage_units][i],
                                             :duct_leakage_value => args[:return_duct_leakage_value][i] }]
    end
    if args[:distribution_system_type] == "AirDistribution"

    end
    return duct_leakage_measurements_values
  end

  def self.get_ducts_values(runner, args)
    ducts_values = []
    args[:distribution_system_type].each_with_index do |distribution_system_type, i|
      next if distribution_system_type != "AirDistribution"

      ducts_values << [{ :duct_type => "supply",
                         :duct_insulation_r_value => args[:supply_duct_insulation_r_value][i],
                         :duct_location => args[:supply_duct_location][i],
                         :duct_surface_area => args[:supply_duct_surface_area][i] },
                       { :duct_type => "return",
                         :duct_insulation_r_value => args[:return_duct_insulation_r_value][i],
                         :duct_location => args[:return_duct_location][i],
                         :duct_surface_area => args[:return_duct_surface_area][i] }]
    end
    return ducts_values
  end

  def self.get_ventilation_fan_values(runner, args)
    ventilation_fans_values = []
    return ventilation_fans_values
  end

  def self.get_water_heating_system_values(runner, args)
    num_water_heaters = 0
    args[:water_heater_type].each do |water_heater_type|
      next if water_heater_type == "none"

      num_water_heaters += 1
    end

    water_heating_systems_values = []
    args[:water_heater_type].each_with_index do |water_heater_type, i|
      next if water_heater_type == "none"

      fuel_type = args[:water_heater_fuel_type][i]

      location = args[:water_heater_location][i]
      if location == Constants.Auto
        location = "living space" # FIXME
      end

      tank_volume = Waterheater2.calc_nom_tankvol(args[:water_heater_tank_volume][i], fuel_type, args[:num_bedrooms], args[:num_bathrooms])

      heating_capacity = args[:water_heater_heating_capacity][i]
      if heating_capacity == Constants.SizingAuto
        heating_capacity = Waterheater.calc_water_heater_capacity(fuel_type, args[:num_bedrooms], num_water_heaters, args[:num_bathrooms])
      else
        heating_capacity = Float(heating_capacity)
      end
      heating_capacity = UnitConversions.convert(heating_capacity, "kBtu/hr", "Btu/hr")

      energy_factor = Waterheater2.calc_ef(args[:water_heater_energy_factor][i], tank_volume, fuel_type)

      recovery_efficiency = args[:water_heater_recovery_efficiency][i]
      if fuel_type == "electricity"
        recovery_efficiency = nil
      end

      water_heating_systems_values << { :id => "WaterHeater#{i + 1}",
                                        :water_heater_type => water_heater_type,
                                        :fuel_type => fuel_type,
                                        :location => location,
                                        :tank_volume => tank_volume,
                                        :fraction_dhw_load_served => args[:water_heater_fraction_dhw_load_served][i],
                                        :heating_capacity => heating_capacity,
                                        :energy_factor => energy_factor,
                                        :recovery_efficiency => recovery_efficiency }
    end
    return water_heating_systems_values
  end

  def self.get_hot_water_distribution_values(runner, args)
    hot_water_distribution_values = { :id => "HotWaterDistribution",
                                      :system_type => args[:hot_water_distribution_system_type],
                                      :standard_piping_length => args[:standard_piping_length],
                                      :recirculation_control_type => args[:recirculation_control_type],
                                      :recirculation_piping_length => args[:recirculation_piping_length],
                                      :recirculation_branch_piping_length => args[:recirculation_branch_piping_length],
                                      :recirculation_pump_power => args[:recirculation_pump_power],
                                      :pipe_r_value => args[:hot_water_distribution_pipe_r_value] }
    return hot_water_distribution_values
  end

  def self.get_water_fixtures_values(runer, args)
    water_fixtures_values = [{ :id => "ShowerFixture",
                               :water_fixture_type => "shower head",
                               :low_flow => args[:shower_low_flow], },
                             { :id => "SinkFixture",
                               :water_fixture_type => "faucet",
                               :low_flow => args[:sink_low_flow] }]
    return water_fixtures_values
  end

  def self.get_pv_system_values(runner, args)
    pv_systems_values = []
    return pv_systems_values
  end

  def self.get_clothes_washer_values(runner, args)
    clothes_washer_values = { :id => "ClothesWasher",
                              :location => args[:clothes_washer_location],
                              :integrated_modified_energy_factor => args[:clothes_washer_integrated_modified_energy_factor],
                              :rated_annual_kwh => args[:clothes_washer_rated_annual_kwh],
                              :label_electric_rate => args[:clothes_washer_label_electric_rate],
                              :label_gas_rate => args[:clothes_washer_label_gas_rate],
                              :label_annual_gas_cost => args[:clothes_washer_label_annual_gas_cost],
                              :capacity => args[:clothes_washer_capacity] }
    return clothes_washer_values
  end

  def self.get_clothes_dryer_values(runner, args)
    clothes_dryer_values = { :id => "ClothesDryer",
                             :location => args[:clothes_dryer_location],
                             :fuel_type => args[:clothes_dryer_fuel_type],
                             :combined_energy_factor => args[:clothes_dryer_combined_energy_factor],
                             :control_type => "timer" }
    return clothes_dryer_values
  end

  def self.get_dishwasher_values(runner, args)
    dishwasher_values = { :id => "Dishwasher",
                          :rated_annual_kwh => args[:dishwasher_rated_annual_kwh],
                          :place_setting_capacity => args[:dishwasher_place_setting_capacity] }
    return dishwasher_values
  end

  def self.get_refrigerator_values(runner, args)
    refrigerator_values = { :id => "Refrigerator",
                            :location => args[:refrigerator_location],
                            :rated_annual_kwh => args[:refrigerator_rated_annual_kwh],
                            :schedules_output_path => args[:schedules_output_path],
                            :schedules_column_name => "refrigerator" }
    return refrigerator_values
  end

  def self.get_cooking_range_values(runner, args)
    cooking_range_values = { :id => "CookingRange",
                             :fuel_type => args[:cooking_range_fuel_type],
                             :is_induction => args[:cooking_range_is_induction] }
    return cooking_range_values
  end

  def self.get_oven_values(runner, args)
    oven_values = { :id => "Oven",
                    :is_convection => args[:oven_is_convection] }
    return oven_values
  end

  def self.get_lighting_values(runner, args)
    lighting_values = { :fraction_tier_i_interior => 0.5,
                        :fraction_tier_i_exterior => 0.5,
                        :fraction_tier_i_garage => 0.5,
                        :fraction_tier_ii_interior => 0.25,
                        :fraction_tier_ii_exterior => 0.25,
                        :fraction_tier_ii_garage => 0.25 }
    return lighting_values
  end

  def self.get_ceiling_fan_values(runner, args)
    return [] if args[:ceiling_fan_quantity] == 0

    ceiling_fans_values = [{ :id => "CeilingFan",
                             :efficiency => args[:ceiling_fan_efficiency],
                             :quantity => args[:ceiling_fan_quantity] }]
    return ceiling_fans_values
  end

  def self.get_plug_loads_values(runner, args)
    plug_loads_values = [{ :id => "PlugLoadMisc",
                           :frac_sensible => args[:plug_loads_frac_sensible],
                           :frac_latent => args[:plug_loads_frac_latent] }]
    return plug_loads_values
  end

  def self.get_misc_load_schedule_values(runner, args)
    misc_load_schedule_values = { :weekday_fractions => args[:plug_loads_weekday_fractions],
                                  :weekend_fractions => args[:plug_loads_weekend_fractions],
                                  :monthly_multipliers => args[:plug_loads_monthly_multipliers] }
    return misc_load_schedule_values
  end
end

# register the measure to be used by the application
HPXMLExporter.new.registerWithApplication
