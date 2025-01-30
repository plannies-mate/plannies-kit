#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'json'
require 'set'
require 'open3'

require_relative '../process_base'

class AnalyzeValidator < ProcessBase
  SCRAPER_ANALYSIS_FILE = 'log/scraper_analysis.js'
  DEBUG_ANALYSIS_FILE = 'log/debug_analysis.json'

  def validate
    validate_output_files_exist
    validate_scraper_analysis_structure
    validate_debug_analysis_structure
    validate_word_extraction
    puts "Analysis validation passed successfully!"
  end

  private

  def validate_output_files_exist
    [SCRAPER_ANALYSIS_FILE, DEBUG_ANALYSIS_FILE].each do |file|
      abort("Error: Output file #{file} does not exist") unless File.exist?(file)
    end
  end

  def validate_scraper_analysis_structure
    content = File.read(SCRAPER_ANALYSIS_FILE)
    
    # Basic structure checks
    abort("Error: Missing scraperDateTime") unless content.include?('scraperDateTime')
    abort("Error: Missing scraperData") unless content.include?('scraperData')
    abort("Error: Missing ignoreWords") unless content.include?('ignoreWords')
  end

  def validate_debug_analysis_structure
    debug_data = JSON.parse(File.read(DEBUG_ANALYSIS_FILE))
    
    # Check metadata
    metadata = debug_data['metadata']
    abort("Error: Missing metadata") unless metadata
    
    required_metadata_keys = [
      'generated_at', 
      'repos_analyzed', 
      'trivial_scrapers_skipped', 
      'broken_scrapers_found', 
      'no_scraper_file'
    ]
    
    required_metadata_keys.each do |key|
      abort("Error: Missing metadata key #{key}") unless metadata.key?(key)
    end
    
    # Check repos structure
    abort("Error: Missing repos in debug analysis") unless debug_data['repos']
  end

  def validate_word_extraction
    # Test word extraction against specification
    test_urls = [
      'https://www.yarracity.vic.gov.au/MyPlanning-application-xsearch',
      'https://www.planning.act.gov.au/development_applications?fromDaste=20251012'
    ]

    test_urls.each do |url|
      words = extract_words(url)
      validate_extracted_words(words)
    end
  end

  def extract_words(url)
    # Remove scheme and hostname
    path = url.gsub(/^https?:\/\/[^\/]*/, '')
    
    # Extract words
    words = path.scan(/([a-z0-9]+)/).flatten
    
    # Filter words
    words.reject! { |word| word.length <= 2 }
    words.reject! { |word| dictionary_word?(word) }
    
    words
  end

  def dictionary_word?(word)
    # Use aspell to check if word is in dictionary
    stdout, _, status = Open3.capture3("echo #{word} | aspell list")
    status.success? && stdout.strip.empty?
  end

  def validate_extracted_words(words)
    case words
    when ['myplanning', 'xearch']
      true
    when ['fromdate']
      true
    else
      abort("Error: Unexpected word extraction result: #{words}")
    end
  end
end

if __FILE__ == $0
  validator = AnalyzeValidator.new
  validator.validate
end
