#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'json'
require_relative '../process_base'

class CleanupValidator < ProcessBase
  def validate
    validate_no_test_dirs
    validate_no_binary_files
    validate_no_git_dirs
    validate_scraper_files
    puts "Cleanup validation passed successfully!"
  end

  private

  def validate_no_test_dirs
    test_dirs = Dir.glob(File.join(REPOS_DIR, '**', '{test,tests,spec,specs}'))
    abort("Error: Test directories still exist: #{test_dirs}") if test_dirs.any?
  end

  def validate_no_binary_files
    binary_files = find_binary_files
    abort("Error: Binary files still exist: #{binary_files}") if binary_files.any?
  end

  def validate_no_git_dirs
    git_dirs = Dir.glob(File.join(REPOS_DIR, '**', '.git'))
    abort("Error: .git directories still exist: #{git_dirs}") if git_dirs.any?
  end

  def validate_scraper_files
    repos_without_scraper = find_repos_without_scraper
    abort("Error: More than 5 repos are missing scraper files: #{repos_without_scraper}") if repos_without_scraper.size > 5
  end

  def find_binary_files
    binary_extensions = %w[
      .pdf .png .jpg .jpeg .gif .ico .svg .woff .woff2 .ttf .eot
      .zip .gz .tar .7z .rar
      .exe .dll .so .dylib
      .db .sqlite .sqlite3
      .doc .docx .xls .xlsx .ppt .pptx
    ]

    Dir.glob(File.join(REPOS_DIR, '**', '*')).select do |file_path|
      next false unless File.file?(file_path)
      
      # Check file extension
      return true if binary_extensions.include?(File.extname(file_path).downcase)

      # Check file content for binary characteristics
      begin
        bytes = File.read(file_path, 512)
        bytes.count("\x00") > 0 ||
          bytes.count("\x00-\x07\x0B\x0E-\x1F").to_f / bytes.length > 0.3
      rescue
        false
      end
    end
  end

  def find_repos_without_scraper
    scraper_patterns = [
      'scraper.rb',
      'scraper.php',
      'scraper.py',
      'scraper.pl',
      'scraper.js'
    ]

    Dir.glob(File.join(REPOS_DIR, '*')).select do |repo_path|
      next false unless File.directory?(repo_path)
      
      # Check if any scraper file exists
      !scraper_patterns.any? { |pattern| Dir.glob(File.join(repo_path, pattern)).any? }
    end
  end
end

if __FILE__ == $0
  validator = CleanupValidator.new
  validator.validate
end
