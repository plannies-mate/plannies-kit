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
        abort("Error: scraperDateTime not in ISO 8601 format. Current value: #{datetime_value.inspect}, "\
              "converted value: #{parsed_time.iso8601.inspect}")
      end
    rescue ArgumentError
      abort("Error: Invalid datetime format. Value: #{datetime_value}")
    end

    # Additional checks can be added here if needed
    puts "Validated scraperDateTime: #{datetime_value}"
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
  end

  def validate_word_extraction
    dictionary = DictionaryChecker.new
    cmd = ScraperAnalyzer.new

    # Test word extraction against specification
    examples = [
      ['https://www.yarracity.vic.gov.au/MyPlanning-application-xsearch', ['/MyPlanning-application-xsearch']],
      ['https://www.planning.act.gov.au/development_applications?fromDate=20251012', ['/development_applications?fromDate=20251012']]
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

    active_repos.each do |name, repo|
      assert repo.key?(:urls), "Active repo #{name} missing URLs"
      assert repo.key?(:words), "Active repo #{name} missing words"
      assert !repo[:urls].empty?, "Active repo #{name} has no URLs"
      assert !repo[:words].empty?, "Active repo #{name} has no words"
      assert !repo[:words].include?('href'), "Active repo #{name} should not have href as a word"
    end
    assert !results[:unknown_words].include?('href'), "global unknown_words should not include href"
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
