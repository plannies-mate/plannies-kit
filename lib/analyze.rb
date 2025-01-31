#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'uri'
require 'fileutils'
require 'time'
require 'set'

require_relative 'process_base'
require_relative 'repo_scanner'
require_relative 'scraper_analysis_output_generator'

class ScraperAnalyzer < ProcessBase
  COMMON_WORDS = Set.new(%w[
    application applications city com council current data date development
    developments edu false find format gov http https index
    list null org page plan planning plans query scraper
    scrapers search shire status true type undefined view www
  ]).freeze

  def initialize
    abort "Directory #{REPOS_DIR} does not exist!" unless Dir.exist?(REPOS_DIR)
    load_descriptions
    @placeholder_scrapers = []
    @no_scraper_repos = []
  end

  def analyze
    @results = {
      metadata: {
        generated_at: Time.now.utc.iso8601,
        repos_analyzed: 0,
        trivial_scrapers_skipped: 0,
        placeholder_scrapers_found: 0,
        no_scraper_file: 0
      },
      repos: {},
      valid_repos: {}
    }

    all_repos = Dir.glob(File.join(REPOS_DIR, '*')).sort
    total_repos = all_repos.count { |path| File.directory?(path) && File.basename(path) != '.git' }
    puts "\nAnalyzing #{total_repos} repositories..."

    all_repos.each do |repo_path|
      next unless File.directory?(repo_path)
      next if File.basename(repo_path) == '.git'
      analyze_repo(repo_path)
    end

    output_results(total_repos)
  end

  def extract_urls(content)
    content.scan(/https?:\/\/[^\s<>"']+/)
      .reject { |url| url.start_with?('https://github.com', 'https://morph.io') }
      .uniq
  end

  def extract_words(content)
    extract_urls(content)
      .flat_map { |url| extract_words_from_url(url) }
      .reject { |word| word.length <= 2 }
      .reject { |word| COMMON_WORDS.include?(word) }
      .uniq
  end

  def extract_words_from_url(url)
    # Remove scheme and hostname
    path_and_query = url.sub(/^https?:\/\/[^\/]+/, '')
    
    # Extract words (sequences of alphanumeric characters)
    path_and_query.scan(/[a-z0-9]+/)
  end

  private

  def load_descriptions
    if File.exist?(REPOS_FILE)
      data = JSON.parse(File.read(REPOS_FILE))
      @descriptions = data.transform_values { |info| info['description'] }
    else
      puts "Warning: #{REPOS_FILE} not found!"
      @descriptions = {}
    end
  end

  def analyze_repo(repo_path)
    repo_name = File.basename(repo_path)
    puts "\nAnalyzing #{repo_name}..."

    scanner = RepoScanner.new(repo_path)
    unless scanner.has_scraper?
      handle_no_scraper_repo(repo_name, repo_path)
      return
    end

    begin
      main_lines = scanner.active_lines(only_scraper: true)
      all_lines = scanner.active_lines

      if is_placeholder_scraper?(main_lines)
        handle_placeholder_scraper(repo_name, main_lines, all_lines)
        return
      end

      unless should_analyze_scraper?(all_lines)
        handle_trivial_scraper(repo_name, main_lines, all_lines)
        return
      end

      process_active_scraper(repo_name, File.read(scanner.instance_variable_get(:@scraper_file)), main_lines, all_lines)
    rescue => e
      puts "  Error analyzing #{repo_name}: #{e.message}"
    end
  end

  def analyze_repo(repo_path)
    repo_name = File.basename(repo_path)
    puts "\nAnalyzing #{repo_name}..."

    scraper_file = find_scraper_file(repo_path)
    unless scraper_file
      handle_no_scraper_repo(repo_name, repo_path)
      return
    end

    begin
      content = File.read(scraper_file)
      main_lines = analyze_scraper_content(content)
      all_lines = count_ruby_files_lines(repo_path)

      if is_placeholder_scraper?(main_lines)
        handle_placeholder_scraper(repo_name, main_lines, all_lines)
        return
      end

      unless should_analyze_scraper?(all_lines)
        handle_trivial_scraper(repo_name, main_lines, all_lines)
        return
      end

      process_active_scraper(repo_name, content, main_lines, all_lines)
    rescue => e
      puts "  Error analyzing #{repo_name}: #{e.message}"
    end
  end

  def handle_no_scraper_repo(repo_name, repo_path)
    @no_scraper_repos << repo_name
    @results[:metadata][:no_scraper_file] += 1
    @results[:repos][repo_name] = {
      name: repo_name,
      description: @descriptions[repo_name],
      status: 'no_scraper',
      main_line_count: 0,
      total_line_count: count_ruby_files_lines(repo_path).length
    }
  end

  def is_placeholder_scraper?(lines)
    return false unless lines.any? { |l| l.include?('Bundler.require') }
    (lines - lines.select { |l| l.include?('Bundler.require') }).all? { |l| l.strip =~ /^\s*puts\s/ }
  end

  def handle_placeholder_scraper(repo_name, main_lines, all_lines)
    @placeholder_scrapers << repo_name
    @results[:metadata][:placeholder_scrapers_found] += 1
    @results[:repos][repo_name] = {
      name: repo_name,
      description: @descriptions[repo_name],
      status: 'placeholder',
      main_line_count: main_lines.length,
      total_line_count: all_lines.length
    }
  end

  def should_analyze_scraper?(lines)
    lines.length >= 15 # Simplified threshold for all languages
  end

  def handle_trivial_scraper(repo_name, main_lines, all_lines)
    @results[:metadata][:trivial_scrapers_skipped] += 1
    @results[:repos][repo_name] = {
      name: repo_name,
      description: @descriptions[repo_name],
      status: 'trivial',
      main_line_count: main_lines.length,
      total_line_count: all_lines.length
    }
  end

  def process_active_scraper(repo_name, content, main_lines, all_lines)
    urls = extract_urls(content)
    words = extract_words(content)
    repo_data = {
      name: repo_name,
      description: @descriptions[repo_name],
      status: 'active',
      urls: urls.sort,
      words: words.sort,
      main_line_count: main_lines.length,
      total_line_count: all_lines.length
    }

    @results[:repos][repo_name] = repo_data
    @results[:valid_repos][repo_name] = repo_data
    @results[:metadata][:repos_analyzed] += 1
  end

  def output_results(total_repos)
    require_relative 'scraper_analysis_output_generator'
    output_generator = ScraperAnalysisOutputGenerator.new(@results, total_repos)
    output_generator.generate_output_files
  end
end

if __FILE__ == $0
  analyzer = ScraperAnalyzer.new
  analyzer.analyze
end
