require 'csv'

class TsvFile

    def initialize(full_path, runner)
        @full_path = full_path
        @filename = File.basename(full_path)
        @runner = runner
        @rows, @option_cols, @dependency_cols, @full_header, @header = get_file_data()
    end
    
    attr_accessor :dependency_cols, :rows, :option_cols, :header, :filename

    def get_file_data()
        option_key = "Option="
        dep_key = "Dependency="
    
        full_header = nil
        rows = []
        CSV.foreach(@full_path, { :col_sep => "\t" }) do |row|

            row.delete_if {|x| x.nil? or x.size == 0} # purge trailing empty fields

            # Store one header line
            if full_header.nil?
                full_header = row
                next
            end

            rows << row
        end
        
        if full_header.nil?
            register_error("Could not find header row in #{@filename.to_s}.", @runner)
        end
        
        # Strip out everything but options and dependencies from header
        header = full_header.select { |el| el.start_with?(option_key) or el.start_with?(dep_key) }
        
        # Get all option names/dependencies and corresponding column numbers on header row
        option_cols = {}
        dependency_cols = {}
        full_header.each_with_index do |d, col|
            next if d.nil?
            if d.strip.start_with?(option_key)
                val = d.strip.sub(option_key,"").strip
                option_cols[val] = col
            elsif d.strip.start_with?(dep_key)
                val = d.strip.sub(dep_key,"").strip
                dependency_cols[val] = col
            end
        end
        if option_cols.size == 0
            register_error("No options found in #{@filename.to_s}.", @runner)
        end
        
        return rows, option_cols, dependency_cols, full_header, header
    end

    def get_option_name_from_sample_number(sample_value, dependency_values)
        # Retrieve option name from probability file based on sample value
        
        matched_option_name = nil
        matched_row_num = nil
        deps_s = hash_to_string(dependency_values)
        
        @rows.each_with_index do |row, rownum|
        
            # Find appropriate row by matching dependency values
            found_row = false
            if dependency_values.nil? or dependency_values.size == 0
                found_row = true
            else
                num_deps_matched = 0
                dependency_values.each do |dep,dep_val|
                    next if row[@dependency_cols[dep]].nil?
                    if row[@dependency_cols[dep]].downcase == dep_val.downcase
                        num_deps_matched += 1
                        if num_deps_matched == dependency_values.size
                            found_row = true
                            break
                        end
                    end
                end
            end
            next if not found_row
        
            # Is this our second match?
            if not matched_row_num.nil?
                if deps_s.size > 0
                    register_error("Multiple rows (#{matched_row_num+2}, #{rownum+2}) found in #{@filename.to_s} with dependencies: #{deps_s.to_s}.", @runner)
                else
                    register_error("Multiple rows (#{matched_row_num+2}, #{rownum+2}) found in #{@filename.to_s}.", @runner)
                end
            end

            # Convert data to numeric row values
            rowvals = {}
            @option_cols.each do |option_name, option_col|
                if not row[option_col].is_number?
                    register_error("Field '#{row[option_col].to_s}' in #{@filename.to_s} must be numeric.", @runner)
                end
                rowvals[option_name] = row[option_col].to_f
            end
            
            # Sum of values within 2% of 100%?
            sum_rowvals = rowvals.values.reduce(:+)
            if sum_rowvals < 0.98 or sum_rowvals > 1.02
                register_error("Values in #{@filename.to_s} incorrectly sum to #{sum_rowvals.to_s}.", @runner)
            end
            
            # If values don't exactly sum to 1, normalize them
            if sum_rowvals != 1.0
                rowvals.each do |option_name, rowval|
                    rowvals[option_name] = rowval / sum_rowvals
                end
            end
            
            # Find appropriate value
            rowsum = 0
            @option_cols.each_with_index do |(option_name, option_col), index|
                rowsum += rowvals[option_name]
                if rowsum >= sample_value or (index == @option_cols.size-1 and rowsum + 0.00001 >= sample_value)
                    matched_option_name = option_name
                    matched_row_num = rownum
                    break
                end
            end
            
        end
        
        if matched_option_name.nil? or matched_option_name.size == 0
            if deps_s.size > 0
                register_error("Could not determine appropriate option in #{@filename.to_s} for sample value #{sample_value.to_s} with dependencies: #{deps_s.to_s}.", @runner)
            else
                register_error("Could not determine appropriate option in #{@filename.to_s} for sample value #{sample_value.to_s}.", @runner)
            end
            return matched_option_name
        end
        
        return matched_option_name, matched_row_num
    end
    
end

def check_file_exists(full_path, runner=nil)
    if not File.exist?(full_path)
        register_error("Cannot find file #{full_path.to_s}.", runner)
    end
end

