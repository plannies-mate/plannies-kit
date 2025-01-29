#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'open3'
require 'fileutils'

class ScraperAnalyzer
  SPELL_CMD = 'aspell list'  # Assumes aspell is installed

  def initialize(repo_dir)
    @repo_dir = repo_dir
    abort "Directory #{repo_dir} does not exist!" unless Dir.exist?(repo_dir)
  end

  def analyze
    @results = {}

    Dir.glob(File.join(@repo_dir, '*')).sort.each do |repo_path|
      next unless File.directory?(repo_path)
      analyze_repo(repo_path)
    end

    output_results
  end

  private

  def analyze_repo(repo_path)
    repo_name = File.basename(repo_path)
    puts "\nAnalyzing #{repo_name}..."

    terms = Set.new

    Dir.chdir(repo_path) do
      # Look for code files
      code_files = Dir.glob("**/*.{rb,py,js,pl,php}")

      code_files.each do |file|
        content = File.read(file)
        terms.merge(extract_terms(content))
      end
    end

    @results[repo_name] = terms.to_a.sort if terms.any?
  end

  def extract_terms(content)
    # Extract potential terms (adjust regex as needed)
    terms = content.scan(/[A-Za-z][A-Za-z0-9_]+/)
                   .select { |t| t.length > 2 }  # Skip short terms
                   .map(&:downcase)
                   .uniq

    # Filter out dictionary words using aspell
    filter_dictionary_words(terms)
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
    puts "\n# Analysis Results"
    puts "# Copy and paste the following into your extraMatchWords hash:\n\n"

    puts "const extraMatchWords = {"
    @results.each do |repo, terms|
      next if terms.empty?
      puts "    '#{repo}': #{terms.inspect},"
    end
    puts "};"
  end
end

if __FILE__ == $0
  if ARGV.empty?
    abort "Usage: #{$0} REPO_DIR"
  end

  analyzer = ScraperAnalyzer.new(ARGV[0])
  analyzer.analyze
end
