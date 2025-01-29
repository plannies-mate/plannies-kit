#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'open3'
require 'fileutils'
require 'time'

class ScraperAnalyzer
  SPELL_CMD = 'aspell list'  # Assumes aspell is installed

  def initialize(repo_dir)
    @repo_dir = repo_dir
    abort "Directory #{repo_dir} does not exist!" unless Dir.exist?(repo_dir)
    load_descriptions
  end

  def analyze
    @results = {
      metadata: {
        generated_at: Time.now.utc.iso8601,
        repos_analyzed: 0
      },
      repos: {}  # Will hold repo data
    }

    Dir.glob(File.join(@repo_dir, '*')).sort.each do |repo_path|
      next unless File.directory?(repo_path)
      next if File.basename(repo_path) == '.git'  # Skip .git directory
      analyze_repo(repo_path)
      @results[:metadata][:repos_analyzed] += 1
    end

    output_results
  end

  private

  def load_descriptions
    desc_file = File.join(@repo_dir, 'descriptions.json')
    if File.exist?(desc_file)
      @descriptions = JSON.parse(File.read(desc_file))
    else
      puts "Warning: descriptions.json not found in #{@repo_dir}"
      @descriptions = {}
    end
  end

  def analyze_repo(repo_path)
    repo_name = File.basename(repo_path)
    puts "\nAnalyzing #{repo_name}..."

    # Data for both debug and production
    words = Set.new
    urls = Set.new

    Dir.chdir(repo_path) do
      code_files = Dir.glob("**/*.{rb,py,js,pl,php}")

      code_files.each do |file|
        content = File.read(file)
        extract_content(content, words, urls)
      end
    end

    # Store full data for debugging
    @results[:repos][repo_name] = {
      name: repo_name,
      description: @descriptions[repo_name],
      urls: urls.to_a.sort,
      words: words.to_a.sort
    }
  end

  def extract_content(content, words, urls)
    # Extract URLs for debug info
    content.scan(/https?:\/\/[^\s<>"']+/).each do |url|
      begin
        uri = URI.parse(url)
        urls << url if uri.host
      rescue URI::InvalidURIError
        # Skip invalid URLs
      end
    end

    # Extract potential terms
    terms = content.scan(/[A-Za-z][A-Za-z0-9_]+/)
                   .select { |t| t.length > 2 }  # Skip short terms
                   .map(&:downcase)
                   .uniq

    # Filter out dictionary words
    non_dict_terms = filter_dictionary_words(terms)
    words.merge(non_dict_terms)
  end

  def filter_dictionary_words(terms)
    return [] if terms.empty?

    # Write terms to temp file
    temp_file = 'temp_words.txt'
    File.write(temp_file, terms.join("\n"))

    # Run aspell to get non-dictionary words
    output, _ = Open3.capture2("#{SPELL_CMD} < #{temp_file}")

    # Clean up
    FileUtils.rm_f(temp_file)

    output.split("\n")
  end

  def output_results
    # Production JS file - minimal data needed for frontend
    js_content = <<~JS
      // Generated by Plannies Mate at #{@results[:metadata][:generated_at]}
      // Analyzed #{@results[:metadata][:repos_analyzed]} repositories

      export const scraperData = {
      #{@results[:repos].map { |name, data|
      "  '#{name}': {\n" \
        "    description: #{data[:description].to_json},\n" \
        "    words: #{data[:words].inspect}\n" \
        "  }"
    }.join(",\n")}
      };
    JS

    File.write('scraper_analysis.js', js_content)

    # Debug JSON file - full analysis including URLs
    File.write('debug_analysis.json', JSON.pretty_generate(@results))

    puts "\n# Analysis Results"
    puts "Generated scraper_analysis.js with search terms and descriptions"
    puts "Generated debug_analysis.json with full analysis including URLs"
    puts "Analyzed #{@results[:metadata][:repos_analyzed]} repositories"
    puts "Generated at: #{@results[:metadata][:generated_at]}"
  end
end

if __FILE__ == $0
  if ARGV.empty?
    abort "Usage: #{$0} REPO_DIR"
  end

  analyzer = ScraperAnalyzer.new(ARGV[0])
  analyzer.analyze
end
