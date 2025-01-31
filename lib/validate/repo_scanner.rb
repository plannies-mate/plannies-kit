#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require_relative '../process_base'
require_relative '../repo_scanner'

class RepoScannerValidator < ProcessBase
  def validate
    validate_scraper_detection
    validate_line_classification
    validate_placeholder_detection
    validate_trivial_detection
    test_repo_classifications
    puts "Repo Scanner validation passed successfully!"
  end

  private

  def test_repo_classifications
    # Test no_scraper repos
    no_scraper_repos = %w[issues planningalerts_xml_feed test-issues]
    no_scraper_repos.each do |repo_name|
      repo_path = File.join(REPOS_DIR, repo_name)
      next unless File.directory?(repo_path)
      
      scanner = RepoScanner.new(repo_path)
      refute scanner.has_scraper?, "#{repo_name} should not have a scraper"
      refute scanner.active_scraper?, "#{repo_name} should not be an active scraper"
      refute scanner.placeholder_scraper?, "#{repo_name} should not be a placeholder scraper"
      refute scanner.trivial_scraper?, "#{repo_name} should not be a trivial scraper"
    end

    # Test placeholder repos
    placeholder_repos = ['cootamundra', 'yass']
    placeholder_repos.each do |repo_name|
      repo_path = File.join(REPOS_DIR, repo_name)
      next unless File.directory?(repo_path)
      
      scanner = RepoScanner.new(repo_path)
      assert scanner.has_scraper?, "#{repo_name} should have a scraper"
      assert scanner.placeholder_scraper?, "#{repo_name} should be a placeholder scraper"
      refute scanner.active_scraper?, "#{repo_name} should not be an active scraper"
      refute scanner.trivial_scraper?, "#{repo_name} should not be a trivial scraper"
    end

    # Test trivial repos
    trivial_repos = ['KingboroughCouncil', 'bankstown', 'launceston', 'townsville']
    trivial_repos.each do |repo_name|
      repo_path = File.join(REPOS_DIR, repo_name)
      next unless File.directory?(repo_path)
      
      scanner = RepoScanner.new(repo_path)
      assert scanner.has_scraper?, "#{repo_name} should have a scraper"
      assert scanner.trivial_scraper?, "#{repo_name} should be a trivial scraper"
      refute scanner.active_scraper?, "#{repo_name} should not be an active scraper"
      refute scanner.placeholder_scraper?, "#{repo_name} should not be a placeholder scraper"
    end
  end

  def validate_scraper_detection
    # Test various scenarios of scraper detection
    test_repos = [
      'repos/bawbaw',        # Should have a scraper
      'repos/townsville',    # Should have a scraper
      'repos/no_scraper_repo' # Should not have a scraper
    ]

    test_repos.each do |repo_path|
      next unless File.directory?(repo_path)
      
      scanner = RepoScanner.new(repo_path)
      
      # Validate has_scraper? method
      if File.basename(repo_path) == 'no_scraper_repo'
        refute scanner.has_scraper?, "Repo #{repo_path} should not have a scraper"
      else
        assert scanner.has_scraper?, "Repo #{repo_path} should have a scraper"
      end
    end
  end

  def validate_line_classification
    test_repos = [
      'repos/bawbaw',        # Active scraper
      'repos/townsville',    # Active scraper
      'repos/placeholder_repo', # Placeholder scraper
      'repos/trivial_repo'   # Trivial scraper
    ]

    test_repos.each do |repo_path|
      next unless File.directory?(repo_path)
      
      scanner = RepoScanner.new(repo_path)
      
      # Validate active_lines method
      active_lines = scanner.active_lines
      assert active_lines.is_a?(Array), "Active lines should be an array for #{repo_path}"
      
      # Validate line filtering
      active_lines.each do |line|
        refute line.strip.empty?, "Active lines should not be empty for #{repo_path}"
        refute line.start_with?('#'), "Active lines should not start with comments for #{repo_path}"
      end
    end
  end

  def validate_placeholder_detection
    placeholder_repos = [
      'repos/placeholder_repo'
    ]

    placeholder_repos.each do |repo_path|
      next unless File.directory?(repo_path)
      
      scanner = RepoScanner.new(repo_path)
      active_lines = scanner.active_lines(only_scraper: true)
      
      # Validate placeholder detection logic
      assert is_placeholder_scraper?(active_lines), 
        "Repo #{repo_path} should be detected as a placeholder scraper"
    end
  end

  def validate_trivial_detection
    trivial_repos = [
      'repos/trivial_repo'
    ]

    trivial_repos.each do |repo_path|
      next unless File.directory?(repo_path)
      
      scanner = RepoScanner.new(repo_path)
      all_lines = scanner.active_lines
      
      # Validate trivial detection logic
      refute should_analyze_scraper?(all_lines), 
        "Repo #{repo_path} should be detected as a trivial scraper"
    end
  end

  # Helper methods to match ScraperAnalyzer logic
  def is_placeholder_scraper?(lines)
    return false unless lines.any? { |l| l.include?('Bundler.require') }
    (lines - lines.select { |l| l.include?('Bundler.require') }).all? { |l| l.strip =~ /^\s*puts\s/ }
  end

  def should_analyze_scraper?(lines)
    lines.length >= 15 # Simplified threshold for all languages
  end

  # Assertion methods
  def assert(condition, message = nil)
    raise StandardError, message unless condition
  end

  def refute(condition, message = nil)
    raise StandardError, message if condition
  end
end

if __FILE__ == $0
  validator = RepoScannerValidator.new
  validator.validate
end
