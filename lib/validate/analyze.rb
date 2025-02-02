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
    test_dictionary_checker
    validate_output_files_exist
    validate_scraper_analysis_structure
    validate_scraper_analysis_values
    validate_debug_analysis_structure
    validate_word_extraction
    validate_repo_classifications
    puts "Analysis validation passed successfully!"
  end

  private

  def test_dictionary_checker
    checker = DictionaryChecker.new

    test_cases = [
      # [word, expected_result, description]
      ['word', true, 'Known word'],
      ['development', true, 'Common word list'],
      ['xyz123', false, 'Contains numbers'],
      ['word123apple', false, 'Numbers between words'],
      ['gllop', false, 'Unknown word'],
      ['swamp', true, 'Known English word']
    ]

    test_cases.each do |word, expected, description|
      result = checker.known?(word)
      abort "Failed: '#{word}' (#{description}) - expected #{expected}, got #{result}" unless result == expected

      # Verify caching
      cached_result = checker.known?(word)
      abort "Failed: '#{word}' - caching issue, got different result on second call" unless cached_result == result
    end
  end

  def validate_output_files_exist
    ANALYSIS_OUTPUT_FILES.each do |file|
      abort("Error: Output file #{file} does not exist") unless File.exist?(file)
      abort("Error: Output file #{file} has no content") unless File.size?(file)
    end
  end

  def validate_scraper_analysis_structure
    # First, validate debug file
    debug_data = YAML.load_file(ANALYSIS_RESULTS_FILE)

    # Count empty arrays in debug file
    empty_words_from_strings = debug_data[:active_repos].values.count { |repo_data| repo_data[:words_from_strings].empty? }
    empty_words_from_urls = debug_data[:active_repos].values.count { |repo_data| repo_data[:words_from_urls].empty? }
    total_repos = debug_data[:active_repos].size

    if ENV['DEBUG']
      puts "Debug file stats:"
      puts "  Total repos: #{total_repos}"
      puts "  Repos with empty words_from_strings: #{empty_words_from_strings}"
      puts "  Repos with empty words_from_urls: #{empty_words_from_urls}"
    end

    # Read the JS file contents
    content = File.read(SCRAPER_ANALYSIS_FILE)

    # Check for required exports
    abort("Error: Missing scraperDateTime export in JS file") unless content.include?('export const scraperDateTime')
    abort("Error: Missing scraperData export in JS file") unless content.include?('export const scraperData')
    abort("Error: Missing ignoreWords export in JS file") unless content.include?('export const ignoreWords')

    # Extract scraperData JSON-like content
    scraper_data_match = content.match(/export const scraperData\s*=\s*(\{.*?\});/m)
    abort("Error: Could not extract scraperData from JS file") unless scraper_data_match

    begin
      # Convert JavaScript object to valid JSON
      json_content = scraper_data_match[1]
        .gsub(/(\w+):/, '"\1":')  # Quote keys
        .gsub(/'([^']*)'/, '"\1"')  # Convert single quotes to double quotes

      # Parse the JSON
      parsed_data = JSON.parse(json_content, symbolize_names: true)

      # Validate scraperData structure
      parsed_data.each do |repo_name, repo_data|
        # Ensure required keys exist and are arrays
        [:words_from_strings, :words_from_urls, :url_patterns].each do |key|
          abort("Error: Missing #{key} for #{repo_name} in JS file") unless repo_data.key?(key)
          abort("Error: #{key} must be an array for #{repo_name} in JS file") unless repo_data[key].is_a?(Array)
        end
      end

      # Count empty arrays in JS file
      js_empty_words_from_strings = parsed_data.values.count { |repo_data| repo_data[:words_from_strings].empty? }
      js_empty_words_from_urls = parsed_data.values.count { |repo_data| repo_data[:words_from_urls].empty? }
      js_total_repos = parsed_data.size

      if ENV['DEBUG']
        puts "JS file stats:"
        puts "  Total repos: #{js_total_repos}"
        puts "  Repos with empty words_from_strings: #{js_empty_words_from_strings}"
        puts "  Repos with empty words_from_urls: #{js_empty_words_from_urls}"
      end

      # Validate consistency between debug file and JS file
      abort("Mismatch in total repos between debug file (#{total_repos}) and JS file (#{js_total_repos})") if total_repos != js_total_repos

      # Check for reasonable number of empty arrays
      max_empty_words_from_strings = (total_repos * 0.4).ceil  # Allow up to 40% empty
      max_empty_words_from_urls = (total_repos * 0.4).ceil     # Allow up to 40% empty

      abort("Too many repos with empty words_from_strings: #{js_empty_words_from_strings} (max #{max_empty_words_from_strings})") if js_empty_words_from_strings > max_empty_words_from_strings
      abort("Too many repos with empty words_from_urls: #{js_empty_words_from_urls} (max #{max_empty_words_from_urls})") if js_empty_words_from_urls > max_empty_words_from_urls
    rescue JSON::ParserError => e
      abort("Error parsing scraperData in JS file: #{e.message}")
    end
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
        abort("Error: scraperDateTime not in ISO 8601 format. Current value: #{datetime_value.inspect}, "\
              "converted value: #{parsed_time.iso8601.inspect}")
      end
    rescue ArgumentError
      abort("Error: Invalid datetime format. Value: #{datetime_value}")
    end

    # Extract scraperData JSON-like content
    scraper_data_match = content.match(/export const scraperData\s*=\s*(\{.*?\});/m)
    abort("Error: Could not extract scraperData") unless scraper_data_match

    begin
      # Convert JavaScript object to valid JSON
      json_content = scraper_data_match[1]
        .gsub(/(\w+):/, '"\1":')  # Quote keys
        .gsub(/'([^']*)'/, '"\1"')  # Convert single quotes to double quotes

      # Parse the JSON
      parsed_data = JSON.parse(json_content, symbolize_names: true)
    
      parsed_data.each do |repo_name, repo_data|
        # Ensure words are unique and lowercase
        assert_unique_lowercase_array(repo_data[:words_from_strings], "words_from_strings", repo_name)
        assert_unique_lowercase_array(repo_data[:words_from_urls], "words_from_urls", repo_name)
      
        # Ensure URL patterns are unique
        assert_unique_array(repo_data[:url_patterns], "url_patterns", repo_name)
      end

      puts "Validated scraperDateTime: #{datetime_value}"
    rescue JSON::ParserError => e
      abort("Error parsing scraperData: #{e.message}")
    end
  end

  def validate_debug_analysis_structure
    debug_data = YAML.load_file(ANALYSIS_RESULTS_FILE)

    # Check stats
    stats = debug_data[:stats]
    abort("Error: Missing stats") unless stats

    required_stats_keys = RepoScanner::IGNORE_REASONS.map(&:to_sym)

    required_stats_keys.each do |key|
      abort("Error: Missing stats key #{key}") unless stats.key?(key)
    end

    # Check repos structure
    abort("Error: Missing active_repos in debug analysis") unless debug_data[:active_repos]&.any?
    abort("Error: Missing ignored_repos in debug analysis") unless debug_data[:ignored_repos]&.any?

    # New checks for word extraction
    debug_data[:active_repos].each do |repo_name, repo_data|
      # Check that words_from_strings and words_from_urls are present
      abort("Error: Missing words_from_strings for #{repo_name}") unless repo_data.key?(:words_from_strings)
      abort("Error: Missing words_from_urls for #{repo_name}") unless repo_data.key?(:words_from_urls)

      # Ensure these are arrays
      abort("Error: words_from_strings must be an array for #{repo_name}") unless repo_data[:words_from_strings].is_a?(Array)
      abort("Error: words_from_urls must be an array for #{repo_name}") unless repo_data[:words_from_urls].is_a?(Array)
    end
  end

  def validate_word_extraction
    dictionary = DictionaryChecker.new
    cmd = ScraperAnalyzer.new

    # Test word extraction against specification
    examples = [
      ['https://www.yarracity.vic.gov.au/MyPlanning-application-xsearch', ['/MyPlanning-application-xsearch']],
      ['https://www.planning.act.gov.au/development_applications?fromDate=20251012', ['/development_applications?fromDate=']]
    ]
    examples.each do |url, expected|
      paths = cmd.extract_url_paths([url])
      unless expected == paths
        abort("Error: extracted #{paths.inspect} from #{url}, expected #{expected.inspect}")
      end
    end

    # Test word extraction against specification
    examples = [
      ['/MyPlanning-application-xsearch', %w[myplanning-application-xsearch]],
      ['/development_applications?fromDate=20251012', %w[fromdate]]
    ]
    examples.each do |url, expected|
      words = cmd.extract_words([url], dictionary)
      unless expected == words
        abort("Error: extracted #{words.inspect} from #{url}, expected #{expected.inspect}")
      end
    end
    expected = examples.map { |_url, words| words }.flatten.sort.uniq
    got = dictionary.unknown_words.to_a.sort.uniq
    unless expected == got
      abort("Error: extracted #{got.inspect} form examples, expected #{expected.inspect}")
    end
  end

  def validate_repo_classifications
    # Read the debug analysis file
    results = YAML.load_file(ANALYSIS_RESULTS_FILE)
    repos = results[:active_repos]

    # Validate presence of different repo types
    classifications = repos.values.map { |repo| repo[:status] }.uniq

    assert classifications.include?('active'),
           "No active scrapers found in analysis, got: #{classifications.inspect}"

    # Validate active repos have required fields
    active_repos = repos.select { |_, repo| repo[:status] == 'active' }

    assert active_repos.any?, "No active repos found"

    empty_words_from_strings = empty_words_from_urls = 0
    active_repos.each do |name, repo|
      # Positively assert that :words key does NOT exist
      refute repo.key?(:words), "Active repo #{name} should not have :words key"

      assert repo.key?(:words_from_strings), "Active repo #{name} missing words_from_strings key"
      assert repo.key?(:words_from_urls), "Active repo #{name} missing words_from_urls key"
      assert repo.key?(:urls), "Active repo #{name} missing urls key"
      
      empty_words_from_urls += 1 if repo[:urls].empty?
      empty_words_from_strings += 1 if repo[:words_from_strings].empty?
    end

    assert empty_words_from_urls < 3,
           "Should have less than 3 repos with no urls, got: #{empty_words_from_urls}"
    assert empty_words_from_strings < 3,
           "Should have less than 3 repos with no words_from_strings, got: #{empty_words_from_strings}"

    # New test: Ensure no words are common to all repos
    common_words_from_strings = active_repos.values.map { |repo| repo[:words_from_strings] }.reduce(&:&)
    common_words_from_urls = active_repos.values.map { |repo| repo[:words_from_urls] }.reduce(&:&)
    
    assert common_words_from_strings.empty?, 
           "Found words common to all repos in words_from_strings: #{common_words_from_strings.inspect}"
    assert common_words_from_urls.empty?, 
           "Found words common to all repos in words_from_urls: #{common_words_from_urls.inspect}"
  end

  # Assertion method
  def assert(condition, message = nil)
    raise StandardError, message unless condition
  end

  def refute(condition, message = nil)
    raise StandardError, message if condition
  end

  def assert_unique_lowercase_array(array, array_name, repo_name)
    # Check for uniqueness
    unless array == array.uniq
      abort("Error: Duplicate entries in #{array_name} for #{repo_name}")
    end

    # Check for lowercase
    unless array == array.map(&:downcase)
      abort("Error: Non-lowercase entries in #{array_name} for #{repo_name}")
    end
  end

  def assert_unique_array(array, array_name, repo_name)
    # Check for uniqueness
    unless array == array.uniq
      abort("Error: Duplicate entries in #{array_name} for #{repo_name}")
    end
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
