# frozen_string_literal: true

require 'tempfile'

module Protection
  class AuthorityDataExtractor
    class ExtractionError < StandardError; end

    attr_reader :file

    def initialize(file)
      @file = file
    end

    # Extract data from all authority files under repos/multiple_*/lib/*/authorities.rb
    def extract_authorities
      module_name = extract_module_name
      raise "No Module found" unless module_name

      begin
        # Create a temporary file to safely evaluate the Ruby code
        temp_file = create_temp_evaluation_file(module_name)

        # Execute the temporary file in a separate process for safety
        output = `ruby #{temp_file.path}`

        # puts "OUTPUT", output, "END"

        # Parse the YAML output
        full_data = YAML.safe_load(output, permitted_classes: [Symbol], symbolize_names: true)
        result = {}
        full_data.each do |authority, details|
          result[authority] =
            if details[:url]
              details[:url]
            elsif details[:subdomain]
              "https://#{details[:subdomain]}.greenlightopm.com/Search/GetList"
            end
        end
        result
      rescue => e
        raise ExtractionError, "Failed to load authorities: #{e.message}"
      ensure
        temp_file.unlink if temp_file
      end
    end

    private

    def extract_module_name
      content = File.read(@file)
      if (match = content.match(/module\s+([a-zA-Z0-9_:]+)/))
        match[1]
      else
        raise ExtractionError, "Could not find module name in #{@file}"
      end
    end

    def create_temp_evaluation_file(module_name)
      temp_file = Tempfile.new(%w[authority-eval- .rb])
      temp_file.write(<<~RUBY)
        #!/usr/bin/env ruby
        
        require 'yaml'

        # Contents  of #{@file}
        #{File.read(@file)}

        # Extract data
        puts #{module_name}::AUTHORITIES.to_yaml
      RUBY
      temp_file.close
      temp_file
    end

    # Validate the extracted data format
    def validate_authorities(data)
      raise ExtractionError, "Invalid authorities data format" unless data.is_a?(Hash)

      data.each do |authority, config|
        unless config.is_a?(Hash) && config[:url].is_a?(String)
          raise ExtractionError, "Invalid configuration for authority #{authority}"
        end
      end
      true
    end
  end
end
