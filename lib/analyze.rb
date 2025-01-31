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
    @results = {}
  end

  def analyze
    @results = {
      generated_at: Time.now.utc.iso8601,
      stats: {
        active: 0
      },
      ignored_repos: {},
      active_repos: {}
    }
    RepoScanner::IGNORE_REASONS.each do |reason|
      @results[:stats][reason.to_sym] = 0
    end

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

  def repos
    @repos ||= YAML.load_file REPOS_FILE
  end

  def descriptions
    @descriptions ||= repos.transform_values { |info| info['description'] }
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


  def handle_ignored_repo(repo_name, reason)
    @results[:stats][reason.to_sym] += 1
    @results[:ignored_repos][repo_name] = {
      name: repo_name,
      description: descriptions[repo_name],
      status: reason
    }
  end

  def process_active_scraper(repo_name, content)
    urls = extract_urls(content)
    words = extract_words(content)
    repo_data = {
      name: repo_name,
      description: descriptions[repo_name],
      status: 'active',
      urls: urls.sort,
      words: words.sort
    }

    @results[:valid_repos][repo_name] = repo_data
    @results[:stats][:active] += 1
  end

  def output_results(total_repos)
    output_generator = ScraperAnalysisOutputGenerator.new(@results, total_repos)
    output_generator.generate_output_files
  end
end

if __FILE__ == $0
  analyzer = ScraperAnalyzer.new
  analyzer.analyze
end
