require_relative "constants"
require_relative "unit_conversions"
require_relative "util"

class Geometry
  def self.get_zone_volume(zone, runner = nil)
    if zone.isVolumeAutocalculated or not zone.volume.is_initialized
      # Calculate volume from spaces
      volume = 0
      zone.spaces.each do |space|
        volume += UnitConversions.convert(space.volume, "m^3", "ft^3")
      end
    else
      volume = UnitConversions.convert(zone.volume.get, "m^3", "ft^3")
    end
    if volume <= 0 and not runner.nil?
      runner.registerError("Could not find any volume.")
      return nil
    end
    return volume
  end

  # Calculates space heights as the max z coordinate minus the min z coordinate
  def self.get_height_of_spaces(spaces)
    minzs = []
    maxzs = []
    spaces.each do |space|
      zvalues = self.getSurfaceZValues(space.surfaces)
      minzs << zvalues.min + UnitConversions.convert(space.zOrigin, "m", "ft")
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, "m", "ft")
    end
    return maxzs.max - minzs.min
  end

  def self.get_max_z_of_spaces(spaces)
    maxzs = []
    spaces.each do |space|
      zvalues = self.getSurfaceZValues(space.surfaces)
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, "m", "ft")
    end
    return maxzs.max
  end

  # Calculates the surface height as the max z coordinate minus the min z coordinate
  def self.surface_height(surface)
    zvalues = self.getSurfaceZValues([surface])
    minz = zvalues.min
    maxz = zvalues.max
    return maxz - minz
  end

  def self.zone_is_conditioned(zone)
    zone.spaces.each do |space|
      unless self.space_is_conditioned(space)
        return false
      end
    end
  end

  def self.get_thermal_zones_from_spaces(spaces)
    thermal_zones = []
    spaces.each do |space|
      next unless space.thermalZone.is_initialized

      unless thermal_zones.include? space.thermalZone.get
        thermal_zones << space.thermalZone.get
      end
    end
    return thermal_zones
  end

  def self.space_is_unconditioned(space)
    return !self.space_is_conditioned(space)
  end

  def self.space_is_conditioned(space)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return self.is_conditioned_space_type(space.spaceType.get.standardsSpaceType.get)
        end
      end
    end
    return false
  end

  def self.is_conditioned_space_type(space_type)
    if [Constants.SpaceTypeLiving].include? space_type
      return true
    end

    return false
  end

  # Returns true if space is fully above grade
  def self.space_is_above_grade(space)
    return !self.space_is_below_grade(space)
  end

  # Returns true if space is either fully or partially below grade
  def self.space_is_below_grade(space)
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != "wall"
      if surface.outsideBoundaryCondition.downcase == "foundation"
        return true
      end
    end
    return false
  end

  def self.get_space_from_location(model, location, location_hierarchy)
    if location == Constants.Auto
      location_hierarchy.each do |space_type|
        model.getSpaces.each do |space|
          next if not self.space_is_of_type(space, space_type)

          return space
        end
      end
    else
      model.getSpaces.each do |space|
        next if not space.spaceType.is_initialized
        next if not space.spaceType.get.standardsSpaceType.is_initialized
        next if space.spaceType.get.standardsSpaceType.get != location

        return space
      end
    end
    return nil
  end

  # Return an array of x values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceXValues(surfaceArray)
    xValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        xValueArray << UnitConversions.convert(vertex.x, "m", "ft")
      end
    end
    return xValueArray
  end

  # Return an array of y values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceYValues(surfaceArray)
    yValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        yValueArray << UnitConversions.convert(vertex.y, "m", "ft")
      end
    end
    return yValueArray
  end

  # Return an array of z values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceZValues(surfaceArray)
    zValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        zValueArray << UnitConversions.convert(vertex.z, "m", "ft")
      end
    end
    return zValueArray
  end

  def self.get_z_origin_for_zone(zone)
    z_origins = []
    zone.spaces.each do |space|
      z_origins << UnitConversions.convert(space.zOrigin, "m", "ft")
    end
    return z_origins.min
  end

  # Takes in a list of spaces and returns the total above grade wall area
  def self.calculate_above_grade_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase == "foundation"

        wall_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
      end
    end
    return wall_area
  end

  def self.calculate_above_grade_exterior_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"
        next if surface.outsideBoundaryCondition.downcase == "foundation"
        next unless self.space_is_conditioned(surface.space.get)

        wall_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
      end
    end
    return wall_area
  end

  def self.get_roof_pitch(surfaces)
    tilts = []
    surfaces.each do |surface|
      next if surface.surfaceType.downcase != "roofceiling"
      next if surface.outsideBoundaryCondition.downcase != "outdoors" and surface.outsideBoundaryCondition.downcase != "adiabatic"

      tilts << surface.tilt
    end
    return UnitConversions.convert(tilts.max, "rad", "deg")
  end

  # Checks if the surface is between conditioned and unconditioned space
  def self.is_interzonal_surface(surface)
    if surface.outsideBoundaryCondition.downcase != "surface" or not surface.space.is_initialized or not surface.adjacentSurface.is_initialized
      return false
    end

    adjacent_surface = surface.adjacentSurface.get
    if not adjacent_surface.space.is_initialized
      return false
    end
    if self.space_is_conditioned(surface.space.get) == self.space_is_conditioned(adjacent_surface.space.get)
      return false
    end

    return true
  end

  def self.is_living(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeLiving)
  end

  def self.is_vented_crawl(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeVentedCrawl)
  end

  def self.is_unvented_crawl(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeUnventedCrawl)
  end

  def self.is_unconditioned_basement(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeUnconditionedBasement)
  end

  def self.is_vented_attic(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeVentedAttic)
  end

  def self.is_unvented_attic(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeUnventedAttic)
  end

  def self.is_garage(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeGarage)
  end

  def self.space_or_zone_is_of_type(space_or_zone, space_type)
    if space_or_zone.is_a? OpenStudio::Model::Space
      return self.space_is_of_type(space_or_zone, space_type)
    elsif space_or_zone.is_a? OpenStudio::Model::ThermalZone
      return self.zone_is_of_type(space_or_zone, space_type)
    end
  end

  def self.space_is_of_type(space, space_type)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return true if space.spaceType.get.standardsSpaceType.get == space_type
        end
      end
    end
    return false
  end

  def self.zone_is_of_type(zone, space_type)
    zone.spaces.each do |space|
      return self.space_is_of_type(space, space_type)
    end
  end

  def self.get_facade_for_surface(surface)
    tol = 0.001
    n = surface.outwardNormal
    facade = nil
    if (n.z).abs < tol
      if (n.x).abs < tol and (n.y + 1).abs < tol
        facade = Constants.FacadeFront
      elsif (n.x - 1).abs < tol and (n.y).abs < tol
        facade = Constants.FacadeRight
      elsif (n.x).abs < tol and (n.y - 1).abs < tol
        facade = Constants.FacadeBack
      elsif (n.x + 1).abs < tol and (n.y).abs < tol
        facade = Constants.FacadeLeft
      end
    else
      if (n.x).abs < tol and n.y < 0
        facade = Constants.FacadeFront
      elsif n.x > 0 and (n.y).abs < tol
        facade = Constants.FacadeRight
      elsif (n.x).abs < tol and n.y > 0
        facade = Constants.FacadeBack
      elsif n.x < 0 and (n.y).abs < tol
        facade = Constants.FacadeLeft
      end
    end
    return facade
  end

  def self.get_surface_length(surface)
    xvalues = self.getSurfaceXValues([surface])
    yvalues = self.getSurfaceYValues([surface])
    xrange = xvalues.max - xvalues.min
    yrange = yvalues.max - yvalues.min
    if xrange > yrange
      return xrange
    end

    return yrange
  end

  def self.get_surface_height(surface)
    zvalues = self.getSurfaceZValues([surface])
    zrange = zvalues.max - zvalues.min
    return zrange
  end

  def self.get_spaces_above_grade_exterior_walls(spaces)
    above_grade_exterior_walls = []
    spaces.each do |space|
      next if not Geometry.space_is_conditioned(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_walls.include?(surface)
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"

        above_grade_exterior_walls << surface
      end
    end
    return above_grade_exterior_walls
  end

  def self.get_spaces_above_grade_exterior_floors(spaces)
    above_grade_exterior_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_conditioned(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"

        above_grade_exterior_floors << surface
      end
    end
    return above_grade_exterior_floors
  end

  def self.get_spaces_above_grade_ground_floors(spaces)
    above_grade_ground_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_conditioned(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_ground_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor"
        next if surface.outsideBoundaryCondition.downcase != "foundation"

        above_grade_ground_floors << surface
      end
    end
    return above_grade_ground_floors
  end

  def self.get_spaces_above_grade_exterior_roofs(spaces)
    above_grade_exterior_roofs = []
    spaces.each do |space|
      next if not Geometry.space_is_conditioned(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_roofs.include?(surface)
        next if surface.surfaceType.downcase != "roofceiling"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"

        above_grade_exterior_roofs << surface
      end
    end
    return above_grade_exterior_roofs
  end

  def self.get_spaces_interzonal_walls(spaces)
    interzonal_walls = []
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if interzonal_walls.include?(surface)
        next if surface.surfaceType.downcase != "wall"
        next if not self.is_interzonal_surface(surface)

        interzonal_walls << surface
      end
    end
    return interzonal_walls
  end

  def self.get_spaces_interzonal_floors_and_ceilings(spaces)
    interzonal_floors = []
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if interzonal_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor" and surface.surfaceType.downcase != "roofceiling"
        next if not self.is_interzonal_surface(surface)

        interzonal_floors << surface
      end
    end
    return interzonal_floors
  end

  def self.get_spaces_below_grade_exterior_walls(spaces)
    below_grade_exterior_walls = []
    spaces.each do |space|
      next if not Geometry.space_is_conditioned(space)
      next if not Geometry.space_is_below_grade(space)

      space.surfaces.each do |surface|
        next if below_grade_exterior_walls.include?(surface)
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase != "foundation"

        below_grade_exterior_walls << surface
      end
    end
    return below_grade_exterior_walls
  end

  def self.get_spaces_below_grade_exterior_floors(spaces)
    below_grade_exterior_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_conditioned(space)
      next if not Geometry.space_is_below_grade(space)

      space.surfaces.each do |surface|
        next if below_grade_exterior_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor"
        next if surface.outsideBoundaryCondition.downcase != "foundation"

        below_grade_exterior_floors << surface
      end
    end
    return below_grade_exterior_floors
  end

  def self.process_occupants(model, runner, num_occ, occ_gain, sens_frac, lat_frac, weekday_sch, weekend_sch, monthly_sch,
                             cfa, nbeds, space)

    # Error checking
    if sens_frac < 0 or sens_frac > 1
      runner.registerError("Sensible fraction must be greater than or equal to 0 and less than or equal to 1.")
      return false
    end
    if lat_frac < 0 or lat_frac > 1
      runner.registerError("Latent fraction must be greater than or equal to 0 and less than or equal to 1.")
      return false
    end
    if lat_frac + sens_frac > 1
      runner.registerError("Sum of sensible and latent fractions must be less than or equal to 1.")
      return false
    end

    activity_per_person = UnitConversions.convert(occ_gain, "Btu/hr", "W")

    # Hard-coded convective, radiative, latent, and lost fractions
    occ_lat = lat_frac
    occ_sens = sens_frac
    occ_conv = 0.442 * occ_sens
    occ_rad = 0.558 * occ_sens
    occ_lost = 1 - occ_lat - occ_conv - occ_rad

    space_obj_name = "#{Constants.ObjectNameOccupants}"
    space_num_occ = num_occ * UnitConversions.convert(space.floorArea, "m^2", "ft^2") / cfa

    # Create schedule
    people_sch = MonthWeekdayWeekendSchedule.new(model, runner, Constants.ObjectNameOccupants + " schedule", weekday_sch, weekend_sch, monthly_sch, mult_weekday = 1.0, mult_weekend = 1.0, normalize_values = true, create_sch_object = true, schedule_type_limits_name = Constants.ScheduleTypeLimitsFraction)
    if not people_sch.validated?
      return false
    end

    # Create schedule
    activity_sch = OpenStudio::Model::ScheduleRuleset.new(model, activity_per_person)

    # Add people definition for the occ
    occ_def = OpenStudio::Model::PeopleDefinition.new(model)
    occ = OpenStudio::Model::People.new(occ_def)
    occ.setName(space_obj_name)
    occ.setSpace(space)
    occ_def.setName(space_obj_name)
    occ_def.setNumberOfPeopleCalculationMethod("People", 1)
    occ_def.setNumberofPeople(space_num_occ)
    occ_def.setFractionRadiant(occ_rad)
    occ_def.setSensibleHeatFraction(occ_sens)
    occ_def.setMeanRadiantTemperatureCalculationType("ZoneAveraged")
    occ_def.setCarbonDioxideGenerationRate(0)
    occ_def.setEnableASHRAE55ComfortWarnings(false)
    occ.setActivityLevelSchedule(activity_sch)
    occ.setNumberofPeopleSchedule(people_sch.schedule)

    runner.registerInfo("Space '#{space.name}' been assigned #{space_num_occ.round(2)} occupant(s).")
    return true
  end

  def self.get_occupancy_default_num(nbeds)
    return Float(nbeds)
  end

  def self.get_occupancy_default_values()
    # Table 4.2.2(3). Internal Gains for Reference Homes
    hrs_per_day = 16.5 # hrs/day
    sens_gains = 3716.0 # Btu/person/day
    lat_gains = 2884.0 # Btu/person/day
    tot_gains = sens_gains + lat_gains
    heat_gain = tot_gains / hrs_per_day # Btu/person/hr
    sens = sens_gains / tot_gains
    lat = lat_gains / tot_gains
    return heat_gain, hrs_per_day, sens, lat
  end

  def self.create_single_family_detached(runner:,
                                         model:,
                                         ffa:,
                                         wall_height:,
                                         num_floors:,
                                         aspect_ratio:,
                                         garage_width:,
                                         garage_depth:,
                                         garage_protrusion:,
                                         garage_position:,
                                         foundation_type:,
                                         foundation_height:,
                                         attic_type:,
                                         roof_type:,
                                         roof_pitch:,
                                         roof_structure:,
                                         **remainder)
    if foundation_type == "slab"
      foundation_height = 0.0
    end

    # error checking
    if model.getSpaces.size > 0
      runner.registerError("Starting model is not empty.")
      return false
    end
    if aspect_ratio < 0
      runner.registerError("Invalid aspect ratio entered.")
      return false
    end
    if foundation_type == "pier and beam" and (foundation_height <= 0.0)
      runner.registerError("The pier & beam height must be greater than 0 ft.")
      return false
    end
    if num_floors > 6
      runner.registerError("Too many floors.")
      return false
    end
    if garage_protrusion < 0 or garage_protrusion > 1
      runner.registerError("Invalid garage protrusion value entered.")
      return false
    end

    # Convert to SI
    ffa = UnitConversions.convert(ffa, "ft^2", "m^2")
    wall_height = UnitConversions.convert(wall_height, "ft", "m")
    garage_width = UnitConversions.convert(garage_width, "ft", "m")
    garage_depth = UnitConversions.convert(garage_depth, "ft", "m")
    foundation_height = UnitConversions.convert(foundation_height, "ft", "m")

    garage_area = garage_width * garage_depth
    has_garage = false
    if garage_area > 0
      has_garage = true
    end

    # error checking
    if garage_protrusion > 0 and roof_type == "hip" and has_garage
      runner.registerError("Cannot handle protruding garage and hip roof.")
      return false
    end
    if garage_protrusion > 0 and aspect_ratio < 1 and has_garage and roof_type == "gable"
      runner.registerError("Cannot handle protruding garage and attic ridge running from front to back.")
      return false
    end
    if foundation_type == "pier and beam" and has_garage
      runner.registerError("Cannot handle garages with a pier & beam foundation type.")
      return false
    end

    # calculate the footprint of the building
    garage_area_inside_footprint = 0
    if has_garage
      garage_area_inside_footprint = garage_area * (1.0 - garage_protrusion)
    end
    bonus_area_above_garage = garage_area * garage_protrusion
    if foundation_type == "finished basement" and attic_type == "finished attic"
      footprint = (ffa + 2 * garage_area_inside_footprint - (num_floors) * bonus_area_above_garage) / (num_floors + 2)
    elsif foundation_type == "finished basement"
      footprint = (ffa + 2 * garage_area_inside_footprint - (num_floors - 1) * bonus_area_above_garage) / (num_floors + 1)
    elsif attic_type == "finished attic"
      footprint = (ffa + garage_area_inside_footprint - (num_floors) * bonus_area_above_garage) / (num_floors + 1)
    else
      footprint = (ffa + garage_area_inside_footprint - (num_floors - 1) * bonus_area_above_garage) / num_floors
    end

    # calculate the dimensions of the building
    width = Math.sqrt(footprint / aspect_ratio)
    length = footprint / width

    # error checking
    if (garage_width > length and garage_depth > 0) or (((1.0 - garage_protrusion) * garage_depth) > width and garage_width > 0) or (((1.0 - garage_protrusion) * garage_depth) == width and garage_width == length)
      runner.registerError("Invalid living space and garage dimensions.")
      return false
    end

    # starting spaces
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # create living zone
    living_zone = OpenStudio::Model::ThermalZone.new(model)
    living_zone.setName("living zone")

    foundation_offset = 0.0
    if foundation_type == "pier and beam"
      foundation_offset = foundation_height
    end

    space_types_hash = {}

    # loop through the number of floors
    foundation_polygon_with_wrong_zs = nil
    for floor in (0..num_floors - 1)

      z = wall_height * floor + foundation_offset

      if has_garage and z == foundation_offset # first floor and has garage

        # create garage zone
        garage_zone = OpenStudio::Model::ThermalZone.new(model)
        garage_zone.setName("garage zone")

        # make points and polygons
        if garage_position == "Right"
          garage_sw_point = OpenStudio::Point3d.new(length - garage_width, -garage_protrusion * garage_depth, z)
          garage_nw_point = OpenStudio::Point3d.new(length - garage_width, garage_depth - garage_protrusion * garage_depth, z)
          garage_ne_point = OpenStudio::Point3d.new(length, garage_depth - garage_protrusion * garage_depth, z)
          garage_se_point = OpenStudio::Point3d.new(length, -garage_protrusion * garage_depth, z)
          garage_polygon = Geometry.make_polygon(garage_sw_point, garage_nw_point, garage_ne_point, garage_se_point)
        elsif garage_position == "Left"
          garage_sw_point = OpenStudio::Point3d.new(0, -garage_protrusion * garage_depth, z)
          garage_nw_point = OpenStudio::Point3d.new(0, garage_depth - garage_protrusion * garage_depth, z)
          garage_ne_point = OpenStudio::Point3d.new(garage_width, garage_depth - garage_protrusion * garage_depth, z)
          garage_se_point = OpenStudio::Point3d.new(garage_width, -garage_protrusion * garage_depth, z)
          garage_polygon = Geometry.make_polygon(garage_sw_point, garage_nw_point, garage_ne_point, garage_se_point)
        end

        # make space
        garage_space = OpenStudio::Model::Space::fromFloorPrint(garage_polygon, wall_height, model)
        garage_space = garage_space.get
        garage_space_name = "garage space"
        garage_space.setName(garage_space_name)
        if space_types_hash.keys.include? Constants.SpaceTypeGarage
          garage_space_type = space_types_hash[Constants.SpaceTypeGarage]
        else
          garage_space_type = OpenStudio::Model::SpaceType.new(model)
          garage_space_type.setStandardsSpaceType(Constants.SpaceTypeGarage)
          space_types_hash[Constants.SpaceTypeGarage] = garage_space_type
        end
        garage_space.setSpaceType(garage_space_type)
        runner.registerInfo("Set #{garage_space_name}.")

        # set this to the garage zone
        garage_space.setThermalZone(garage_zone)

        m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[0, 3] = 0
        m[1, 3] = 0
        m[2, 3] = z
        garage_space.changeTransformation(OpenStudio::Transformation.new(m))

        if garage_position == "Right"
          sw_point = OpenStudio::Point3d.new(0, 0, z)
          nw_point = OpenStudio::Point3d.new(0, width, z)
          ne_point = OpenStudio::Point3d.new(length, width, z)
          se_point = OpenStudio::Point3d.new(length, 0, z)
          l_se_point = OpenStudio::Point3d.new(length - garage_width, 0, z)
          if (garage_depth < width or garage_protrusion > 0) and garage_protrusion < 1 # garage protrudes but not fully
            living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, garage_ne_point, garage_nw_point, l_se_point)
          elsif garage_protrusion < 1 # garage fits perfectly within living space
            living_polygon = Geometry.make_polygon(sw_point, nw_point, garage_nw_point, garage_sw_point)
          else # garage fully protrudes
            living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)
          end
        elsif garage_position == "Left"
          sw_point = OpenStudio::Point3d.new(0, 0, z)
          nw_point = OpenStudio::Point3d.new(0, width, z)
          ne_point = OpenStudio::Point3d.new(length, width, z)
          se_point = OpenStudio::Point3d.new(length, 0, z)
          l_sw_point = OpenStudio::Point3d.new(garage_width, 0, z)
          if (garage_depth < width or garage_protrusion > 0) and garage_protrusion < 1 # garage protrudes but not fully
            living_polygon = Geometry.make_polygon(garage_nw_point, nw_point, ne_point, se_point, l_sw_point, garage_ne_point)
          elsif garage_protrusion < 1 # garage fits perfectly within living space
            living_polygon = Geometry.make_polygon(garage_se_point, garage_ne_point, ne_point, se_point)
          else # garage fully protrudes
            living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)
          end
        end
        foundation_polygon_with_wrong_zs = living_polygon

      else # first floor without garage or above first floor

        if has_garage
          garage_se_point = OpenStudio::Point3d.new(garage_se_point.x, garage_se_point.y, wall_height * floor + foundation_offset)
          garage_sw_point = OpenStudio::Point3d.new(garage_sw_point.x, garage_sw_point.y, wall_height * floor + foundation_offset)
          garage_nw_point = OpenStudio::Point3d.new(garage_nw_point.x, garage_nw_point.y, wall_height * floor + foundation_offset)
          garage_ne_point = OpenStudio::Point3d.new(garage_ne_point.x, garage_ne_point.y, wall_height * floor + foundation_offset)
          if garage_position == "Right"
            sw_point = OpenStudio::Point3d.new(0, 0, z)
            nw_point = OpenStudio::Point3d.new(0, width, z)
            ne_point = OpenStudio::Point3d.new(length, width, z)
            se_point = OpenStudio::Point3d.new(length, 0, z)
            l_se_point = OpenStudio::Point3d.new(length - garage_width, 0, z)
            if garage_protrusion > 0 # garage protrudes
              living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, garage_se_point, garage_sw_point, l_se_point)
            else # garage does not protrude
              living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)
            end
          elsif garage_position == "Left"
            sw_point = OpenStudio::Point3d.new(0, 0, z)
            nw_point = OpenStudio::Point3d.new(0, width, z)
            ne_point = OpenStudio::Point3d.new(length, width, z)
            se_point = OpenStudio::Point3d.new(length, 0, z)
            l_sw_point = OpenStudio::Point3d.new(garage_width, 0, z)
            if garage_protrusion > 0 # garage protrudes
              living_polygon = Geometry.make_polygon(garage_sw_point, nw_point, ne_point, se_point, l_sw_point, garage_se_point)
            else # garage does not protrude
              living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)
            end
          end

        else

          sw_point = OpenStudio::Point3d.new(0, 0, z)
          nw_point = OpenStudio::Point3d.new(0, width, z)
          ne_point = OpenStudio::Point3d.new(length, width, z)
          se_point = OpenStudio::Point3d.new(length, 0, z)
          living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)
          if z == foundation_offset
            foundation_polygon_with_wrong_zs = living_polygon
          end

        end

      end

      # make space
      living_space = OpenStudio::Model::Space::fromFloorPrint(living_polygon, wall_height, model)
      living_space = living_space.get
      if floor > 0
        living_space_name = "living space|story #{floor + 1}"
      else
        living_space_name = "living space"
      end
      living_space.setName(living_space_name)
      if space_types_hash.keys.include? Constants.SpaceTypeLiving
        living_space_type = space_types_hash[Constants.SpaceTypeLiving]
      else
        living_space_type = OpenStudio::Model::SpaceType.new(model)
        living_space_type.setStandardsSpaceType(Constants.SpaceTypeLiving)
        space_types_hash[Constants.SpaceTypeLiving] = living_space_type
      end
      living_space.setSpaceType(living_space_type)
      runner.registerInfo("Set #{living_space_name}.")

      # set these to the living zone
      living_space.setThermalZone(living_zone)

      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[0, 3] = 0
      m[1, 3] = 0
      m[2, 3] = z
      living_space.changeTransformation(OpenStudio::Transformation.new(m))

    end

    # Attic
    if roof_type != "flat"

      z = z + wall_height

      # calculate the dimensions of the attic
      if length >= width
        attic_height = (width / 2.0) * roof_pitch
      else
        attic_height = (length / 2.0) * roof_pitch
      end

      # make points
      roof_nw_point = OpenStudio::Point3d.new(0, width, z)
      roof_ne_point = OpenStudio::Point3d.new(length, width, z)
      roof_se_point = OpenStudio::Point3d.new(length, 0, z)
      roof_sw_point = OpenStudio::Point3d.new(0, 0, z)

      # make polygons
      polygon_floor = Geometry.make_polygon(roof_nw_point, roof_ne_point, roof_se_point, roof_sw_point)
      side_type = nil
      if roof_type == "gable"
        if length >= width
          roof_w_point = OpenStudio::Point3d.new(0, width / 2.0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length, width / 2.0, z + attic_height)
          polygon_s_roof = Geometry.make_polygon(roof_e_point, roof_w_point, roof_sw_point, roof_se_point)
          polygon_n_roof = Geometry.make_polygon(roof_w_point, roof_e_point, roof_ne_point, roof_nw_point)
          polygon_w_wall = Geometry.make_polygon(roof_w_point, roof_nw_point, roof_sw_point)
          polygon_e_wall = Geometry.make_polygon(roof_e_point, roof_se_point, roof_ne_point)
        else
          roof_w_point = OpenStudio::Point3d.new(length / 2.0, 0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length / 2.0, width, z + attic_height)
          polygon_s_roof = Geometry.make_polygon(roof_e_point, roof_w_point, roof_se_point, roof_ne_point)
          polygon_n_roof = Geometry.make_polygon(roof_w_point, roof_e_point, roof_nw_point, roof_sw_point)
          polygon_w_wall = Geometry.make_polygon(roof_w_point, roof_sw_point, roof_se_point)
          polygon_e_wall = Geometry.make_polygon(roof_e_point, roof_ne_point, roof_nw_point)
        end
        side_type = "Wall"
      elsif roof_type == "hip"
        if length >= width
          roof_w_point = OpenStudio::Point3d.new(width / 2.0, width / 2.0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length - width / 2.0, width / 2.0, z + attic_height)
          polygon_s_roof = Geometry.make_polygon(roof_e_point, roof_w_point, roof_sw_point, roof_se_point)
          polygon_n_roof = Geometry.make_polygon(roof_w_point, roof_e_point, roof_ne_point, roof_nw_point)
          polygon_w_wall = Geometry.make_polygon(roof_w_point, roof_nw_point, roof_sw_point)
          polygon_e_wall = Geometry.make_polygon(roof_e_point, roof_se_point, roof_ne_point)
        else
          roof_w_point = OpenStudio::Point3d.new(length / 2.0, length / 2.0, z + attic_height)
          roof_e_point = OpenStudio::Point3d.new(length / 2.0, width - length / 2.0, z + attic_height)
          polygon_s_roof = Geometry.make_polygon(roof_e_point, roof_w_point, roof_se_point, roof_ne_point)
          polygon_n_roof = Geometry.make_polygon(roof_w_point, roof_e_point, roof_nw_point, roof_sw_point)
          polygon_w_wall = Geometry.make_polygon(roof_w_point, roof_sw_point, roof_se_point)
          polygon_e_wall = Geometry.make_polygon(roof_e_point, roof_ne_point, roof_nw_point)
        end
        side_type = "RoofCeiling"
      end

      # make surfaces
      surface_floor = OpenStudio::Model::Surface.new(polygon_floor, model)
      surface_floor.setSurfaceType("Floor")
      surface_floor.setOutsideBoundaryCondition("Surface")
      surface_s_roof = OpenStudio::Model::Surface.new(polygon_s_roof, model)
      surface_s_roof.setSurfaceType("RoofCeiling")
      surface_s_roof.setOutsideBoundaryCondition("Outdoors")
      surface_n_roof = OpenStudio::Model::Surface.new(polygon_n_roof, model)
      surface_n_roof.setSurfaceType("RoofCeiling")
      surface_n_roof.setOutsideBoundaryCondition("Outdoors")
      surface_w_wall = OpenStudio::Model::Surface.new(polygon_w_wall, model)
      surface_w_wall.setSurfaceType(side_type)
      surface_w_wall.setOutsideBoundaryCondition("Outdoors")
      surface_e_wall = OpenStudio::Model::Surface.new(polygon_e_wall, model)
      surface_e_wall.setSurfaceType(side_type)
      surface_e_wall.setOutsideBoundaryCondition("Outdoors")

      # assign surfaces to the space
      attic_space = OpenStudio::Model::Space.new(model)
      surface_floor.setSpace(attic_space)
      surface_s_roof.setSpace(attic_space)
      surface_n_roof.setSpace(attic_space)
      surface_w_wall.setSpace(attic_space)
      surface_e_wall.setSpace(attic_space)

      # set these to the attic zone
      if attic_type == "unfinished attic"
        # create attic zone
        attic_zone = OpenStudio::Model::ThermalZone.new(model)
        attic_zone.setName("unfinished attic zone")
        attic_space.setThermalZone(attic_zone)
        attic_space_name = "unfinished attic space"
        attic_space_type_name = Constants.SpaceTypeVentedAttic
      elsif attic_type == "finished attic"
        attic_space.setThermalZone(living_zone)
        attic_space_name = "finished attic space"
        attic_space_type_name = Constants.SpaceTypeLiving
      end
      attic_space.setName(attic_space_name)
      if space_types_hash.keys.include? attic_space_type_name
        attic_space_type = space_types_hash[attic_space_type_name]
      else
        attic_space_type = OpenStudio::Model::SpaceType.new(model)
        attic_space_type.setStandardsSpaceType(attic_space_type_name)
        space_types_hash[attic_space_type_name] = attic_space_type
      end
      attic_space.setSpaceType(attic_space_type)
      runner.registerInfo("Set #{attic_space_name}.")

      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[0, 3] = 0
      m[1, 3] = 0
      m[2, 3] = z
      attic_space.changeTransformation(OpenStudio::Transformation.new(m))

    end

    # Foundation
    if ["crawlspace", "unfinished basement", "finished basement", "pier and beam"].include? foundation_type

      z = -foundation_height + foundation_offset

      # create foundation zone
      foundation_zone = OpenStudio::Model::ThermalZone.new(model)
      if foundation_type == "crawlspace"
        foundation_zone_name = "crawl zone"
      elsif foundation_type == "unfinished basement"
        foundation_zone_name = "unfinished basement zone"
      elsif foundation_type == "finished basement"
        foundation_zone_name = "finished basement zone"
      elsif foundation_type == "pier and beam"
        foundation_zone_name = "pier and beam zone"
      end
      foundation_zone.setName(foundation_zone_name)

      # make polygons
      p = OpenStudio::Point3dVector.new
      foundation_polygon_with_wrong_zs.each do |point|
        p << OpenStudio::Point3d.new(point.x, point.y, z)
      end
      foundation_polygon = p

      # make space
      foundation_space = OpenStudio::Model::Space::fromFloorPrint(foundation_polygon, foundation_height, model)
      foundation_space = foundation_space.get
      if foundation_type == "crawlspace"
        foundation_space_name = "crawl space"
        foundation_space_type_name = Constants.SpaceTypeVentedCrawl
      elsif foundation_type == "unfinished basement"
        foundation_space_name = "unfinished basement space"
        foundation_space_type_name = Constants.SpaceTypeUnconditionedBasement
      elsif foundation_type == "finished basement"
        foundation_space_name = "finished basement space"
        foundation_space_type_name = Constants.SpaceTypeLiving
      elsif foundation_type == "pier and beam"
        foundation_space_name = "pier and beam space"
        foundation_space_type_name = foundation_type
      end
      foundation_space.setName(foundation_space_name)
      if space_types_hash.keys.include? foundation_space_type_name
        foundation_space_type = space_types_hash[foundation_space_type_name]
      else
        foundation_space_type = OpenStudio::Model::SpaceType.new(model)
        foundation_space_type.setStandardsSpaceType(foundation_space_type_name)
        space_types_hash[foundation_space_type_name] = foundation_space_type
      end
      foundation_space.setSpaceType(foundation_space_type)
      runner.registerInfo("Set #{foundation_space_name}.")

      # set these to the foundation zone
      foundation_space.setThermalZone(foundation_zone)

      # set foundation walls outside boundary condition
      spaces = model.getSpaces
      spaces.each do |space|
        if Geometry.get_space_floor_z(space) + UnitConversions.convert(space.zOrigin, "m", "ft") < 0
          surfaces = space.surfaces
          surfaces.each do |surface|
            next if surface.surfaceType.downcase != "wall"

            surface.setOutsideBoundaryCondition("Ground")
          end
        end
      end

      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[0, 3] = 0
      m[1, 3] = 0
      m[2, 3] = z
      foundation_space.changeTransformation(OpenStudio::Transformation.new(m))

    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    if has_garage and roof_type != "flat"
      if num_floors > 1
        space_with_roof_over_garage = living_space
      else
        space_with_roof_over_garage = garage_space
      end
      space_with_roof_over_garage.surfaces.each do |surface|
        if surface.surfaceType.downcase == "roofceiling" and surface.outsideBoundaryCondition.downcase == "outdoors"
          n_points = []
          s_points = []
          surface.vertices.each do |vertex|
            if vertex.y == 0
              n_points << vertex
            elsif vertex.y < 0
              s_points << vertex
            end
          end
          if n_points[0].x > n_points[1].x
            nw_point = n_points[1]
            ne_point = n_points[0]
          else
            nw_point = n_points[0]
            ne_point = n_points[1]
          end
          if s_points[0].x > s_points[1].x
            sw_point = s_points[1]
            se_point = s_points[0]
          else
            sw_point = s_points[0]
            se_point = s_points[1]
          end

          if num_floors == 1
            if not attic_type == "finished attic"
              nw_point = OpenStudio::Point3d.new(nw_point.x, nw_point.y, living_space.zOrigin + nw_point.z)
              ne_point = OpenStudio::Point3d.new(ne_point.x, ne_point.y, living_space.zOrigin + ne_point.z)
              sw_point = OpenStudio::Point3d.new(sw_point.x, sw_point.y, living_space.zOrigin + sw_point.z)
              se_point = OpenStudio::Point3d.new(se_point.x, se_point.y, living_space.zOrigin + se_point.z)
            else
              nw_point = OpenStudio::Point3d.new(nw_point.x, nw_point.y, nw_point.z - living_space.zOrigin)
              ne_point = OpenStudio::Point3d.new(ne_point.x, ne_point.y, ne_point.z - living_space.zOrigin)
              sw_point = OpenStudio::Point3d.new(sw_point.x, sw_point.y, sw_point.z - living_space.zOrigin)
              se_point = OpenStudio::Point3d.new(se_point.x, se_point.y, se_point.z - living_space.zOrigin)
            end
          else
            nw_point = OpenStudio::Point3d.new(nw_point.x, nw_point.y, num_floors * nw_point.z)
            ne_point = OpenStudio::Point3d.new(ne_point.x, ne_point.y, num_floors * ne_point.z)
            sw_point = OpenStudio::Point3d.new(sw_point.x, sw_point.y, num_floors * sw_point.z)
            se_point = OpenStudio::Point3d.new(se_point.x, se_point.y, num_floors * se_point.z)
          end

          garage_attic_height = (ne_point.x - nw_point.x) / 2 * roof_pitch

          garage_roof_pitch = roof_pitch
          if garage_attic_height >= attic_height
            garage_attic_height = attic_height - 0.01 # garage attic height slightly below attic height so that we don't get any roof decks with only three vertices
            garage_roof_pitch = garage_attic_height / (garage_width / 2)
            runner.registerWarning("The garage pitch was changed to accommodate garage ridge >= house ridge (from #{roof_pitch.round(3)} to #{garage_roof_pitch.round(3)}).")
          end

          if num_floors == 1
            if not attic_type == "finished attic"
              roof_n_point = OpenStudio::Point3d.new((nw_point.x + ne_point.x) / 2, nw_point.y + garage_attic_height / roof_pitch, living_space.zOrigin + wall_height + garage_attic_height)
              roof_s_point = OpenStudio::Point3d.new((sw_point.x + se_point.x) / 2, sw_point.y, living_space.zOrigin + wall_height + garage_attic_height)
            else
              roof_n_point = OpenStudio::Point3d.new((nw_point.x + ne_point.x) / 2, nw_point.y + garage_attic_height / roof_pitch, garage_attic_height + wall_height)
              roof_s_point = OpenStudio::Point3d.new((sw_point.x + se_point.x) / 2, sw_point.y, garage_attic_height + wall_height)
            end
          else
            roof_n_point = OpenStudio::Point3d.new((nw_point.x + ne_point.x) / 2, nw_point.y + garage_attic_height / roof_pitch, num_floors * wall_height + garage_attic_height)
            roof_s_point = OpenStudio::Point3d.new((sw_point.x + se_point.x) / 2, sw_point.y, num_floors * wall_height + garage_attic_height)
          end

          polygon_w_roof = Geometry.make_polygon(nw_point, sw_point, roof_s_point, roof_n_point)
          polygon_e_roof = Geometry.make_polygon(ne_point, roof_n_point, roof_s_point, se_point)
          polygon_n_wall = Geometry.make_polygon(nw_point, roof_n_point, ne_point)
          polygon_s_wall = Geometry.make_polygon(sw_point, se_point, roof_s_point)

          deck_w = OpenStudio::Model::Surface.new(polygon_w_roof, model)
          deck_w.setSurfaceType("RoofCeiling")
          deck_w.setOutsideBoundaryCondition("Outdoors")
          deck_e = OpenStudio::Model::Surface.new(polygon_e_roof, model)
          deck_e.setSurfaceType("RoofCeiling")
          deck_e.setOutsideBoundaryCondition("Outdoors")
          wall_n = OpenStudio::Model::Surface.new(polygon_n_wall, model)
          wall_n.setSurfaceType("Wall")
          wall_s = OpenStudio::Model::Surface.new(polygon_s_wall, model)
          wall_s.setSurfaceType("Wall")
          wall_s.setOutsideBoundaryCondition("Outdoors")

          garage_attic_space = OpenStudio::Model::Space.new(model)
          garage_attic_space_name = "garage attic space"
          garage_attic_space.setName(garage_attic_space_name)
          deck_w.setSpace(garage_attic_space)
          deck_e.setSpace(garage_attic_space)
          wall_n.setSpace(garage_attic_space)
          wall_s.setSpace(garage_attic_space)

          if attic_type == "finished attic"
            garage_attic_space_type_name = Constants.SpaceTypeLiving
            garage_attic_space.setThermalZone(living_zone)
          else
            if num_floors > 1
              garage_attic_space_type_name = Constants.SpaceTypeVentedAttic
              garage_attic_space.setThermalZone(attic_zone)
            else
              garage_attic_space_type_name = Constants.SpaceTypeGarage
              garage_attic_space.setThermalZone(garage_zone)
            end
          end

          surface.createAdjacentSurface(garage_attic_space) # garage attic floor
          if space_types_hash.keys.include? garage_attic_space_type_name
            garage_attic_space_type = space_types_hash[garage_attic_space_type_name]
          else
            garage_attic_space_type = OpenStudio::Model::SpaceType.new(model)
            garage_attic_space_type.setStandardsSpaceType(garage_attic_space_type_name)
            space_types_hash[garage_attic_space_type_name] = garage_attic_space_type
          end
          garage_attic_space.setSpaceType(garage_attic_space_type)
          runner.registerInfo("Set #{garage_attic_space_name}.")

          # put all of the spaces in the model into a vector
          spaces = OpenStudio::Model::SpaceVector.new
          model.getSpaces.each do |space|
            spaces << space
          end

          # intersect and match surfaces for each space in the vector
          OpenStudio::Model.intersectSurfaces(spaces)
          OpenStudio::Model.matchSurfaces(spaces)

          # remove triangular surface between unfinished attic and garage attic
          unless attic_space.nil?
            attic_space.surfaces.each do |surface|
              next if roof_type == "hip"
              next unless surface.vertices.length == 3
              next unless (90 - surface.tilt * 180 / Math::PI).abs > 0.01 # don't remove the vertical attic walls
              next unless surface.adjacentSurface.is_initialized

              surface.adjacentSurface.get.remove
              surface.remove
            end
          end

          garage_attic_space.surfaces.each do |surface|
            if num_floors > 1 or attic_type == "finished attic"
              m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
              m[2, 3] = -attic_space.zOrigin
              transformation = OpenStudio::Transformation.new(m)
              new_vertices = transformation * surface.vertices
              surface.setVertices(new_vertices)
              surface.setSpace(attic_space)
            end
          end

          if num_floors > 1 or attic_type == "finished attic"
            garage_attic_space.remove
          end

          break

        end
      end
    end

    # set foundation outside boundary condition to Kiva "foundation"
    model.getSurfaces.each do |surface|
      next if surface.outsideBoundaryCondition.downcase != "ground"

      surface.setOutsideBoundaryCondition("Foundation")
    end

    # set foundation walls adjacent to garage to adiabatic
    foundation_walls = []
    model.getSurfaces.each do |surface|
      next if surface.surfaceType.downcase != "wall"
      next if surface.outsideBoundaryCondition.downcase != "foundation"

      foundation_walls << surface
    end
    garage_spaces = Geometry.get_garage_spaces(model.getSpaces)
    garage_spaces.each do |garage_space|
      garage_space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != "floor"

        adjacent_wall_surfaces = Geometry.get_walls_connected_to_floor(foundation_walls, surface, false)
        adjacent_wall_surfaces.each do |adjacent_wall_surface|
          adjacent_wall_surface.setOutsideBoundaryCondition("Adiabatic")
        end
      end
    end

    return true
  end

  def self.make_polygon(*pts)
    p = OpenStudio::Point3dVector.new
    pts.each do |pt|
      p << pt
    end
    return p
  end

  def self.initialize_transformation_matrix(m)
    m[0, 0] = 1
    m[1, 1] = 1
    m[2, 2] = 1
    m[3, 3] = 1
    return m
  end

  def self.get_garage_spaces(spaces)
    garage_spaces = []
    spaces.each do |space|
      next if not self.is_garage(space)

      garage_spaces << space
    end
    return garage_spaces
  end

  def self.space_is_finished(space)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return self.is_living_space_type(space.spaceType.get.standardsSpaceType.get)
        end
      end
    end
    return false
  end

  def self.is_living_space_type(space_type)
    if ["living", "finished basement", "kitchen", "bedroom",
        "bathroom", "laundry room"].include? space_type
      return true
    end

    return false
  end

  def self.get_space_floor_z(space)
    space.surfaces.each do |surface|
      next unless surface.surfaceType.downcase == "floor"

      return self.getSurfaceZValues([surface])[0]
    end
  end

  def self.create_windows_and_skylights(runner:,
                                        model:,
                                        front_wwr:,
                                        back_wwr:,
                                        left_wwr:,
                                        right_wwr:,
                                        front_window_area:,
                                        back_window_area:,
                                        left_window_area:,
                                        right_window_area:,
                                        window_aspect_ratio:,
                                        front_skylight_area:,
                                        back_skylight_area:,
                                        left_skylight_area:,
                                        right_skylight_area:,
                                        **remainder)
    facades = [Constants.FacadeFront, Constants.FacadeBack, Constants.FacadeLeft, Constants.FacadeRight]

    wwrs = {}
    wwrs[Constants.FacadeFront] = front_wwr
    wwrs[Constants.FacadeBack] = back_wwr
    wwrs[Constants.FacadeLeft] = left_wwr
    wwrs[Constants.FacadeRight] = right_wwr
    window_areas = {}
    window_areas[Constants.FacadeFront] = front_window_area
    window_areas[Constants.FacadeBack] = back_window_area
    window_areas[Constants.FacadeLeft] = left_window_area
    window_areas[Constants.FacadeRight] = right_window_area
    # width_extension = UnitConversions.convert(runner.getDoubleArgumentValue("width_extension",user_arguments), "ft", "m")
    skylight_areas = {}
    skylight_areas[Constants.FacadeFront] = front_skylight_area
    skylight_areas[Constants.FacadeBack] = back_skylight_area
    skylight_areas[Constants.FacadeLeft] = left_skylight_area
    skylight_areas[Constants.FacadeRight] = right_skylight_area
    skylight_areas[Constants.FacadeNone] = 0

    # Remove existing windows and store surfaces that should get windows by facade
    wall_surfaces = { Constants.FacadeFront => [], Constants.FacadeBack => [],
                      Constants.FacadeLeft => [], Constants.FacadeRight => [] }
    roof_surfaces = { Constants.FacadeFront => [], Constants.FacadeBack => [],
                      Constants.FacadeLeft => [], Constants.FacadeRight => [],
                      Constants.FacadeNone => [] }
    # flat_roof_surfaces = []
    constructions = {}
    window_warn_msg = nil
    skylight_warn_msg = nil
    Geometry.get_finished_spaces(model.getSpaces).each do |space|
      space.surfaces.each do |surface|
        if surface.surfaceType.downcase == "wall" and surface.outsideBoundaryCondition.downcase == "outdoors"
          next if (90 - surface.tilt * 180 / Math::PI).abs > 0.01 # Not a vertical wall

          win_removed = false
          construction = nil
          surface.subSurfaces.each do |sub_surface|
            next if sub_surface.subSurfaceType.downcase != "fixedwindow"

            if sub_surface.construction.is_initialized
              if not construction.nil? and construction != sub_surface.construction.get
                window_warn_msg = "Multiple constructions found. An arbitrary construction may be assigned to new window(s)."
              end
              construction = sub_surface.construction.get
            end
            sub_surface.remove
            win_removed = true
          end
          if win_removed
            runner.registerInfo("Removed fixed window(s) from #{surface.name}.")
          end
          facade = Geometry.get_facade_for_surface(surface)
          next if facade.nil?

          wall_surfaces[facade] << surface
          if not construction.nil? and not constructions.keys.include? facade
            constructions[facade] = construction
          end
        elsif surface.surfaceType.downcase == "roofceiling" and surface.outsideBoundaryCondition.downcase == "outdoors"
          sky_removed = false
          construction = nil
          surface.subSurfaces.each do |sub_surface|
            next if sub_surface.subSurfaceType.downcase != "skylight"

            if sub_surface.construction.is_initialized
              if not construction.nil? and construction != sub_surface.construction.get
                skylight_warn_msg = "Multiple constructions found. An arbitrary construction may be assigned to new skylight(s)."
              end
              construction = sub_surface.construction.get
            end
            sub_surface.remove
            sky_removed = true
          end
          if sky_removed
            runner.registerInfo("Removed fixed skylight(s) from #{surface.name}.")
          end
          facade = Geometry.get_facade_for_surface(surface)
          if facade.nil?
            if surface.tilt == 0 # flat roof
              roof_surfaces[Constants.FacadeNone] << surface
            end
            next
          end
          roof_surfaces[facade] << surface
          if not construction.nil? and not constructions.keys.include? facade
            constructions[facade] = construction
          end
        end
      end
    end
    if not window_warn_msg.nil?
      runner.registerWarning(window_warn_msg)
    end
    if not skylight_warn_msg.nil?
      runner.registerWarning(skylight_warn_msg)
    end

    # error checking
    facades.each do |facade|
      if wwrs[facade] > 0 and window_areas[facade] > 0
        runner.registerError("Both #{facade} window-to-wall ratio and #{facade} window area are specified.")
        return false
      elsif wwrs[facade] < 0 or wwrs[facade] >= 1
        runner.registerError("#{facade.capitalize} window-to-wall ratio must be greater than or equal to 0 and less than 1.")
        return false
      elsif window_areas[facade] < 0
        runner.registerError("#{facade.capitalize} window area must be greater than or equal to 0.")
        return false
      elsif skylight_areas[facade] < 0
        runner.registerError("#{facade.capitalize} skylight area must be greater than or equal to 0.")
        return false
      end
    end
    if window_aspect_ratio <= 0
      runner.registerError("Window Aspect Ratio must be greater than 0.")
      return false
    end

    # Split any surfaces that have doors so that we can ignore them when adding windows
    facades.each do |facade|
      surfaces_to_add = []
      wall_surfaces[facade].each do |surface|
        next if surface.subSurfaces.size == 0

        new_surfaces = surface.splitSurfaceForSubSurfaces
        new_surfaces.each do |new_surface|
          next if new_surface.subSurfaces.size > 0

          surfaces_to_add << new_surface
        end
      end
      surfaces_to_add.each do |surface_to_add|
        wall_surfaces[facade] << surface_to_add
      end
    end

    # Windows

    # Default assumptions
    min_single_window_area = 5.333 # sqft
    max_single_window_area = 12.0 # sqft
    window_gap_y = 1.0 # ft; distance from top of wall
    window_gap_x = 0.2 # ft; distance between windows in a two-window group
    min_wall_height_for_window = Math.sqrt(max_single_window_area * window_aspect_ratio) + window_gap_y * 1.05 # allow some wall area above/below
    min_window_width = Math.sqrt(min_single_window_area / window_aspect_ratio) * 1.05 # allow some wall area to the left/right

    # Calculate available area for each wall, facade
    surface_avail_area = {}
    facade_avail_area = {}
    facades.each do |facade|
      facade_avail_area[facade] = 0
      wall_surfaces[facade].each do |surface|
        if not surface_avail_area.include? surface
          surface_avail_area[surface] = 0
        end
        next if surface.subSurfaces.size > 0

        area = get_wall_area_for_windows(surface, min_wall_height_for_window, min_window_width, runner)
        surface_avail_area[surface] += area
        facade_avail_area[facade] += area
      end
    end

    surface_window_area = {}
    target_facade_areas = {}
    facades.each do |facade|
      # Initialize
      wall_surfaces[facade].each do |surface|
        surface_window_area[surface] = 0
      end

      # Calculate target window area for this facade
      target_facade_areas[facade] = 0.0
      if wwrs[facade] > 0
        wall_area = 0
        wall_surfaces[facade].each do |surface|
          wall_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
        end
        target_facade_areas[facade] = wall_area * wwrs[facade]
      else
        target_facade_areas[facade] = window_areas[facade]
      end

      next if target_facade_areas[facade] == 0

      if target_facade_areas[facade] < min_single_window_area
        # If the total window area for the facade is less than the minimum window area,
        # set all of the window area to the surface with the greatest available wall area
        surface = my_hash.max_by { |k, v| v }[0]
        surface_window_area[surface] = target_facade_areas[facade]
        next
      end

      # Initial guess for wall of this facade
      wall_surfaces[facade].each do |surface|
        surface_window_area[surface] = surface_avail_area[surface] / facade_avail_area[facade] * target_facade_areas[facade]
      end

      # If window area for a surface is less than the minimum window area,
      # set the window area to zero and proportionally redistribute to the
      # other surfaces.
      wall_surfaces[facade].each_with_index do |surface, surface_num|
        next if surface_window_area[surface] >= min_single_window_area

        removed_window_area = surface_window_area[surface]
        surface_window_area[surface] = 0

        # Future surfaces are those that have not yet been compared to min_single_window_area
        future_surfaces_area = 0
        wall_surfaces[facade].each_with_index do |future_surface, future_surface_num|
          next if future_surface_num <= surface_num

          future_surfaces_area += surface_avail_area[future_surface]
        end
        next if future_surfaces_area == 0

        wall_surfaces[facade].each_with_index do |future_surface, future_surface_num|
          next if future_surface_num <= surface_num

          surface_window_area[future_surface] += removed_window_area * surface_window_area[future_surface] / future_surfaces_area
        end
      end

      # Because the above process is calculated based on the order of surfaces, it's possible
      # that we have less area for this facade than we should. If so, redistribute proportionally
      # to all surfaces that have window area.
      sum_window_area = 0
      wall_surfaces[facade].each do |surface|
        sum_window_area += surface_window_area[surface]
      end
      next if sum_window_area == 0

      wall_surfaces[facade].each do |surface|
        surface_window_area[surface] += surface_window_area[surface] / sum_window_area * (target_facade_areas[facade] - sum_window_area)
      end
    end

    tot_win_area = 0
    facades.each do |facade|
      facade_win_area = 0
      wall_surfaces[facade].each do |surface|
        next if surface_window_area[surface] == 0
        if not add_windows_to_wall(surface, surface_window_area[surface], window_gap_y, window_gap_x, window_aspect_ratio, max_single_window_area, facade, constructions, model, runner)
          return false
        end

        tot_win_area += surface_window_area[surface]
        facade_win_area += surface_window_area[surface]
      end
      if (facade_win_area - target_facade_areas[facade]).abs > 0.1
        runner.registerWarning("Unable to assign appropriate window area for #{facade} facade.")
      end
    end

    # Skylights
    unless roof_surfaces[Constants.FacadeNone].empty?
      tot_sky_area = 0
      skylight_areas.each do |facade, skylight_area|
        next if facade == Constants.FacadeNone

        skylight_area /= roof_surfaces[Constants.FacadeNone].length
        skylight_areas[Constants.FacadeNone] += skylight_area
        skylight_areas[facade] = 0
      end
    end

    tot_sky_area = 0
    skylight_areas.each do |facade, skylight_area|
      next if skylight_area == 0

      surfaces = roof_surfaces[facade]

      if surfaces.empty? and not facade == Constants.FacadeNone
        runner.registerError("There are no #{facade} roof surfaces, but #{skylight_area} ft^2 of skylights were specified.")
        return false
      end

      surfaces.each do |surface|
        if (UnitConversions.convert(surface.grossArea, "m^2", "ft^2") / Geometry.get_surface_length(surface)) > Geometry.get_surface_length(surface)
          skylight_aspect_ratio = Geometry.get_surface_length(surface) / (UnitConversions.convert(surface.grossArea, "m^2", "ft^2") / Geometry.get_surface_length(surface)) # aspect ratio of the roof surface
        else
          skylight_aspect_ratio = (UnitConversions.convert(surface.grossArea, "m^2", "ft^2") / Geometry.get_surface_length(surface)) / Geometry.get_surface_length(surface) # aspect ratio of the roof surface
        end

        skylight_width = Math.sqrt(UnitConversions.convert(skylight_area, "ft^2", "m^2") / skylight_aspect_ratio)
        skylight_length = UnitConversions.convert(skylight_area, "ft^2", "m^2") / skylight_width

        skylight_bottom_left = OpenStudio::getCentroid(surface.vertices).get
        leftx = skylight_bottom_left.x
        lefty = skylight_bottom_left.y
        bottomz = skylight_bottom_left.z
        if facade == Constants.FacadeFront or facade == Constants.FacadeNone
          skylight_top_left = OpenStudio::Point3d.new(leftx, lefty + Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx + skylight_width, lefty + Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx + skylight_width, lefty, bottomz)
        elsif facade == Constants.FacadeBack
          skylight_top_left = OpenStudio::Point3d.new(leftx, lefty - Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx - skylight_width, lefty - Math.cos(surface.tilt) * skylight_length, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx - skylight_width, lefty, bottomz)
        elsif facade == Constants.FacadeLeft
          skylight_top_left = OpenStudio::Point3d.new(leftx + Math.cos(surface.tilt) * skylight_length, lefty, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx + Math.cos(surface.tilt) * skylight_length, lefty - skylight_width, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx, lefty - skylight_width, bottomz)
        elsif facade == Constants.FacadeRight
          skylight_top_left = OpenStudio::Point3d.new(leftx - Math.cos(surface.tilt) * skylight_length, lefty, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_top_right = OpenStudio::Point3d.new(leftx - Math.cos(surface.tilt) * skylight_length, lefty + skylight_width, bottomz + Math.sin(surface.tilt) * skylight_length)
          skylight_bottom_right = OpenStudio::Point3d.new(leftx, lefty + skylight_width, bottomz)
        end

        skylight_polygon = OpenStudio::Point3dVector.new
        [skylight_bottom_left, skylight_bottom_right, skylight_top_right, skylight_top_left].each do |skylight_vertex|
          skylight_polygon << skylight_vertex
        end

        sub_surface = OpenStudio::Model::SubSurface.new(skylight_polygon, model)
        sub_surface.setName("#{surface.name} - Skylight")
        sub_surface.setSurface(surface)

        runner.registerInfo("Added a skylight, totaling #{skylight_area.round(1).to_s} ft^2, to #{surface.name}.")

        if not constructions[facade].nil?
          sub_surface.setConstruction(constructions[facade])
        end

        tot_sky_area += skylight_area
      end
    end

    if tot_win_area == 0 and tot_sky_area == 0
      runner.registerFinalCondition("No windows or skylights added.")
    end

    return true
  end

  def self.get_wall_area_for_windows(surface, min_wall_height_for_window, min_window_width, runner)
    # Only allow on gable and rectangular walls
    if not (Geometry.is_rectangular_wall(surface) or Geometry.is_gable_wall(surface))
      return 0.0
    end

    # Can't fit the smallest window?
    if Geometry.get_surface_length(surface) < min_window_width
      return 0.0
    end

    # Wall too short?
    if min_wall_height_for_window > Geometry.get_surface_height(surface)
      return 0.0
    end

    # Gable too short?
    # TODO: super crude safety factor of 1.5
    if Geometry.is_gable_wall(surface) and min_wall_height_for_window > Geometry.get_surface_height(surface) / 1.5
      return 0.0
    end

    return UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
  end

  def self.add_windows_to_wall(surface, window_area, window_gap_y, window_gap_x, window_aspect_ratio, max_single_window_area, facade, constructions, model, runner)
    wall_width = Geometry.get_surface_length(surface)
    wall_height = Geometry.get_surface_height(surface)

    # Calculate number of windows needed
    num_windows = (window_area / max_single_window_area).ceil
    num_window_groups = (num_windows / 2.0).ceil
    num_window_gaps = num_window_groups
    if num_windows % 2 == 1
      num_window_gaps -= 1
    end
    window_width = Math.sqrt((window_area / num_windows.to_f) / window_aspect_ratio)
    window_height = (window_area / num_windows.to_f) / window_width
    width_for_windows = window_width * num_windows.to_f + window_gap_x * num_window_gaps.to_f
    if width_for_windows > wall_width
      runner.registerError("Could not fit windows on #{surface.name.to_s}.")
      return false
    end

    # Position window from top of surface
    win_top = wall_height - window_gap_y
    if Geometry.is_gable_wall(surface)
      # For gable surfaces, position windows from bottom of surface so they fit
      win_top = window_height + window_gap_y
    end

    # Groups of two windows
    win_num = 0
    for i in (1..num_window_groups)

      # Center vertex for group
      group_cx = wall_width * i / (num_window_groups + 1).to_f
      group_cy = win_top - window_height / 2.0

      if not (i == num_window_groups and num_windows % 2 == 1)
        # Two windows in group
        win_num += 1
        add_window_to_wall(surface, window_width, window_height, group_cx - window_width / 2.0 - window_gap_x / 2.0, group_cy, win_num, facade, constructions, model, runner)
        win_num += 1
        add_window_to_wall(surface, window_width, window_height, group_cx + window_width / 2.0 + window_gap_x / 2.0, group_cy, win_num, facade, constructions, model, runner)
      else
        # One window in group
        win_num += 1
        add_window_to_wall(surface, window_width, window_height, group_cx, group_cy, win_num, facade, constructions, model, runner)
      end
    end
    runner.registerInfo("Added #{num_windows.to_s} window(s), totaling #{window_area.round(1).to_s} ft^2, to #{surface.name}.")
    return true
  end

  def self.add_window_to_wall(surface, win_width, win_height, win_center_x, win_center_y, win_num, facade, constructions, model, runner)
    # Create window vertices in relative coordinates, ft
    upperleft = [win_center_x - win_width / 2.0, win_center_y + win_height / 2.0]
    upperright = [win_center_x + win_width / 2.0, win_center_y + win_height / 2.0]
    lowerright = [win_center_x + win_width / 2.0, win_center_y - win_height / 2.0]
    lowerleft = [win_center_x - win_width / 2.0, win_center_y - win_height / 2.0]

    # Convert to 3D geometry; assign to surface
    window_polygon = OpenStudio::Point3dVector.new
    if facade == Constants.FacadeFront
      multx = 1
      multy = 0
    elsif facade == Constants.FacadeBack
      multx = -1
      multy = 0
    elsif facade == Constants.FacadeLeft
      multx = 0
      multy = -1
    elsif facade == Constants.FacadeRight
      multx = 0
      multy = 1
    end
    if facade == Constants.FacadeBack or facade == Constants.FacadeLeft
      leftx = Geometry.getSurfaceXValues([surface]).max
      lefty = Geometry.getSurfaceYValues([surface]).max
    else
      leftx = Geometry.getSurfaceXValues([surface]).min
      lefty = Geometry.getSurfaceYValues([surface]).min
    end
    bottomz = Geometry.getSurfaceZValues([surface]).min
    [upperleft, lowerleft, lowerright, upperright].each do |coord|
      newx = UnitConversions.convert(leftx + multx * coord[0], "ft", "m")
      newy = UnitConversions.convert(lefty + multy * coord[0], "ft", "m")
      newz = UnitConversions.convert(bottomz + coord[1], "ft", "m")
      window_vertex = OpenStudio::Point3d.new(newx, newy, newz)
      window_polygon << window_vertex
    end
    sub_surface = OpenStudio::Model::SubSurface.new(window_polygon, model)
    sub_surface.setName("#{surface.name} - Window #{win_num.to_s}")
    sub_surface.setSurface(surface)
    sub_surface.setSubSurfaceType("FixedWindow")
    if not constructions[facade].nil?
      sub_surface.setConstruction(constructions[facade])
    end
  end

  def self.get_finished_spaces(spaces)
    finished_spaces = []
    spaces.each do |space|
      next if self.space_is_unfinished(space)

      finished_spaces << space
    end
    return finished_spaces
  end

  def self.space_is_unfinished(space)
    return !self.space_is_finished(space)
  end

  def self.is_rectangular_wall(surface)
    if (surface.surfaceType.downcase != "wall" or surface.outsideBoundaryCondition.downcase != "outdoors")
      return false
    end
    if surface.vertices.size != 4
      return false
    end

    xvalues = self.getSurfaceXValues([surface])
    yvalues = self.getSurfaceYValues([surface])
    zvalues = self.getSurfaceZValues([surface])
    if not ((xvalues.uniq.size == 1 and yvalues.uniq.size == 2) or
            (xvalues.uniq.size == 2 and yvalues.uniq.size == 1))
      return false
    end
    if not zvalues.uniq.size == 2
      return false
    end

    return true
  end

  def self.is_gable_wall(surface)
    if (surface.surfaceType.downcase != "wall" or surface.outsideBoundaryCondition.downcase != "outdoors")
      return false
    end
    if surface.vertices.size != 3
      return false
    end
    if not surface.space.is_initialized
      return false
    end

    space = surface.space.get
    if not self.space_has_roof(space)
      return false
    end

    return true
  end

  def self.create_doors(runner:,
                        model:,
                        door_area:,
                        **remainder)
    construction = nil
    warn_msg = nil
    model.getSubSurfaces.each do |sub_surface|
      next if sub_surface.subSurfaceType.downcase != "door"

      if sub_surface.construction.is_initialized
        if not construction.nil?
          warn_msg = "Multiple constructions found. An arbitrary construction may be assigned to new door(s)."
        end
        construction = sub_surface.construction.get
      end
      runner.registerInfo("Removed door(s) from #{sub_surface.surface.get.name}.")
      sub_surface.remove
    end
    if not warn_msg.nil?
      runner.registerWarning(warn_msg)
    end

    # error checking
    if door_area < 0
      runner.registerError("Invalid door area.")
      return false
    elsif door_area == 0
      runner.registerFinalCondition("No doors added because door area was set to 0.")
      return true
    end

    door_height = 7 # ft
    door_width = door_area / door_height
    door_offset = 0.5 # ft

    # Get all exterior walls prioritized by front, then back, then left, then right
    facades = [Constants.FacadeFront, Constants.FacadeBack]
    avail_walls = []
    facades.each do |facade|
      Geometry.get_finished_spaces(model.getSpaces).each do |space|
        next if Geometry.space_is_below_grade(space)

        space.surfaces.each do |surface|
          next if Geometry.get_facade_for_surface(surface) != facade
          next if surface.outsideBoundaryCondition.downcase != "outdoors"
          next if (90 - surface.tilt * 180 / Math::PI).abs > 0.01 # Not a vertical wall

          avail_walls << surface
        end
      end
      break if avail_walls.size > 0
    end

    # Get subset of exterior walls on lowest story
    min_story_avail_walls = []
    min_story_avail_wall_minz = 99999
    avail_walls.each do |avail_wall|
      zvalues = Geometry.getSurfaceZValues([avail_wall])
      minz = zvalues.min + avail_wall.space.get.zOrigin
      if minz < min_story_avail_wall_minz
        min_story_avail_walls.clear
        min_story_avail_walls << avail_wall
        min_story_avail_wall_minz = minz
      elsif (minz - min_story_avail_wall_minz).abs < 0.001
        min_story_avail_walls << avail_wall
      end
    end

    # Get all corridor walls
    corridor_walls = []
    Geometry.get_finished_spaces(model.getSpaces).each do |space|
      space.surfaces.each do |surface|
        next unless surface.surfaceType.downcase == "wall"
        next unless surface.outsideBoundaryCondition.downcase == "adiabatic"

        model.getSpaces.each do |potential_corridor_space|
          next unless potential_corridor_space.spaceType.get.standardsSpaceType.get == "corridor"

          potential_corridor_space.surfaces.each do |potential_corridor_surface|
            next unless surface.reverseEqualVertices(potential_corridor_surface)

            corridor_walls << potential_corridor_surface
          end
        end
      end
    end

    # Get subset of corridor walls on lowest story
    min_story_corridor_walls = []
    min_story_corridor_wall_minz = 99999
    corridor_walls.each do |corridor_wall|
      zvalues = Geometry.getSurfaceZValues([corridor_wall])
      minz = zvalues.min + corridor_wall.space.get.zOrigin
      if minz < min_story_corridor_wall_minz
        min_story_corridor_walls.clear
        min_story_corridor_walls << corridor_wall
        min_story_corridor_wall_minz = minz
      elsif (minz - min_story_corridor_wall_minz).abs < 0.001
        min_story_corridor_walls << corridor_wall
      end
    end

    # Prioritize corridor surfaces if available
    unless min_story_corridor_walls.size == 0
      min_story_avail_walls = min_story_corridor_walls
    end

    unit_has_door = true
    if min_story_avail_walls.size == 0
      runner.registerWarning("Could not find appropriate surface for the door. No door was added.")
      unit_has_door = false
    end

    door_sub_surface = nil
    min_story_avail_walls.each do |min_story_avail_wall|
      wall_gross_area = UnitConversions.convert(min_story_avail_wall.grossArea, "m^2", "ft^2")

      # Try to place door on any surface with enough area
      next if door_area >= wall_gross_area

      facade = Geometry.get_facade_for_surface(min_story_avail_wall)

      if (door_offset + door_width) * door_height > wall_gross_area
        # Reduce door offset to fit door on surface
        door_offset = 0
      end

      num_existing_doors_on_this_surface = 0
      min_story_avail_wall.subSurfaces.each do |sub_surface|
        if sub_surface.subSurfaceType.downcase == "door"
          num_existing_doors_on_this_surface += 1
        end
      end
      new_door_offset = door_offset + (door_offset + door_width) * num_existing_doors_on_this_surface

      # Create door vertices in relative coordinates
      upperleft = [new_door_offset, door_height]
      upperright = [new_door_offset + door_width, door_height]
      lowerright = [new_door_offset + door_width, 0]
      lowerleft = [new_door_offset, 0]

      # Convert to 3D geometry; assign to surface
      door_polygon = OpenStudio::Point3dVector.new
      if facade == Constants.FacadeFront
        multx = 1
        multy = 0
      elsif facade == Constants.FacadeBack
        multx = -1
        multy = 0
      elsif facade == Constants.FacadeLeft
        multx = 0
        multy = -1
      elsif facade == Constants.FacadeRight
        multx = 0
        multy = 1
      end
      if facade == Constants.FacadeBack or facade == Constants.FacadeLeft
        leftx = Geometry.getSurfaceXValues([min_story_avail_wall]).max
        lefty = Geometry.getSurfaceYValues([min_story_avail_wall]).max
      else
        leftx = Geometry.getSurfaceXValues([min_story_avail_wall]).min
        lefty = Geometry.getSurfaceYValues([min_story_avail_wall]).min
      end
      bottomz = Geometry.getSurfaceZValues([min_story_avail_wall]).min

      [upperleft, lowerleft, lowerright, upperright].each do |coord|
        newx = UnitConversions.convert(leftx + multx * coord[0], "ft", "m")
        newy = UnitConversions.convert(lefty + multy * coord[0], "ft", "m")
        newz = UnitConversions.convert(bottomz + coord[1], "ft", "m")
        door_vertex = OpenStudio::Point3d.new(newx, newy, newz)
        door_polygon << door_vertex
      end

      door_sub_surface = OpenStudio::Model::SubSurface.new(door_polygon, model)
      door_sub_surface.setName("#{min_story_avail_wall.name} - Door")
      door_sub_surface.setSubSurfaceType("Door")
      door_sub_surface.setSurface(min_story_avail_wall)
      if not construction.nil?
        door_sub_surface.setConstruction(construction)
      end

      break
    end

    if door_sub_surface.nil? and unit_has_door
      runner.registerWarning("Could not find appropriate surface for the door. No door was added.")
    elsif not door_sub_surface.nil?
      runner.registerInfo("Added #{door_area.round(1)} ft^2 door.")
    end

    return true
  end

  def self.space_has_roof(space)
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != "roofceiling"
      next if surface.outsideBoundaryCondition.downcase != "outdoors"
      next if surface.tilt == 0

      return true
    end
    return false
  end

  def self.create_single_family_attached(runner:,
                                         model:,
                                         **remainder)

    return true
  end

  def self.create_multifamily(runner:,
                              model:,
                              ffa:,
                              wall_height:,
                              aspect_ratio:,
                              level:,
                              horizontal_location:,
                              corridor_position:,
                              corridor_width:,
                              inset_width:,
                              inset_depth:,
                              inset_position:,
                              balcony_depth:,
                              foundation_type:,
                              foundation_height:,
                              **remainder)
    num_units = 2
    num_floors = 1

    if foundation_type == "slab"
      foundation_height = 0.0
    elsif foundation_type == "unfinished basement"
      foundation_height = 8.0
    end
    num_units_per_floor = num_units / num_floors
    num_units_per_floor_actual = num_units_per_floor

    if (num_floors > 1) and (level != "Bottom")
      runner.registerWarning("Unit is not on the bottom floor, setting foundation height to 0.")
      foundation_height = 0
    end

    if (num_units_per_floor % 2 == 0) and (corridor_position == "Double-Loaded Interior" or corridor_position == "Double Exterior")
      unit_depth = 2
      unit_width = num_units_per_floor / 2
      has_rear_units = true
    else
      unit_depth = 1
      unit_width = num_units_per_floor
      has_rear_units = false
    end

    # error checking
    if model.getSpaces.size > 0
      runner.registerError("Starting model is not empty.")
      return false
    end
    # if foundation_type == "crawlspace" and (foundation_height < 1.5 or foundation_height > 5.0)
    #   runner.registerError("The crawlspace height can be set between 1.5 and 5 ft.")
    #   return false
    # end
    if num_units % num_floors != 0
      runner.registerError("The number of units must be divisible by the number of floors.")
      return false
    end
    if (!has_rear_units) and (corridor_position == "Double-Loaded Interior" or corridor_position == "Double Exterior")
      runner.registerWarning("Specified incompatible corridor; setting corridor position to 'Single Exterior (Front)'.")
      corridor_position = "Single Exterior (Front)"
    end
    if aspect_ratio < 0
      runner.registerError("Invalid aspect ratio entered.")
      return false
    end
    if corridor_width == 0 and corridor_position != "None"
      corridor_position = "None"
    end
    if corridor_position == "None"
      corridor_width = 0
    end
    if corridor_width < 0
      runner.registerError("Invalid corridor width entered.")
      return false
    end
    if balcony_depth > 0 and inset_width * inset_depth == 0
      runner.registerWarning("Specified a balcony, but there is no inset.")
      balcony_depth = 0
    end
    if unit_width < 3 and horizontal_location == "Middle"
      runner.registerError("No middle horizontal location exists.")
      return false
    end

    # Convert to SI
    ffa = UnitConversions.convert(ffa, "ft^2", "m^2")
    wall_height = UnitConversions.convert(wall_height, "ft", "m")
    foundation_height = UnitConversions.convert(foundation_height, "ft", "m")

    space_types_hash = {}

    # starting spaces
    runner.registerInitialCondition("The building started with #{model.getSpaces.size} spaces.")

    # calculate the dimensions of the unit
    footprint = ffa + inset_width * inset_depth
    x = Math.sqrt(footprint / aspect_ratio)
    y = footprint / x

    foundation_corr_polygon = nil
    foundation_front_polygon = nil
    foundation_back_polygon = nil

    # create the front prototype unit footprint
    nw_point = OpenStudio::Point3d.new(0, 0, 0)
    ne_point = OpenStudio::Point3d.new(x, 0, 0)
    sw_point = OpenStudio::Point3d.new(0, -y, 0)
    se_point = OpenStudio::Point3d.new(x, -y, 0)

    if inset_width * inset_depth > 0
      if inset_position == "Right"
        # unit footprint
        inset_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y, 0)
        front_point = OpenStudio::Point3d.new(x - inset_width, -y, 0)
        side_point = OpenStudio::Point3d.new(x, inset_depth - y, 0)
        living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, side_point, inset_point, front_point)
        # unit balcony
        if balcony_depth > 0
          inset_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y, wall_height)
          side_point = OpenStudio::Point3d.new(x, inset_depth - y, wall_height)
          se_point = OpenStudio::Point3d.new(x, inset_depth - y - balcony_depth, wall_height)
          front_point = OpenStudio::Point3d.new(x - inset_width, inset_depth - y - balcony_depth, wall_height)
          shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([front_point, se_point, side_point, inset_point]), model)
        end
      else
        # unit footprint
        inset_point = OpenStudio::Point3d.new(inset_width, inset_depth - y, 0)
        front_point = OpenStudio::Point3d.new(inset_width, -y, 0)
        side_point = OpenStudio::Point3d.new(0, inset_depth - y, 0)
        living_polygon = Geometry.make_polygon(side_point, nw_point, ne_point, se_point, front_point, inset_point)
        # unit balcony
        if balcony_depth > 0
          inset_point = OpenStudio::Point3d.new(inset_width, inset_depth - y, wall_height)
          side_point = OpenStudio::Point3d.new(0, inset_depth - y, wall_height)
          sw_point = OpenStudio::Point3d.new(0, inset_depth - y - balcony_depth, wall_height)
          front_point = OpenStudio::Point3d.new(inset_width, inset_depth - y - balcony_depth, wall_height)
          shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([front_point, sw_point, side_point, inset_point]), model)
        end
      end
    else
      living_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)
    end

    # foundation
    if foundation_height > 0 and foundation_front_polygon.nil?
      foundation_front_polygon = living_polygon
    end

    # create living zone
    living_zone = OpenStudio::Model::ThermalZone.new(model)
    living_zone.setName("living zone")

    # first floor front
    living_spaces_front = []
    living_space = OpenStudio::Model::Space::fromFloorPrint(living_polygon, wall_height, model)
    living_space = living_space.get
    living_space.setName("living space")
    if space_types_hash.keys.include? Constants.SpaceTypeLiving
      living_space_type = space_types_hash[Constants.SpaceTypeLiving]
    else
      living_space_type = OpenStudio::Model::SpaceType.new(model)
      living_space_type.setStandardsSpaceType(Constants.SpaceTypeLiving)
      space_types_hash[Constants.SpaceTypeLiving] = living_space_type
    end
    living_space.setSpaceType(living_space_type)
    living_space.setThermalZone(living_zone)

    # add the balcony
    if balcony_depth > 0
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface_group.setSpace(living_space)
      shading_surface.setShadingSurfaceGroup(shading_surface_group)
    end
    living_spaces_front << living_space

    ##############################################################################################
    # Map unit location to adiabatic surfaces
    horz_hash = { "Left" => ["right"], "Right" => ["left"], "Middle" => ["left", "right"], "None" => [] }
    level_hash = { "Bottom" => ["RoofCeiling"], "Top" => ["Floor"], "Middle" => ["RoofCeiling", "Floor"], "None" => [] }
    adb_facade = horz_hash[horizontal_location]
    adb_level = level_hash[level]

    # Check levels
    if num_floors == 1
      adb_level = []
    end
    # Check for exposed left and right facades
    if num_units_per_floor == 1 or (num_units_per_floor == 2 and has_rear_units == true)
      adb_facade = []
    end
    if (has_rear_units == true)
      adb_facade += ["back"]
    end

    adiabatic_surf = adb_facade + horz_hash[horizontal_location] + level_hash[level]
    # Make surfaces adiabatic
    model.getSpaces.each do |space|
      # Store has_rear_units to call in the door geometry measure
      space.surfaces.each do |surface|
        os_facade = Geometry.get_facade_for_surface(surface)
        if surface.surfaceType == "Wall"
          if adb_facade.include? os_facade
            x_ft = UnitConversions.convert(x, "m", "ft")
            max_x = Geometry.getSurfaceXValues([surface]).max
            min_x = Geometry.getSurfaceXValues([surface]).min
            next if ((max_x - x_ft).abs >= 0.01) and min_x > 0

            surface.setOutsideBoundaryCondition("Adiabatic")
          end
        else
          if (adb_level.include? surface.surfaceType)
            surface.setOutsideBoundaryCondition("Adiabatic")
          end
        end
      end
    end
    ##############################################################################################

    if (corridor_position == "Double-Loaded Interior")
      interior_corridor_width = corridor_width / 2 # Only half the corridor is attached to a unit
      # corridors
      if corridor_width > 0
        # create the prototype corridor
        nw_point = OpenStudio::Point3d.new(0, interior_corridor_width, 0)
        ne_point = OpenStudio::Point3d.new(x, interior_corridor_width, 0)
        sw_point = OpenStudio::Point3d.new(0, 0, 0)
        se_point = OpenStudio::Point3d.new(x, 0, 0)
        corr_polygon = Geometry.make_polygon(sw_point, nw_point, ne_point, se_point)

        if foundation_height > 0 and foundation_corr_polygon.nil?
          foundation_corr_polygon = corr_polygon
        end

        # create corridor zone
        corridor_zone = OpenStudio::Model::ThermalZone.new(model)
        corridor_zone.setName("corridor zone")
        corridor_space = OpenStudio::Model::Space::fromFloorPrint(corr_polygon, wall_height, model)
        corridor_space = corridor_space.get
        corridor_space_name = "corridor space"
        corridor_space.setName(corridor_space_name)
        if space_types_hash.keys.include? "corridor"
          corridor_space_type = space_types_hash["corridor"]
        else
          corridor_space_type = OpenStudio::Model::SpaceType.new(model)
          corridor_space_type.setStandardsSpaceType("corridor")
          space_types_hash["corridor"] = corridor_space_type
        end

        corridor_space.setSpaceType(corridor_space_type)
        corridor_space.setThermalZone(corridor_zone)

        # Make walls of corridor adiabatic
        if has_rear_units == true
          corridor_space.surfaces.each do |surface|
            os_facade = Geometry.get_facade_for_surface(surface)
          end
        end
      end

    elsif corridor_position == "Double Exterior" or corridor_position == "Single Exterior (Front)"
      interior_corridor_width = 0
      # front access
      nw_point = OpenStudio::Point3d.new(0, -y, wall_height)
      sw_point = OpenStudio::Point3d.new(0, -y - corridor_width, wall_height)
      ne_point = OpenStudio::Point3d.new(x, -y, wall_height)
      se_point = OpenStudio::Point3d.new(x, -y - corridor_width, wall_height)

      shading_surface = OpenStudio::Model::ShadingSurface.new(OpenStudio::Point3dVector.new([sw_point, se_point, ne_point, nw_point]), model)
      shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
      shading_surface.setShadingSurfaceGroup(shading_surface_group)
      shading_surface.setName("Corridor shading")
    end

    # foundation
    if foundation_height > 0
      foundation_spaces = []

      # foundation corridor
      if corridor_width > 0 and corridor_position == "Double-Loaded Interior"
        corridor_space = OpenStudio::Model::Space::fromFloorPrint(foundation_corr_polygon, foundation_height, model)
        corridor_space = corridor_space.get
        m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
        m[2, 3] = foundation_height
        corridor_space.changeTransformation(OpenStudio::Transformation.new(m))
        corridor_space.setXOrigin(0)
        corridor_space.setYOrigin(0)
        corridor_space.setZOrigin(0)

        foundation_spaces << corridor_space
      end

      # foundation front
      foundation_space_front = []
      foundation_space = OpenStudio::Model::Space::fromFloorPrint(foundation_front_polygon, foundation_height, model)
      foundation_space = foundation_space.get
      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      m[2, 3] = foundation_height
      foundation_space.changeTransformation(OpenStudio::Transformation.new(m))
      foundation_space.setXOrigin(0)
      foundation_space.setYOrigin(0)
      foundation_space.setZOrigin(0)

      foundation_space_front << foundation_space
      foundation_spaces << foundation_space

      # put all of the spaces in the model into a vector
      spaces = OpenStudio::Model::SpaceVector.new
      model.getSpaces.each do |space|
        spaces << space
      end

      # intersect and match surfaces for each space in the vector
      OpenStudio::Model.intersectSurfaces(spaces)
      OpenStudio::Model.matchSurfaces(spaces)

      if (["crawlspace", "unfinished basement"].include? foundation_type)
        foundation_space = Geometry.make_one_space_from_multiple_spaces(model, foundation_spaces)
        if foundation_type == "crawlspace"
          foundation_space.setName("crawl space")
          foundation_zone = OpenStudio::Model::ThermalZone.new(model)
          foundation_zone.setName("crawl zone")
          foundation_space.setThermalZone(foundation_zone)
          foundation_space_type_name = Constants.SpaceTypeCrawl
        elsif foundation_type == "unfinished basement"
          foundation_space.setName("unfinished basement space")
          foundation_zone = OpenStudio::Model::ThermalZone.new(model)
          foundation_zone.setName("unfinished basement zone")
          foundation_space.setThermalZone(foundation_zone)
          foundation_space_type_name = Constants.SpaceTypeUnfinishedBasement
        end
        if space_types_hash.keys.include? foundation_space_type_name
          foundation_space_type = space_types_hash[foundation_space_type_name]
        else
          foundation_space_type = OpenStudio::Model::SpaceType.new(model)
          foundation_space_type.setStandardsSpaceType(foundation_space_type_name)
          space_types_hash[foundation_space_type_name] = foundation_space_type
        end
        foundation_space.setSpaceType(foundation_space_type)
      end

      # set foundation walls to ground
      spaces = model.getSpaces
      spaces.each do |space|
        if Geometry.get_space_floor_z(space) + UnitConversions.convert(space.zOrigin, "m", "ft") < 0
          surfaces = space.surfaces
          surfaces.each do |surface|
            next if surface.surfaceType.downcase != "wall"

            surface.setOutsideBoundaryCondition("Foundation")
          end
        end
      end

    end

    # put all of the spaces in the model into a vector
    spaces = OpenStudio::Model::SpaceVector.new
    model.getSpaces.each do |space|
      spaces << space
    end

    # intersect and match surfaces for each space in the vector
    OpenStudio::Model.intersectSurfaces(spaces)
    OpenStudio::Model.matchSurfaces(spaces)

    # make all surfaces adjacent to corridor spaces into adiabatic surfaces
    model.getSpaces.each do |space|
      next unless space.spaceType.get.standardsSpaceType.get == "corridor"

      space.surfaces.each do |surface|
        if surface.adjacentSurface.is_initialized # only set to adiabatic if the corridor surface is adjacent to another surface
          surface.adjacentSurface.get.setOutsideBoundaryCondition("Adiabatic")
          surface.setOutsideBoundaryCondition("Adiabatic")
        end
      end
    end

    # set foundation outside boundary condition to Kiva "foundation"
    model.getSurfaces.each do |surface|
      next if surface.outsideBoundaryCondition.downcase != "ground"

      surface.setOutsideBoundaryCondition("Foundation")
    end

    return true
  end
end
