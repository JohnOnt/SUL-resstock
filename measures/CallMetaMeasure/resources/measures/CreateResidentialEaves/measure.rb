# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require "#{File.dirname(__FILE__)}/resources/constants"

# start the measure
class CreateResidentialEaves < OpenStudio::Ruleset::ModelUserScript

  def initialize_transformation_matrix(m)
    m[0,0] = 1
    m[1,1] = 1
    m[2,2] = 1
    m[3,3] = 1
    return m
  end

  def get_surface_dimensions(surface)
    least_x = 9e99
    greatest_x = -9e99
    least_y = 9e99
    greatest_y = -9e99
    least_z = 9e99
    greatest_z = -9e99
    surface.vertices.each do |vertex|
      if vertex.x < least_x
        least_x = vertex.x
      end
      if vertex.x > greatest_x
        greatest_x = vertex.x
      end
      if vertex.y < least_y
        least_y = vertex.y
      end
      if vertex.y > greatest_y
        greatest_y = vertex.y
      end
      if vertex.z > greatest_z
        greatest_z = vertex.z
      end
      if vertex.z < least_z
        least_z = vertex.z
      end
    end
    l = greatest_x - least_x
    w = greatest_y - least_y
    h = greatest_z - least_z  
    return l, w, h
  end
  
  def get_attic_height_increase(eaves_depth, surfaces)
    surfaces.each do |surface|
      next unless surface.surfaceType.downcase == "roofceiling" and surface.outsideBoundaryCondition.downcase == "outdoors"
      attic_length, attic_width, attic_height = get_surface_dimensions(surface)
      if attic_length > attic_width
        roof_pitch = attic_height / attic_width
      else
        roof_pitch = attic_height / attic_length
      end
      attic_increase = roof_pitch * eaves_depth          
      return attic_increase
    end
  end  
  
  def determine_roof_type(surfaces)
    roof_decks = []
    surfaces.each do |surface|
      next unless surface.surfaceType.downcase == "roofceiling" and surface.outsideBoundaryCondition.downcase == "outdoors"
      roof_decks << surface
    end
    if roof_decks.length == 1
      return Constants.RoofTypeFlat
    end
    roof_decks.each do |roof_deck|
      if roof_deck.vertices.length == 3
        return Constants.RoofTypeHip
      else
        lengths_of_sides = []
        lengths_of_sides << Math.sqrt((roof_deck.vertices[0].x - roof_deck.vertices[1].x) ** 2 + (roof_deck.vertices[0].y - roof_deck.vertices[1].y) ** 2 + (roof_deck.vertices[0].z - roof_deck.vertices[1].z) ** 2)
        lengths_of_sides << Math.sqrt((roof_deck.vertices[1].x - roof_deck.vertices[2].x) ** 2 + (roof_deck.vertices[1].y - roof_deck.vertices[2].y) ** 2 + (roof_deck.vertices[1].z - roof_deck.vertices[2].z) ** 2)
        lengths_of_sides << Math.sqrt((roof_deck.vertices[2].x - roof_deck.vertices[3].x) ** 2 + (roof_deck.vertices[2].y - roof_deck.vertices[3].y) ** 2 + (roof_deck.vertices[2].z - roof_deck.vertices[3].z) ** 2)
        lengths_of_sides << Math.sqrt((roof_deck.vertices[3].x - roof_deck.vertices[0].x) ** 2 + (roof_deck.vertices[3].y - roof_deck.vertices[0].y) ** 2 + (roof_deck.vertices[3].z - roof_deck.vertices[0].z) ** 2)
        if lengths_of_sides.uniq.length == 3
          return Constants.RoofTypeHip
        end
      end
    end    
    return Constants.RoofTypeGable
  end
  
  # human readable name
  def name
    return "Set Residential Eaves"
  end

  # human readable description
  def description
    return "Sets the eaves for the building."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Performs a series of affine transformations on the roof decks into shading surfaces."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make a choice argument for model objects
    roof_structure_display_names = OpenStudio::StringVector.new
    roof_structure_display_names << Constants.RoofStructureTrussCantilever
    roof_structure_display_names << Constants.RoofStructureRafter
	
    #make a choice argument for roof type
    roof_structure = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("roof_structure", roof_structure_display_names, true)
    roof_structure.setDisplayName("Roof Structure")
    roof_structure.setDescription("The roof structure of the building.")
    roof_structure.setDefaultValue(Constants.RoofStructureTrussCantilever)
    args << roof_structure	
	
    #make a choice argument for eaves depth
    eaves_depth = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("eaves_depth", true)
    eaves_depth.setDisplayName("Eaves Depth")
    eaves_depth.setUnits("ft")
    eaves_depth.setDescription("The eaves depth of the roof.")
    eaves_depth.setDefaultValue(2.0)
    args << eaves_depth 
  
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    roof_structure = runner.getStringArgumentValue("roof_structure",user_arguments)
    eaves_depth = OpenStudio.convert(runner.getDoubleArgumentValue("eaves_depth",user_arguments),"ft","m").get

    roof_type = determine_roof_type(model.getSurfaces)
    unless roof_type == Constants.RoofTypeGable or roof_type == Constants.RoofTypeFlat
      runner.registerError("Roof type not gable or flat.")
      return false
    end
    
    surfaces_modified = false
    
    case roof_type
    when Constants.RoofTypeGable
      
      attic_increase = get_attic_height_increase(eaves_depth, model.getSurfaces)
      
      model.getSurfaces.each do |surface|
        next unless ( surface.surfaceType.downcase == "roofceiling" or surface.surfaceType.downcase == "wall" ) and surface.outsideBoundaryCondition.downcase == "outdoors"      
        surfaces_modified = true
        
        # Truss, Cantilever
        if roof_structure == Constants.RoofStructureTrussCantilever
        
          # Roof Decks
          if surface.surfaceType.downcase == "roofceiling"

            # raise the roof decks
            m = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
            m[2,3] = attic_increase
            transformation = OpenStudio::Transformation.new(m)
            vertices = surface.vertices
            new_vertices = transformation * vertices
            surface.setVertices(new_vertices)

          # Attic Walls
          elsif surface.surfaceType.downcase == "wall" and surface.vertices.length == 3

            # raise the attic walls
            x_s = []
            y_s = []
            z_s = []
            vertices = surface.vertices
            vertices.each do |vertex|
              x_s << vertex.x
              y_s << vertex.y
              z_s << vertex.z
            end
            max_z = z_s.each_with_index.max
            top_pt = OpenStudio::Point3d.new(x_s[max_z[1]], y_s[max_z[1]], z_s[max_z[1]] + attic_increase)
            if x_s.uniq.size == 1 # orientation of this wall is along y-axis
              min_y = y_s.each_with_index.min
              max_y = y_s.each_with_index.max 
              min_pt = OpenStudio::Point3d.new(x_s[min_y[1]], y_s[min_y[1]] - eaves_depth, z_s[min_y[1]])
              max_pt = OpenStudio::Point3d.new(x_s[max_y[1]], y_s[max_y[1]] + eaves_depth, z_s[max_y[1]])
            else # orientation of this wall is along the x-axis
              min_x = x_s.each_with_index.min
              max_x = x_s.each_with_index.max 
              min_pt = OpenStudio::Point3d.new(x_s[min_x[1]] - eaves_depth, y_s[min_x[1]], z_s[min_x[1]])
              max_pt = OpenStudio::Point3d.new(x_s[max_x[1]] + eaves_depth, y_s[max_x[1]], z_s[max_x[1]])						
            end
            new_vertices = OpenStudio::Point3dVector.new
            new_vertices << top_pt
            new_vertices << min_pt
            new_vertices << max_pt
            surface.setVertices(new_vertices)
                      
          end
        
        end

        # get the surface orientation
        attic_length, attic_width, attic_height = get_surface_dimensions(surface)
        if attic_length > attic_width
          attic_run = attic_width
        else
          attic_run = attic_length
        end      
        
        # Eaves
        shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
        if surface.surfaceType.downcase == "roofceiling"
        
          # add the shading surfaces
          new_surface_down = surface.clone.to_Surface.get
          new_surface_left = surface.clone.to_Surface.get
          new_surface_right = surface.clone.to_Surface.get
          m_down_top = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_down_bottom = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_left_top_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_left_top_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_left_bottom_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_left_bottom_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_right_top_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_right_top_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_right_bottom_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_right_bottom_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))				
          vertices = new_surface_down.vertices
          z_offset = surface.space.get.zOrigin # shift the z coordinates of the vertices up by the z origin of the space
          if vertices[0].z != vertices[1].z
            # TODO
          else # vertices[0].z != vertices[3].z
            if vertices[0].x == vertices[3].x # slopes along y-axis
              if vertices[0].y > vertices[3].y # vertices[0] at the top and vertices[3] at the bottom
                if vertices[0].x > vertices[1].x # vertices[0] at the right and vertices[1] at the left
                  top_right = vertices[0]
                  top_left = vertices[1]
                  bottom_left = vertices[2]
                  bottom_right = vertices[3]
                else # vertices[1] at the right and vertices[0] at the left
                  top_left = vertices[0]
                  top_right = vertices[1]
                  bottom_right = vertices[2]
                  bottom_left = vertices[3]						
                end
                # slopes in neg y
                m_down_top[0,3] = 0
                m_down_top[1,3] = -attic_run
                m_down_top[2,3] = -attic_height + z_offset
                m_down_bottom[0,3] = 0
                m_down_bottom[1,3] = -eaves_depth
                m_down_bottom[2,3] = -attic_increase + z_offset
                m_left_top_left[0,3] = -eaves_depth
                m_left_top_left[1,3] = 0
                m_left_top_left[2,3] = 0 + z_offset
                m_left_top_right[0,3] = -attic_length
                m_left_top_right[1,3] = 0
                m_left_top_right[2,3] = 0 + z_offset
                m_left_bottom_right[0,3] = -attic_length
                m_left_bottom_right[1,3] = -eaves_depth
                m_left_bottom_right[2,3] = -attic_increase + z_offset
                m_left_bottom_left[0,3] = -eaves_depth
                m_left_bottom_left[1,3] = -eaves_depth
                m_left_bottom_left[2,3] = -attic_increase + z_offset
                m_right_top_left[0,3] = attic_length
                m_right_top_left[1,3] = 0
                m_right_top_left[2,3] = 0 + z_offset
                m_right_top_right[0,3] = eaves_depth
                m_right_top_right[1,3] = 0
                m_right_top_right[2,3] = 0 + z_offset
                m_right_bottom_right[0,3] = eaves_depth
                m_right_bottom_right[1,3] = -eaves_depth
                m_right_bottom_right[2,3] = -attic_increase + z_offset
                m_right_bottom_left[0,3] = attic_length
                m_right_bottom_left[1,3] = -eaves_depth
                m_right_bottom_left[2,3] = -attic_increase + z_offset							
              else # vertices[3] at the top and vertices[0] at the bottom
                if vertices[3].x > vertices[1].x # vertices [3] at the right and vertices[1] at the left
                  bottom_right = vertices[3]
                  bottom_left = vertices[2]
                  top_left = vertices[1]
                  top_right = vertices[0]
                else # vertices[1] at the right and vertices[3] at the left
                  bottom_left = vertices[3]
                  bottom_right = vertices[2]
                  top_right = vertices[1]
                  top_left = vertices[0]									
                end
                # slopes in pos y
                m_down_top[0,3] = 0
                m_down_top[1,3] = attic_run
                m_down_top[2,3] = -attic_height + z_offset
                m_down_bottom[0,3] = 0
                m_down_bottom[1,3] = eaves_depth
                m_down_bottom[2,3] = -attic_increase + z_offset
                m_left_top_left[0,3] = -eaves_depth
                m_left_top_left[1,3] = 0
                m_left_top_left[2,3] = 0 + z_offset
                m_left_top_right[0,3] = -attic_length
                m_left_top_right[1,3] = 0
                m_left_top_right[2,3] = 0 + z_offset
                m_left_bottom_right[0,3] = -attic_length
                m_left_bottom_right[1,3] = eaves_depth
                m_left_bottom_right[2,3] = -attic_increase + z_offset
                m_left_bottom_left[0,3] = -eaves_depth
                m_left_bottom_left[1,3] = eaves_depth
                m_left_bottom_left[2,3] = -attic_increase + z_offset
                m_right_top_left[0,3] = attic_length
                m_right_top_left[1,3] = 0
                m_right_top_left[2,3] = 0 + z_offset
                m_right_top_right[0,3] = eaves_depth
                m_right_top_right[1,3] = 0
                m_right_top_right[2,3] = 0 + z_offset
                m_right_bottom_right[0,3] = eaves_depth
                m_right_bottom_right[1,3] = eaves_depth
                m_right_bottom_right[2,3] = -attic_increase + z_offset
                m_right_bottom_left[0,3] = attic_length
                m_right_bottom_left[1,3] = eaves_depth
                m_right_bottom_left[2,3] = -attic_increase + z_offset						
              end
            else # slopes along x-axis
              if vertices[0].x > vertices[3].x # vertices[0] at the top and vertices[3] at the bottom
                if vertices[0].y > vertices[1].y # vertices[0] at the left and vertices[1] at right
                  bottom_right = vertices[2]
                  bottom_left = vertices[3]
                  top_left = vertices[0]
                  top_right = vertices[1]
                else # vertices[1] at the left and vertices[0] at right
                  bottom_left = vertices[2]
                  bottom_right = vertices[3]
                  top_right = vertices[0]
                  top_left = vertices[1]
                end
                # slopes in neg x
                m_down_top[0,3] = -attic_run
                m_down_top[1,3] = 0
                m_down_top[2,3] = -attic_height + z_offset
                m_down_bottom[0,3] = -eaves_depth
                m_down_bottom[1,3] = 0
                m_down_bottom[2,3] = -attic_increase + z_offset
                m_left_top_left[0,3] = 0
                m_left_top_left[1,3] = eaves_depth
                m_left_top_left[2,3] = 0 + z_offset
                m_left_top_right[0,3] = 0
                m_left_top_right[1,3] = attic_width
                m_left_top_right[2,3] = 0 + z_offset
                m_left_bottom_right[0,3] = -eaves_depth
                m_left_bottom_right[1,3] = attic_width
                m_left_bottom_right[2,3] = -attic_increase + z_offset
                m_left_bottom_left[0,3] = -eaves_depth
                m_left_bottom_left[1,3] = eaves_depth
                m_left_bottom_left[2,3] = -attic_increase + z_offset
                m_right_top_left[0,3] = 0
                m_right_top_left[1,3] = -attic_width
                m_right_top_left[2,3] = 0 + z_offset
                m_right_top_right[0,3] = 0
                m_right_top_right[1,3] = -eaves_depth
                m_right_top_right[2,3] = 0 + z_offset
                m_right_bottom_right[0,3] = -eaves_depth
                m_right_bottom_right[1,3] = -eaves_depth
                m_right_bottom_right[2,3] = -attic_increase + z_offset
                m_right_bottom_left[0,3] = -eaves_depth
                m_right_bottom_left[1,3] = -attic_width
                m_right_bottom_left[2,3] = -attic_increase + z_offset
              else # vertices[3] at the top and vertices[0] at the bottom
                if vertices[3].y > vertices[1].y # vertices[3] at the left and vertices[1] at right
                  bottom_right = vertices[3]
                  bottom_left = vertices[2]
                  top_left = vertices[1]
                  top_right = vertices[0]
                else # vertices[1] at the left and vertices[3] at right
                  bottom_left = vertices[3]
                  bottom_right = vertices[2]
                  top_right = vertices[1]
                  top_left = vertices[0]
                end
                # slopes in pos x
                m_down_top[0,3] = attic_run
                m_down_top[1,3] = 0
                m_down_top[2,3] = -attic_height + z_offset
                m_down_bottom[0,3] = eaves_depth
                m_down_bottom[1,3] = 0
                m_down_bottom[2,3] = -attic_increase + z_offset
                m_left_top_left[0,3] = 0
                m_left_top_left[1,3] = -eaves_depth
                m_left_top_left[2,3] = 0 + z_offset
                m_left_top_right[0,3] = 0
                m_left_top_right[1,3] = -attic_width
                m_left_top_right[2,3] = 0 + z_offset
                m_left_bottom_right[0,3] = eaves_depth
                m_left_bottom_right[1,3] = -attic_width
                m_left_bottom_right[2,3] = -attic_increase + z_offset
                m_left_bottom_left[0,3] = eaves_depth
                m_left_bottom_left[1,3] = -eaves_depth
                m_left_bottom_left[2,3] = -attic_increase + z_offset
                m_right_top_left[0,3] = 0
                m_right_top_left[1,3] = attic_width
                m_right_top_left[2,3] = 0 + z_offset
                m_right_top_right[0,3] = 0
                m_right_top_right[1,3] = eaves_depth
                m_right_top_right[2,3] = 0 + z_offset
                m_right_bottom_right[0,3] = eaves_depth
                m_right_bottom_right[1,3] = eaves_depth
                m_right_bottom_right[2,3] = -attic_increase + z_offset
                m_right_bottom_left[0,3] = eaves_depth
                m_right_bottom_left[1,3] = attic_width
                m_right_bottom_left[2,3] = -attic_increase + z_offset
              end			
            end						
          end
          
          # lower eaves
          transformation_down_top = OpenStudio::Transformation.new(m_down_top)
          transformation_down_bottom = OpenStudio::Transformation.new(m_down_bottom)
          new_vertices_down = OpenStudio::Point3dVector.new
          new_vertices_down << transformation_down_top * top_left
          new_vertices_down << transformation_down_top * top_right
          new_vertices_down << transformation_down_bottom * bottom_right
          new_vertices_down << transformation_down_bottom * bottom_left					
          new_surface_down.setVertices(new_vertices_down)		
          shading_surface = OpenStudio::Model::ShadingSurface.new(new_surface_down.vertices, model)
          shading_surface.setName("eaves")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)								
          new_surface_down.remove
          
          # left eaves
          transformation_left_top_left = OpenStudio::Transformation.new(m_left_top_left)
          transformation_left_top_right = OpenStudio::Transformation.new(m_left_top_right)
          transformation_left_bottom_right = OpenStudio::Transformation.new(m_left_bottom_right)
          transformation_left_bottom_left = OpenStudio::Transformation.new(m_left_bottom_left)
          new_vertices_left = OpenStudio::Point3dVector.new
          new_vertices_left << transformation_left_top_left * top_left
          new_vertices_left << transformation_left_top_right * top_right
          new_vertices_left << transformation_left_bottom_right * bottom_right
          new_vertices_left << transformation_left_bottom_left * bottom_left
          new_surface_left.setVertices(new_vertices_left)		
          shading_surface = OpenStudio::Model::ShadingSurface.new(new_surface_left.vertices, model)
          shading_surface.setName("eaves")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)								
          new_surface_left.remove

          # right eaves
          transformation_right_top_left = OpenStudio::Transformation.new(m_right_top_left)
          transformation_right_top_right = OpenStudio::Transformation.new(m_right_top_right)
          transformation_right_bottom_right = OpenStudio::Transformation.new(m_right_bottom_right)
          transformation_right_bottom_left = OpenStudio::Transformation.new(m_right_bottom_left)
          new_vertices_right = OpenStudio::Point3dVector.new
          new_vertices_right << transformation_right_top_left * top_left
          new_vertices_right << transformation_right_top_right * top_right
          new_vertices_right << transformation_right_bottom_right * bottom_right
          new_vertices_right << transformation_right_bottom_left * bottom_left
          new_surface_right.setVertices(new_vertices_right)		
          shading_surface = OpenStudio::Model::ShadingSurface.new(new_surface_right.vertices, model)
          shading_surface.setName("eaves")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)								
          new_surface_right.remove      
          
        end
        
      end      
     
    when Constants.RoofTypeFlat
    
      model.getSurfaces.each do |surface|
        next unless surface.surfaceType.downcase == "roofceiling" and surface.outsideBoundaryCondition.downcase == "outdoors"

          attic_length, attic_width, attic_height = get_surface_dimensions(surface)
        
          shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
          new_surface_left = surface.clone.to_Surface.get
          new_surface_right = surface.clone.to_Surface.get
          new_surface_bottom = surface.clone.to_Surface.get
          new_surface_top = surface.clone.to_Surface.get
          vertices = new_surface_left.vertices
          z_offset = surface.space.get.zOrigin # shift the z coordinates of the vertices up by the z origin of the space
          
          m_left_far = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_left_close = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_left_far[0,3] = -attic_length
          m_left_far[2,3] = z_offset
          m_left_close[0,3] = -eaves_depth
          m_left_close[2,3] = z_offset
          
          m_right_far = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_right_close = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_right_far[0,3] = attic_length
          m_right_far[2,3] = z_offset
          m_right_close[0,3] = eaves_depth
          m_right_close[2,3] = z_offset          
          
          m_bottom_far_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_bottom_far_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_bottom_close_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_bottom_close_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_bottom_far_left[0,3] = -eaves_depth
          m_bottom_far_left[1,3] = -attic_width
          m_bottom_far_left[2,3] = z_offset
          m_bottom_far_right[0,3] = eaves_depth
          m_bottom_far_right[1,3] = -attic_width
          m_bottom_far_right[2,3] = z_offset          
          m_bottom_close_left[0,3] = -eaves_depth
          m_bottom_close_left[1,3] = -eaves_depth
          m_bottom_close_left[2,3] = z_offset
          m_bottom_close_right[0,3] = eaves_depth
          m_bottom_close_right[1,3] = -eaves_depth
          m_bottom_close_right[2,3] = z_offset          
          
          m_top_far_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_top_far_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_top_close_left = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_top_close_right = initialize_transformation_matrix(OpenStudio::Matrix.new(4,4,0))
          m_top_far_left[0,3] = -eaves_depth
          m_top_far_left[1,3] = attic_width
          m_top_far_left[2,3] = z_offset
          m_top_far_right[0,3] = eaves_depth
          m_top_far_right[1,3] = attic_width
          m_top_far_right[2,3] = z_offset
          m_top_close_left[0,3] = -eaves_depth          
          m_top_close_left[1,3] = eaves_depth
          m_top_close_left[2,3] = z_offset
          m_top_close_right[0,3] = eaves_depth          
          m_top_close_right[1,3] = eaves_depth
          m_top_close_right[2,3] = z_offset          
          
          transformation_left_far = OpenStudio::Transformation.new(m_left_far)
          transformation_left_close = OpenStudio::Transformation.new(m_left_close)
          
          transformation_right_far = OpenStudio::Transformation.new(m_right_far)
          transformation_right_close = OpenStudio::Transformation.new(m_right_close)          
          
          transformation_bottom_far_left = OpenStudio::Transformation.new(m_bottom_far_left)
          transformation_bottom_far_right = OpenStudio::Transformation.new(m_bottom_far_right)
          transformation_bottom_close_left = OpenStudio::Transformation.new(m_bottom_close_left)
          transformation_bottom_close_right = OpenStudio::Transformation.new(m_bottom_close_right)
          
          transformation_top_far_left = OpenStudio::Transformation.new(m_top_far_left)
          transformation_top_far_right = OpenStudio::Transformation.new(m_top_far_right)
          transformation_top_close_left = OpenStudio::Transformation.new(m_top_close_left)
          transformation_top_close_right = OpenStudio::Transformation.new(m_top_close_right)

          if vertices[0].x < vertices[1].x
            top_left = vertices[3]
            top_right = vertices[2]
            bottom_right = vertices[1]
            bottom_left = vertices[0]
          elsif vertices[1].x < vertices[0].x
            top_left = vertices[1]
            top_right = vertices[0]
            bottom_right = vertices[3]
            bottom_left = vertices[2]            
          elsif vertices[0].x < vertices[3].x
            top_left = vertices[0]
            top_right = vertices[3]
            bottom_right = vertices[2]
            bottom_left = vertices[1]
          elsif vertices[3].x < vertices[0].x
            top_left = vertices[2]
            top_right = vertices[1]
            bottom_right = vertices[0]
            bottom_left = vertices[3]            
          end
          
          new_vertices_left = OpenStudio::Point3dVector.new
          new_vertices_left << transformation_left_far * top_right
          new_vertices_left << transformation_left_far * bottom_right
          new_vertices_left << transformation_left_close * bottom_left
          new_vertices_left << transformation_left_close * top_left               
          
          new_surface_left.setVertices(new_vertices_left)
          shading_surface = OpenStudio::Model::ShadingSurface.new(new_surface_left.vertices, model)
          shading_surface.setName("eaves")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)								
          new_surface_left.remove

          new_vertices_right = OpenStudio::Point3dVector.new
          new_vertices_right << transformation_right_far * top_left
          new_vertices_right << transformation_right_close * top_right
          new_vertices_right << transformation_right_close * bottom_right          
          new_vertices_right << transformation_right_far * bottom_left
          
          new_surface_right.setVertices(new_vertices_right)		
          shading_surface = OpenStudio::Model::ShadingSurface.new(new_surface_right.vertices, model)
          shading_surface.setName("eaves")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)								
          new_surface_right.remove

          new_vertices_bottom = OpenStudio::Point3dVector.new
          new_vertices_bottom << transformation_bottom_far_left * top_left
          new_vertices_bottom << transformation_bottom_far_right * top_right
          new_vertices_bottom << transformation_bottom_close_right * bottom_right
          new_vertices_bottom << transformation_bottom_close_left * bottom_left
          
          new_surface_bottom.setVertices(new_vertices_bottom)		
          shading_surface = OpenStudio::Model::ShadingSurface.new(new_surface_bottom.vertices, model)
          shading_surface.setName("eaves")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)								
          new_surface_bottom.remove
          
          new_vertices_top = OpenStudio::Point3dVector.new
          new_vertices_top << transformation_top_far_left * bottom_left
          new_vertices_top << transformation_top_close_left * top_left
          new_vertices_top << transformation_top_close_right * top_right
          new_vertices_top << transformation_top_far_right * bottom_right
          
          new_surface_top.setVertices(new_vertices_top)		
          shading_surface = OpenStudio::Model::ShadingSurface.new(new_surface_top.vertices, model)
          shading_surface.setName("eaves")
          shading_surface.setShadingSurfaceGroup(shading_surface_group)								
          new_surface_top.remove          
        
      end
      
    end
    
    if not surfaces_modified
      runner.registerAsNotApplicable("No surfaces found for adding eaves.")
      return true
    end
   
    return true

  end
  
end

# register the measure to be used by the application
CreateResidentialEaves.new.registerWithApplication
