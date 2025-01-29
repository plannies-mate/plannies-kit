#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'fileutils'
require 'time'
require 'set'

class ScraperAnalyzer
  SCRAPER_PATTERNS = [
    'scraper.rb',
    'scraper.php',
    'scraper.py',
    'scraper.pl',
    'scraper.js'
  ]

  COMMON_WORDS = Set.new([
                           'scraper', 'scrapers',
                           'http', 'https', 'www', 'com', 'org', 'gov', 'edu',
                           'search', 'query', 'find', 'page', 'data',
                           'format', 'type', 'view', 'index', 'list',
                           'application', 'applications',
                           'development', 'developments',
                           'planning', 'plan', 'plans',
                           'council', 'shire', 'city',
                           'current', 'date', 'status',
                           'true', 'false', 'null', 'undefined'
                         ])

  def initialize(repo_dir)
    @repo_dir = repo_dir
    abort "Directory #{repo_dir} does not exist!" unless Dir.exist?(repo_dir)
    load_descriptions
    @broken_scrapers = []
    @no_scraper_repos = []

    # Initialize aspell
    @speller = IO.popen("aspell -a", "r+")
    @speller.readline # Read first line to clear aspell header
  end

  def analyze
    @results = {
      metadata: {
        generated_at: Time.now.utc.iso8601,
        repos_analyzed: 0,
        trivial_scrapers_skipped: 0,
        broken_scrapers_found: 0,
        no_scraper_file: 0
      },
      repos: {},      # Will hold repo data for all scrapers
      valid_repos: {} # Will hold only the useful scrapers
    }

    all_repos = Dir.glob(File.join(@repo_dir, '*')).sort
    total_repos = all_repos.count { |path| File.directory?(path) && File.basename(path) != '.git' }
    puts "\nAnalyzing #{total_repos} repositories..."

    all_repos.each do |repo_path|
      next unless File.directory?(repo_path)
      next if File.basename(repo_path) == '.git'  # Skip .git directory
      analyze_repo(repo_path)
    end

    output_results(total_repos)
  end

  private

  def load_descriptions
    desc_file = File.join(@repo_dir, 'descriptions.json')
    if File.exist?(desc_file)
      data = JSON.parse(File.read(desc_file))
      @descriptions = {}
      data.each do |name, info|
        @descriptions[name] = info['description']
      end
    else
      puts "Warning: descriptions.json not found in #{@repo_dir}"
      @descriptions = {}
    end
  end

  def find_scraper_file(repo_path)
    SCRAPER_PATTERNS.each do |pattern|
      file_path = File.join(repo_path, pattern)
      return file_path if File.exist?(file_path)
    end
    nil
  end

  def analyze_scraper_content(content)
    # Remove comments based on file type
    if content.match?(/^#!/) # Shebang indicates shell/ruby/python/perl
      lines = content.lines.reject { |line| line.strip.start_with?('#') }
    else # For PHP/JS
      lines = content.lines.reject { |line| line.strip.start_with?('//') }
    end

    lines.reject { |line| line.strip.empty? }.map(&:strip)
  end

  def should_analyze_scraper?(lines)
    lines.length >= 15 # Simplified threshold for all languages
  end

  def is_broken_scraper?(lines)
    return false unless lines.any? { |l| l == 'Bundler.require' }
    (lines - ['Bundler.require']).all? { |l| l.strip =~ /^\s*puts\s/ }
  end

  def count_ruby_files_lines(repo_path)
    total_lines = []
    Dir.glob(File.join(repo_path, '**/*.rb')).each do |file|
      begin
        content = File.read(file)
        total_lines.concat(analyze_scraper_content(content))
      rescue => e
        puts "  Warning: Could not read #{file}: #{e.message}"
      end
    end
    total_lines
  end

  def analyze_repo(repo_path)
    repo_name = File.basename(repo_path)
    puts "\nAnalyzing #{repo_name}..."

    scraper_file = find_scraper_file(repo_path)
    unless scraper_file
      @no_scraper_repos << repo_name
      @results[:metadata][:no_scraper_file] += 1
      @results[:repos][repo_name] = {
        name: repo_name,
        description: @descriptions[repo_name],
        status: 'no_scraper',
        main_line_count: 0,
        total_line_count: count_ruby_files_lines(repo_path).length
      }
      return
    end

    begin
      content = File.read(scraper_file)
      main_lines = analyze_scraper_content(content)
      all_lines = count_ruby_files_lines(repo_path)

      if is_broken_scraper?(main_lines)
        @broken_scrapers << repo_name
        @results[:metadata][:broken_scrapers_found] += 1
        @results[:repos][repo_name] = {
          name: repo_name,
          description: @descriptions[repo_name],
          status: 'broken',
          main_line_count: main_lines.length,
          total_line_count: all_lines.length
        }
        return
      end

      unless should_analyze_scraper?(all_lines)
        @results[:metadata][:trivial_scrapers_skipped] += 1
        @results[:repos][repo_name] = {
          name: repo_name,
          description: @descriptions[repo_name],
          status: 'trivial',
          main_line_count: main_lines.length,
          total_line_count: all_lines.length
        }
        return
      end

      urls = extract_urls(content)
      words = extract_words(content)
      repo_data = {
        name: repo_name,
        description: @descriptions[repo_name],
        status: 'active',
        urls: urls.to_a.sort,
        words: words.to_a.sort,
        main_line_count: main_lines.length,
        total_line_count: all_lines.length
      }

      @results[:repos][repo_name] = repo_data
      @results[:valid_repos][repo_name] = repo_data
      @results[:metadata][:repos_analyzed] += 1
    rescue => e
      puts "  Error analyzing #{repo_name}: #{e.message}"
    end
  end

  def extract_urls(content)
    urls = Set.new
    content.scan(/https?:\/\/[^\s<>"']+/).each do |url|
      begin
        uri = URI.parse(url)
        urls << url if uri.host && !url.start_with?('https://github.com', 'https://morph.io')
      rescue URI::InvalidURIError
        # Skip invalid URLs
      end
    end
    urls
  end

  def process_potential_words(text, word_set)
    text.downcase.scan(/[a-zA-Z][a-zA-Z0-9_-]{3,}/).each do |word|
      # Skip if in common words list
      next if COMMON_WORDS.include?(word.downcase)

      # Check if word is in dictionary
      @speller.puts(word)
      @speller.flush
      result = @speller.readline.chomp

      # Add word if not in dictionary (result starts with '*' or '&')
      word_set << word if result.start_with?('*', '&')
    end
  end

  def extract_words(content)
    words = Set.new
    content.scan(/https?:\/\/[^\s<>"']+/).each do |url|
      begin
        uri = URI.parse(url)
        next unless uri.host
        next if url.start_with?('https://github.com', 'https://morph.io')

        # Split path into components
        if uri.path
          uri.path.split('/').each do |part|
            # Extract words from path parts (skip empty parts)
            next if part.empty?
            process_potential_words(part, words)
          end
        end

        # Process query parameters if they exist
        if uri.query
          uri.query.split('&').each do |param|
            name, value = param.split('=', 2)
            # Add parameter names and values
            process_potential_words(name, words)
            process_potential_words(value, words) if value
          end
        end
      rescue URI::InvalidURIError
        # Skip invalid URLs
      end
    end
    words
  end

  def output_results(total_repos)
    FileUtils.mkdir_p('tmp')

    # Output lists of different scraper types
    if @broken_scrapers.any?
      File.write('tmp/broken_scrapers.txt', @broken_scrapers.sort.join("\n"))
      puts "\nExcluded #{@broken_scrapers.size} broken scrapers (see tmp/broken_scrapers.txt)"
    end

    if @results[:repos].any? { |_, r| r[:status] == 'trivial' }
      trivial = @results[:repos].select { |_, r| r[:status] == 'trivial' }.keys.sort
      File.write('tmp/trivial_scrapers.txt', trivial.join("\n"))
      puts "Excluded #{trivial.size} trivial scrapers (see tmp/trivial_scrapers.txt)"
    end

    if @no_scraper_repos.any?
      File.write('tmp/no_scraper.txt', @no_scraper_repos.sort.join("\n"))
      puts "Excluded #{@no_scraper_repos.size} repos without scraper files (see tmp/no_scraper.txt)"
    end

    # Production JS file - only valid scrapers
    js_content = <<~JS
      // Generated by Plannies Mate at #{@results[:metadata][:generated_at]}
      // Including #{@results[:valid_repos].size} active scrapers
      // Excluded #{@results[:metadata][:trivial_scrapers_skipped]} trivial scrapers
      // Excluded #{@results[:metadata][:broken_scrapers_found]} broken scrapers
      // Excluded #{@results[:metadata][:no_scraper_file]} repos without scraper files

      export const scraperData = {
      #{@results[:valid_repos].map { |name, data|
      "  '#{name}': {\n" \
        "    description: #{data[:description].to_json},\n" \
        "    words: #{data[:words].inspect}\n" \
        "  }"
    }.join(",\n")}
      };
    JS

    File.write('tmp/scraper_analysis.js', js_content)
    File.write('tmp/debug_analysis.json', JSON.pretty_generate(@results))

    puts "\n# Analysis Results"
    puts "Generated tmp/scraper_analysis.js with active scraper data"
    puts "Generated tmp/debug_analysis.json with full analysis"
    puts "Total repositories: #{total_repos}"
    puts "Including #{@results[:valid_repos].size} active scrapers"
    puts "Excluded #{@results[:metadata][:trivial_scrapers_skipped]} trivial scrapers (see tmp/trivial_scrapers.txt)"
    puts "Excluded #{@results[:metadata][:broken_scrapers_found]} broken scrapers (see tmp/broken_scrapers.txt)"
    puts "Excluded #{@results[:metadata][:no_scraper_file]} repos without scraper files (see tmp/no_scraper.txt)"
    puts "Generated at: #{@results[:metadata][:generated_at]}"

    # Validation
    total_classified = @results[:valid_repos].size +
      @results[:metadata][:trivial_scrapers_skipped] +
      @results[:metadata][:broken_scrapers_found] +
      @results[:metadata][:no_scraper_file]

    if total_classified != total_repos
      puts "\nWARNING: Classification mismatch!"
      puts "Total repos: #{total_repos}"
      puts "Total classified: #{total_classified}"
      puts "Difference: #{total_repos - total_classified}"
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    abort "Usage: #{$0} REPO_DIR"
  end

  analyzer = ScraperAnalyzer.new(ARGV[0])
  analyzer.analyze
end