def check_dir_exists(full_path, runner=nil)
    if not Dir.exist?(full_path)
        register_error("Cannot find directory #{full_path.to_s}.", runner)
    end
end
  
def get_parameters_ordered_from_options_lookup_tsv(resources_dir)
    # Obtain full list of parameters and their order
    params_file = File.join(resources_dir, 'options_lookup.tsv')
    if not File.exist?(params_file)
        fail "ERROR: Cannot find #{params_file}."
    end
    params = []
    CSV.foreach(params_file, { :col_sep => "\t" }) do |row|
        next if row.size < 2
        next if row[0].nil? or row[0].downcase == "parameter name" or row[1].nil?
        if not params.include?(row[0])
            params << row[0]
        end
    end
    
    return params
end
  
def get_combination_hashes(tsvfiles, dependencies)
    # Returns an array with hashes that include each combination of 
    # dependency values for the given dependencies.
    combos_hashes = []

    # Construct array of dependency value arrays
    depval_array = []
    dependencies.each do |dep|
        depval_array << tsvfiles[dep].option_cols.keys
    end
    
    if depval_array.size == 0
        return combos_hashes
    end
    
    # Create combinations
    combos = depval_array.first.product(*depval_array[1..-1])
    
    # Convert to combinations of hashes
    combos.each do |combo|
        # Convert to hash
        combo_hash = {}
        if combo.is_a?(String)
            combo_hash[dependencies[0]] = combo
        else
            dependencies.each_with_index do |dep, i|
                combo_hash[dep] = combo[i]
            end
        end
        combos_hashes << combo_hash
    end
    return combos_hashes
end
  
def get_value_from_runner_past_results(key_lookup, runner=nil)
    runner.past_results.each do |measure, measure_hash|
        measure_hash.each do |k, v|
            if k.to_s == key_lookup.to_s
                return v.to_s
            end
        end
    end
    register_error("Could not find past value for '#{key_lookup.to_s}'.", runner)
end
  
def get_measure_args_from_option_name(lookup_file, option_name, parameter_name, runner=nil)
    found_option = false
    measure_args = {}
    CSV.foreach(lookup_file, { :col_sep => "\t" }) do |row|
        next if row.size < 2
        if not found_option
            # Found option row?
            if not row[0].nil? and not row[1].nil? and row[0].downcase == parameter_name.downcase and row[1].downcase == option_name.downcase
                found_option = true
                if row.size >= 3 and not row[2].nil?
                    measure_dir = row[2]
                    args = {}
                    for col in 3..(row.size-1)
                        next if row[col].nil? or not row[col].include?("=")
                        data = row[col].split("=")
                        arg_name = data[0]
                        arg_val = data[1]
                        args[arg_name] = arg_val
                    end
                    measure_args[measure_dir] = args
                end
                next
            end
        else
            # Additional rows for option?
            if row[0].nil? and row[1].nil?
                if row.size >= 3 and not row[2].nil?
                    measure_dir = row[2]
                    args = {}
                    for col in 3..(row.size-1)
                        next if row[col].nil? or not row[col].include?("=")
                        data = row[col].split("=")
                        arg_name = data[0]
                        arg_val = data[1]
                        args[arg_name] = arg_val
                    end
                    measure_args[measure_dir] = args
                end
            else
                break # we're done searching
            end
        end
    end
    if not found_option
        register_error("Could not find parameter '#{parameter_name.to_s}' and option '#{option_name.to_s}' in #{lookup_file.to_s}.", runner)
    end
    return measure_args
end
  
def print_info(measure_args, measure_dir, option_name, runner)
    if measure_args.nil? or measure_dir.nil?
        runner.registerInfo("Assigning option '#{option_name.to_s}'.")
    else
        args_s = hash_to_string(measure_args, delim=" -> ", separator="\n")
        if args_s.size > 0
            runner.registerInfo("Assigning option '#{option_name.to_s}'.")
            runner.registerInfo("Calling #{measure_dir.to_s} measure with arguments:\n#{args_s}")
        else
            runner.registerInfo("Assigning option '#{option_name.to_s}'.")
            runner.registerInfo("Calling #{measure_dir.to_s} measure with no arguments.")
        end
    end
end

def get_measure_instance(measure_rb_path)
    # Parse XML file for class name
    require 'rexml/document'
    require 'rexml/xpath'
    xmldoc = REXML::Document.new(File.read(measure_rb_path.sub(".rb",".xml")))
    measure_class = REXML::XPath.first(xmldoc, "//measure/class_name").text
    # Create new instance
    require (measure_rb_path)
    measure = eval(measure_class).new
    return measure
end

