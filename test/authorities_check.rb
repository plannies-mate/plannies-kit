#!/usr/bin/env ruby

require_relative '../lib/protection/authority_data_extractor'
require 'yaml'

Dir.glob("repos/multiple_*/lib/*/authorities.rb").each do |file|

  extractor = Protection::AuthorityDataExtractor.new(file)

  # Extract all authority data
  results = extractor.extract_authorities

  puts "=" * 80,
       "Authority Data Summary: #{file}",
      "=" * 80
  results.first(5).each do |name, url|
    puts "  #{name.inspect} => #{url.inspect}"
  end

  # Save full results to YAML file for further processing
  # output_file = "log/authority_extraction.yml"
  # FileUtils.mkdir_p(File.dirname(output_file))
  # File.write(output_file, results.to_yaml)
  #
  # puts "\nFull results saved to #{output_file}"
end