require "csv"
require "matrix"
resources_path = File.absolute_path(File.join(File.dirname(__FILE__), "../HPXMLtoOpenStudio/resources"))
unless File.exists? resources_path
  resources_path = File.join(OpenStudio::BCLMeasure::userMeasuresDir.to_s, "HPXMLtoOpenStudio/resources") # Hack to run measures in the OS App since applied measures are copied off into a temporary directory
end
require File.join(resources_path, "constants")
require File.join(resources_path, "geometry")
require File.join(resources_path, "unit_conversions")
require File.join(resources_path, "appliances")
require File.join(resources_path, "weather")

# start the measure
class ResidentialScheduleGenerator < OpenStudio::Measure::ModelMeasure
  def name
    return "Generate Appliance schedules"
  end

  def description
    return "Generates occupancy based schedules for various residential appliances.#{Constants.WorkflowDescription}"
  end

  def modeler_description
    return "a"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # make an argument for number of units
    arg = OpenStudio::Measure::OSArgument::makeIntegerArgument("num_units", true)
    arg.setDisplayName("Num Units")
    arg.setUnits("#")
    arg.setDescription("The number of units.")
    arg.setDefaultValue(1)
    args << arg

    # make a string argument for number of bedrooms
    arg = OpenStudio::Measure::OSArgument::makeDoubleArgument("num_bedrooms", true)
    arg.setDisplayName("Number of Bedrooms")
    arg.setDescription("Specify the number of bedrooms.")
    arg.setDefaultValue(3)
    args << arg

    # Make a string argument for occupants (auto or number)
    arg = OpenStudio::Measure::OSArgument::makeStringArgument("num_occupants", true)
    arg.setDisplayName("Number of Occupants")
    arg.setDescription("Specify the number of occupants.")
    arg.setDefaultValue("2")
    args << arg

    arg = OpenStudio::Measure::OSArgument::makeBoolArgument("modify_plugs_and_lighting", false)
    arg.setDisplayName("Modify plugload and lighting")
    arg.setDescription("Whether to modify plugloads, lighting and the ceiling fan based on occupancy")
    arg.setDefaultValue(true)
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

    # assign the user inputs to variables
    args = { :num_units => runner.getIntegerArgumentValue("num_units", user_arguments),
             :num_bedrooms => runner.getDoubleArgumentValue("num_bedrooms", user_arguments),
             :num_occupants => runner.getStringArgumentValue("num_occupants", user_arguments) }

    args[:schedules_path] = File.join(File.dirname(__FILE__), "../HPXMLtoOpenStudio/resources/schedules")

    weather = WeatherProcess.new(model, runner) # required for lighting schedule generation
    if weather.error?
      return false
    end

    schedule_generator = ScheduleGenerator.new(runner: runner, model: model, weather: weather, **args)

    # create the schedule
    success = schedule_generator.create
    return false if not success

    # export the schedule
    output_csv_file = File.expand_path("../schedules.csv")
    success = schedule_generator.export(output_path: output_csv_file)
    return false if not success

    runner.registerInfo("Generated schedule file: #{output_csv_file}")
    model.getBuilding.additionalProperties.setFeature("Schedules Path", output_csv_file)

    return true
  end
end # end the measure

# this allows the measure to be use by the application
ResidentialScheduleGenerator.new.registerWithApplication
