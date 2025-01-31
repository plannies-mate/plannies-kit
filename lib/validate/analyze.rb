#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'json'
require 'set'
require 'open3'
require 'time'
require 'yaml'

require_relative '../process_base'
require_relative '../analyze'
require_relative 'repo_scanner'

class AnalyzeValidator < ProcessBase
  def validate
    validate_output_files_exist
    validate_scraper_analysis_structure
    validate_scraper_analysis_values
    validate_debug_analysis_structure
    validate_word_extraction
    validate_repo_classifications
    puts "Analysis validation passed successfully!"
  end

  private

  def validate_output_files_exist
    ANALYSIS_OUTPUT_FILES.each do |file|
      abort("Error: Output file #{file} does not exist") unless File.exist?(file)
      abort("Error: Output file #{file} has no content") unless File.size?(file)
    end
  end

  def validate_scraper_analysis_structure
    # Read the file contents
    content = File.read(SCRAPER_ANALYSIS_FILE)

    # Check for required exports
    abort("Error: Missing scraperDateTime export") unless content.include?('export const scraperDateTime')
    abort("Error: Missing scraperData export") unless content.include?('export const scraperData')
    abort("Error: Missing ignoreWords export") unless content.include?('export const ignoreWords')
  end

  def validate_scraper_analysis_values
    # Read the file contents
    content = File.read(SCRAPER_ANALYSIS_FILE)

    # Extract values using regex
    datetime_match = content.match(/export const scraperDateTime\s*=\s*['"]([^'"]+)['"]/)
    abort("Error: Could not extract scraperDateTime") unless datetime_match

    datetime_value = datetime_match[1]
    begin
      # Check if the datetime is in ISO 8601 format
      parsed_time = Time.iso8601(datetime_value)
      
      # Ensure it matches the original input
      unless datetime_value == parsed_time.iso8601
        abort("Error: scraperDateTime not in ISO 8601 format. Current value: #{datetime_value}")
      end
    rescue ArgumentError
      abort("Error: Invalid datetime format. Value: #{datetime_value}")
    end

    # Additional checks can be added here if needed
    puts "Validated scraperDateTime: #{datetime_value}"
  end

  def validate_debug_analysis_structure
    debug_data = JSON.parse(File.read(ANALYSIS_RESULTS_FILE))

    # Check metadata
    metadata = debug_data['metadata']
    abort("Error: Missing metadata") unless metadata

    required_metadata_keys = %w[generated_at repos_analyzed trivial_scrapers_skipped placeholder_scrapers_found no_scraper_file]

    required_metadata_keys.each do |key|
      abort("Error: Missing metadata key #{key}") unless metadata.key?(key)
    end

    # Check repos structure
    abort("Error: Missing repos in debug analysis") unless debug_data['repos']
  end

  def validate_word_extraction
    cmd = ScraperAnalyzer.new
    # Test word extraction against specification
    [
      ['https://www.yarracity.vic.gov.au/MyPlanning-application-xsearch', %w[myplanning xearch]],
      ['https://www.planning.act.gov.au/development_applications?fromDaste=20251012', %w[fromdate]]
    ].each do |url, expected|
      words = cmd.extract_words(url)
      unless expected == words
        abort("Error: extracted #{words.inspect} from #{url}, expected #{expected.inspect}")
      end
    end
  end

  def validate_repo_classifications
    # Read the ignored repos file
    ignored_repos = File.exist?(IGNORED_SCRAPERS_FILE) ? 
      YAML.load_file(IGNORED_SCRAPERS_FILE) : {}

    # Ensure all ignore reasons are represented
    RepoScanner::IGNORE_REASONS.each do |reason|
      assert ignored_repos.values.include?(reason), 
        "No repos found with ignore reason: #{reason}"
    end

    # Read the debug analysis file
    debug_data = JSON.parse(File.read(ANALYSIS_RESULTS_FILE))
    repos = debug_data['repos']

    # Validate presence of different repo types
    classifications = repos.values.map { |repo| repo['status'] }

    assert classifications.include?('active'), 
      "No active scrapers found in analysis"

    # Validate active repos have required fields
    active_repos = repos.select { |_, repo| repo['status'] == 'active' }
    
    refute active_repos.empty?, "No active repos found"
    
    active_repos.each do |name, repo|
      assert repo.key?('urls'), "Active repo #{name} missing URLs"
      assert repo.key?('words'), "Active repo #{name} missing words"
      assert !repo['urls'].empty?, "Active repo #{name} has no URLs"
      assert !repo['words'].empty?, "Active repo #{name} has no words"
    end
  end

  # Assertion method
  def assert(condition, message = nil)
    raise StandardError, message unless condition
  end

  def dictionary_word?(word)
    # Use aspell to check if word is in dictionary
    stdout, _, status = Open3.capture3("echo #{word} | aspell list")
    status.success? && stdout.strip.empty?
  end
end

if __FILE__ == $0
  validator = AnalyzeValidator.new
  validator.validate
end
