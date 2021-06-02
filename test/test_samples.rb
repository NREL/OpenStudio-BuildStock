require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require_relative 'minitest_helper'
require_relative '../resources/run_sampling'
require_relative '../resources/buildstock'
require 'minitest/autorun'

class TestResStockMeasuresOSW < MiniTest::Test
  def test_samples_osw
    parent_dir = File.absolute_path(File.join(File.dirname(__FILE__), 'test_samples_osw'))
    weather_dir = create_weather_folder(parent_dir, 'project_testing')

    all_results = []
    [['project_testing', 11], ['project_national', 30]].each do |scenario|
      project_dir, num_samples = scenario

      buildstock_csv = create_buildstock_csv(project_dir, num_samples)
      lib_dir = create_lib_folder(parent_dir, project_dir, buildstock_csv)

      runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
      Dir["#{parent_dir}/workflow.osw"].each do |osw|
        measures_osw_dir = nil
        measures_upgrade_osw_dir = nil

        json = JSON.parse(File.read(osw), symbolize_names: true)
        json[:steps].each do |measure|
          if measure[:measure_dir_name] == 'BuildExistingModel'
            measures_osw_dir = File.join(parent_dir, "#{project_dir}_measures_osw")
            Dir.mkdir(measures_osw_dir) unless File.exist?(measures_osw_dir)
          end
          if measure[:measure_dir_name] == 'ApplyUpgrade'
            measures_upgrade_osw_dir = File.join(parent_dir, "#{project_dir}_measures_upgrade_osw")
            Dir.mkdir(measures_upgrade_osw_dir) unless File.exist?(measures_upgrade_osw_dir)
          end
        end

        (1..num_samples).to_a.each do |building_id|
          bldg_data = get_data_for_sample(File.join(lib_dir, 'housing_characteristics/buildstock.csv'), building_id, runner)
          next unless counties.include? bldg_data['County']

          puts "\nBuilding ID: #{building_id} ...\n"

          change_building_id(osw, building_id)
          RunOSWs.add_simulation_output_report(osw)
          out_osw, result = RunOSWs.run_and_check(osw, parent_dir)
          result['OSW'] = "#{building_id}.osw"
          result['PROJECT'] = project_dir
          all_results << result

          # Check workflow was successful
          assert(File.exist?(out_osw))
          data_hash = JSON.parse(File.read(out_osw))
          assert_equal(data_hash['completed_status'], 'Success')

          # Save measures.osw
          unless measures_osw_dir.nil?
            measures_osw = File.join(parent_dir, 'run', 'measures.osw')
            new_measures_osw = File.join(measures_osw_dir, "#{building_id}.osw")
            FileUtils.mv(measures_osw, new_measures_osw)
          end

          # Save measures-upgrade.osw
          next if measures_upgrade_osw_dir.nil?

          measures_upgrade_osw = File.join(parent_dir, 'run', 'measures-upgrade.osw')
          new_measures_upgrade_osw = File.join(measures_upgrade_osw_dir, "#{building_id}.osw")
          FileUtils.mv(measures_upgrade_osw, new_measures_upgrade_osw)
        end # building_id
      end # osw

      Dir["#{parent_dir}/workflow.osw"].each do |osw|
        change_building_id(osw, 1)
      end

      FileUtils.rm_rf(lib_dir) if File.exist?(lib_dir)
      FileUtils.mv(File.join(parent_dir, 'buildstock.csv'), File.join(parent_dir, "#{project_dir}_buildstock.csv"))
    end # scenario

    FileUtils.rm_rf(weather_dir) if File.exist?(weather_dir)
    FileUtils.rm_rf(File.join(parent_dir, 'run'))
    FileUtils.rm_rf(File.join(parent_dir, 'reports'))

    results_dir = File.join(parent_dir, 'results')
    RunOSWs._rm_path(results_dir)
    RunOSWs.write_summary_results(results_dir, all_results)
  end

  private

  def create_buildstock_csv(project_dir, num_samples)
    outfile = File.join('..', 'test', 'test_samples_osw', 'buildstock.csv')
    r = RunSampling.new
    r.run(project_dir, num_samples, outfile)

    return outfile
  end

  def create_lib_folder(parent_dir, project_dir, buildstock_csv)
    lib_dir = File.join(parent_dir, '..', '..', 'lib') # at top level
    resources_dir = File.join(parent_dir, '..', '..', 'resources')
    housing_characteristics_dir = File.join(parent_dir, '..', '..', project_dir, 'housing_characteristics')
    Dir.mkdir(lib_dir) unless File.exist?(lib_dir)
    FileUtils.cp_r(resources_dir, lib_dir)
    FileUtils.cp_r(housing_characteristics_dir, lib_dir)
    FileUtils.cp(File.join(resources_dir, buildstock_csv), File.join(lib_dir, 'housing_characteristics'))
    return lib_dir
  end

  def create_weather_folder(parent_dir, project_dir)
    src = File.join(parent_dir, '..', '..', 'resources', 'measures', 'HPXMLtoOpenStudio', 'weather', project_dir)
    des = File.join(parent_dir, '..', '..', 'weather')
    FileUtils.cp_r(src, des)

    return des
  end

  def change_building_id(osw, building_id)
    json = JSON.parse(File.read(osw), symbolize_names: true)
    json[:steps].each do |measure|
      next if measure[:measure_dir_name] != 'BuildExistingModel'

      measure[:arguments][:building_id] = "#{building_id}"
    end
    File.open(osw, 'w') do |f|
      f.write(JSON.pretty_generate(json))
    end
  end

  def counties
    return [
      'AZ, Maricopa County',
      'CA, Los Angeles County',
      'GA, Fulton County',
      'IL, Cook County',
      'TX, Harris County',
      'WA, King County'
    ]
  end
end
