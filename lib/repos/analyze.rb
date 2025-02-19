#!/usr/bin/env ruby

require 'fileutils'
require 'set'
require 'time'
require 'uri'

require_relative '../utils/dictionary_checker'
require_relative 'html_filter'
require_relative 'process_base'
require_relative 'repo_scanner'
require_relative 'scraper_analysis_output_generator'

class ScraperAnalyzer < ProcessBase
  attr_reader :dictionary

  def initialize
    abort "Directory #{REPOS_DIR} does not exist!" unless Dir.exist?(REPOS_DIR)
    @results = {}
    @dictionary = DictionaryChecker.new
  end

  def analyze
    @results = initial_results
    puts "\nAnalyzing #{repos.count} repositories..."

    repos.each do |repo_name, data|
      # add known words from repo name and description to ignoredWords list
      "#{repo_name} #{data['description']}"
        .scan(/[a-z]+/i)
        .each { |word| @dictionary.known?(word.downcase) }

      analyze_repo(repo_name, @results, @dictionary)
    end

    # Find words common to all active repos
    common_words = find_common_words(@results[:active_repos])

    # Remove common words from each repo's words
    @results[:active_repos].each do |repo_name, repo_data|
      repo_data[:words_from_strings] -= common_words
      repo_data[:words_from_urls] -= common_words
    end

    # Add common words to known words
    @results[:known_words] = (@dictionary.known_words.to_a + common_words).sort
    
    # Remove common words from unknown words
    @results[:unknown_words] = (@dictionary.unknown_words.to_a - common_words).sort

    puts "\nSaving internal results to #{ANALYSIS_RESULTS_FILE} ..."

    FileUtils.mkdir_p(LOG_DIR)
    File.write(ANALYSIS_RESULTS_FILE, YAML.dump(@results))

    puts "\nGenerating output to #{SCRAPER_ANALYSIS_FILE} ..."

    output_generator = ScraperAnalysisOutputGenerator.new(@results)
    output_generator.generate_output_files
  end

  def find_common_words(active_repos)
    # Get words from all active repos
    words_from_strings = active_repos.values.map { |repo| repo[:words_from_strings] }
    words_from_urls = active_repos.values.map { |repo| repo[:words_from_urls] }
    
    # Find words that appear in ALL repos
    (words_from_strings + words_from_urls).reduce(&:&)
  end

  def initial_results
    results = {
      generated_at: Time.now.utc.iso8601,
      stats: {
        active: 0
      },
      ignored_repos: {},
      active_repos: {}
    }
    RepoScanner::IGNORE_REASONS.each do |reason|
      results[:stats][reason.to_sym] = 0
    end
    results
  end

  # analyse_repo
  def analyze_repo(repo_name, results, dictionary)
    puts "\nAnalyzing #{repo_name}..."

    scanner = RepoScanner.new(repo_name)
    if scanner.ignore?
      record_ignored_repo(results, repo_name, scanner.ignore_reason)
      return
    end

    begin
      lines = scanner.active_lines
      urls = extract_url_paths(lines)
      selectors = extract_selectors(lines)
      significant_strings = urls + selectors
      words = extract_words(significant_strings, dictionary)
      record_active_scraper(results, repo_name, urls, words)
    rescue => e
      puts "  Error analyzing #{repo_name}: #{e.message}"
    end
  end

  def extract_selectors(lines)
    lines
      .flat_map do |line|
      extract_single_quoted_strings(line) +
        extract_double_quoted_strings(line)
    end
      .reject do |str|
      str.match?(/^https?:\/\//) || # Reject URLs
        str.empty? || # Reject empty strings
        HTMLFilter.html_token?(str) # Reject HTML elements and attributes
    end
      .uniq
  end

  def extract_single_quoted_strings(line)
    line.scan(/'([^']+)'/).map(&:first)
  end

  def extract_double_quoted_strings(line)
    line.scan(/"([^"]+)"/).map(&:first)
  end

  def extract_url_paths(lines)
    lines
      .join("\n")
      .scan(%r{https?://[^\s<>"']+})
      .reject { |url| url.downcase.start_with?('https://github.com', 'https://morph.io') }
      .map { |url| url.sub(/^https?:\/\/[^\/]+/, '').sub(/=\d+$/, '=') }
      .uniq
  end

  # extract_words returns significant words found in urls
  # tests words against dictionary before downcase as aspell is case-sensitive
  def extract_words(strings, dictionary)
    strings
      .map { |string| extract_words_from_string(string) }
      .flatten
      .reject { |word| word.length <= 2 || dictionary.known?(word) }
      .map(&:downcase)
      .uniq
  end

  def extract_words_from_string(string)
    string.scan(/[-_%a-z0-9]+/i)
  end

  private

  def repos
    @repos ||= YAML.load_file REPOS_FILE
  end

  def descriptions
    @descriptions ||= repos.transform_values { |info| info['description'] }
  end

  def record_ignored_repo(results, repo_name, reason)
    results[:stats][reason.to_sym] += 1
    results[:ignored_repos][repo_name] = {
      name: repo_name,
      description: descriptions[repo_name],
      status: reason
    }
  end

  def record_active_scraper(results, repo_name, urls, words)
    # Separate words from URLs and strings
    words_from_urls = extract_words(urls, @dictionary)
    words_from_strings = words - words_from_urls

    repo_data = {
      name: repo_name,
      description: descriptions[repo_name],
      status: 'active',
      urls: urls.sort,
      words_from_strings: words_from_strings.sort,
      words_from_urls: words_from_urls.sort
    }

    results[:active_repos][repo_name] = repo_data
    results[:stats][:active] += 1
  end
end

if __FILE__ == $0
  $stdout.sync = true
  $stderr.sync = true

  analyzer = ScraperAnalyzer.new
  analyzer.analyze
end
