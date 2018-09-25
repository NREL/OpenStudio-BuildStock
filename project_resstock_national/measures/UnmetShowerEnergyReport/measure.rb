# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class UnmetShowerEnergyReport < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Unmet Shower Energy Report'
  end

  # human readable description
  def description
    return 'Reports unmet shower energy.'
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Measure::OSArgumentVector.new

    return args
  end

  # define the outputs that the measure will create
  def outputs
    buildstock_outputs = ["unmet_shower_energy_kbtu"]
    result = OpenStudio::Measure::OSOutputVector.new
    buildstock_outputs.each do |output|
      result << OpenStudio::Measure::OSOutput.makeDoubleOutput(output)
    end
    return result
  end
  
  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  # Warning: Do not change the name of this method to be snake_case. The method must be lowerCamelCase.
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return result
    end

    result << OpenStudio::IdfObject.load("Output:Variable,*,Unmet Shower Energy,Hourly;").get

    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return false
    end

    # Get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get
    
    # Get the last sql file
    sql = runner.lastEnergyPlusSqlFile
    if sql.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sql = sql.get
    model.setSqlFile(sql)

    # Get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sql.availableEnvPeriods.each do |env_pd|
      env_type = sql.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new("WeatherRunPeriod")
          ann_env_pd = env_pd
        end
      end
    end
    if ann_env_pd == false
      runner.registerError("Can't find a weather runperiod, make sure you ran an annual simulation, not just the design days.")
      return false
    end

    requests = ["Unmet Shower Energy"]
    requests.each do |request|

      sql.availableKeyValues(ann_env_pd, "Hourly", request).each do |key_value|

        total_val = get_timeseries(sql, ann_env_pd, request, key_value)
        unless total_val
          runner.registerError("No data found for #{request}.")
          return false
        end

        report_output(runner, request, total_val, "kBtu")

      end

    end

    sql.close()

    return true
  end


  def get_timeseries(sql, ann_env_pd, request, key_value)
    timeseries = sql.timeSeries(ann_env_pd, "Hourly", request, key_value)
    if timeseries.empty?
      return false
    else
      values = timeseries.get.values
    end
    total_val = 0
    (0...values.length).to_a.each do |i|
      total_val += values[i]
    end
    return OpenStudio::convert(total_val, timeseries.get.units, "kBtu").get
  end

  def report_output(runner, name, val, units)
    runner.registerValue("#{name}_kbtu", val)
    runner.registerInfo("Registering #{val.round(2)} #{units} for #{name}.")
  end

end

# register the measure to be used by the application
UnmetShowerEnergyReport.new.registerWithApplication