def validate_measure_args(measure_args, provided_args, lookup_file, parameter_name, option_name, runner=nil)
    measure_arg_names = measure_args.map { |arg| arg.name }
    # Verify all arguments have been provided
    measure_args.each do |arg|
        next if provided_args.keys.include?(arg.name)
        register_error("Argument '#{arg.name}' not provided in #{lookup_file.to_s} for parameter '#{parameter_name.to_s}' and option '#{option_name.to_s}'.", runner)
    end
    provided_args.keys.each do |k|
        next if measure_arg_names.include?(k)
        register_error("Extra argument '#{k}' specified in #{lookup_file.to_s} for parameter '#{parameter_name.to_s}' and option '#{option_name.to_s}'.", runner)
    end
    # Check for valid argument values
    measure_args.each do |arg|
        # Get measure provided arg
        provided_val = provided_args[arg.name]
        if provided_val.nil?
            if arg.required
                register_error("Argument '#{arg.name.to_s}' for parameter '#{parameter_name.to_s}' and option '#{option_name.to_s}' must have a value provided.", runner)
            else
                next
            end
        end
        case arg.type.valueName.downcase
        when "boolean"
            if not ['true','false'].include?(provided_val)
                register_error("Value of '#{provided_val.to_s}' for argument '#{arg.name.to_s}', parameter '#{parameter_name.to_s}', and option '#{option_name.to_s}' must be 'true' or 'false'.", runner)
            end 
        when "double"
            if not provided_val.is_number?
                register_error("Value of '#{provided_val.to_s}' for argument '#{arg.name.to_s}', parameter '#{parameter_name.to_s}', and option '#{option_name.to_s}' must be a number.", runner)
            end
        when "integer"
            if not provided_val.is_integer?
                register_error("Value of '#{provided_val.to_s}' for argument '#{arg.name.to_s}', parameter '#{parameter_name.to_s}', and option '#{option_name.to_s}' must be an integer.", runner)
            end
        when "string"
            # no op
        when "choice"
            if not arg.choiceValues.include?(provided_val)
                register_error("Value of '#{provided_val.to_s}' for argument '#{arg.name.to_s}', parameter '#{parameter_name.to_s}', and option '#{option_name.to_s}' must be one of: #{arg.choiceValues.to_s}.", runner)
            end
        end
    end 
end
  
def get_argument_map(model, measure, provided_args, lookup_file, parameter_name, option_name, runner=nil)
    measure_args = measure.arguments(model)
    validate_measure_args(measure_args, provided_args, lookup_file, parameter_name, option_name, runner)
    
    # Convert to argument map needed by OS
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(measure_args)
    measure_args.each do |arg|
        temp_arg_var = arg.clone
        if provided_args[arg.name]
            temp_arg_var.setValue(provided_args[arg.name])
        end
        argument_map[arg.name] = temp_arg_var
    end
    return argument_map
end
  
def run_measure(model, measure, argument_map, runner)
    begin

      # run the measure
      runner_child = OpenStudio::Ruleset::OSRunner.new
      measure.run(model, runner_child, argument_map)
      result_child = runner_child.result

      # get initial and final condition
      if result_child.initialCondition.is_initialized
        runner.registerInitialCondition(result_child.initialCondition.get.logMessage)
      end
      if result_child.finalCondition.is_initialized
        runner.registerFinalCondition(result_child.finalCondition.get.logMessage)
      end

      # log messages
      result_child.warnings.each do |warning|
        runner.registerWarning(warning.logMessage)
      end
      result_child.info.each do |info|
        runner.registerInfo(info.logMessage)
      end
      result_child.errors.each do |error|
        runner.registerError(error.logMessage)
      end
      if result_child.errors.size > 0
        return false
      end

      # convert a return false in the measure to a return false and error here.
      if result_child.value.valueName == "Fail"
        runner.registerError("The measure was not successful")
        return false
      end

    rescue => e
      runner.registerError("Measure Failed with Error: #{e.backtrace.join("\n")}")
      return false
    end
    return true
end
  
def hash_to_string(hash, delim="=", separator=",")
    hash_s = ""
    hash.each do |k,v|
        hash_s << "#{k.to_s}#{delim.to_s}#{v.to_s}#{separator.to_s}"
    end
    if hash_s.size > 0
        hash_s = hash_s.chomp(separator.to_s)
    end
    return hash_s
end

def register_value(runner, parameter_name, option_name)
    runner.registerValue(parameter_name, option_name)
end

def register_error(msg, runner=nil)
    if not runner.nil?
        runner.registerError(msg)
        fail msg # OS 2.0 will handle this more gracefully
    else
        puts "ERROR: #{msg}"
        exit
    end
end

class String
  def is_number?
    true if Float(self) rescue false
  end
  
  def is_integer?
    if not self.is_number?
      return false
    end
    if Integer(Float(self)).to_f != Float(self)
      return false
    end
    return true
  end
end
