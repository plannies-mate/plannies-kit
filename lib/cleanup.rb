#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'fileutils'

require_relative 'process_base'

class ReposCleaner < ProcessBase
  DIRS_TO_REMOVE = %w[
    test tests spec specs
    doc docs fixtures expected
    .vscode .idea
  ]

  FILES_TO_REMOVE = %w[
    Gemfile
    Gemfile.lock
    composer.json
    composer.lock
    hundrednames.txt
    package.json
    package-lock.json
    repos/descriptions.json
    req
    scraper.js.map
    streetnames.txt
    streetsuffixes.txt
    suburbnames.txt
    tsconfig.json
    words.txt
    README.md
  ]


  # Common binary file extensions
  BINARY_EXTENSIONS = %w[
    .pdf .png .jpg .jpeg .gif .ico .svg .woff .woff2 .ttf .eot
    .zip .gz .tar .7z .rar
    .exe .dll .so .dylib
    .db .sqlite .sqlite3
    .doc .docx .xls .xlsx .ppt .pptx
  ]

  def initialize
  end

  def cleanup
    puts "Cleaning #{REPOS_DIR}..."

    Dir.glob(File.join(REPOS_DIR, '*')).each do |repo_path|
      next unless File.directory?(repo_path)
      clean_repo(repo_path)
    end
  end

  private

  def clean_repo(repo_path)
    repo_name = File.basename(repo_path)
    puts "\nCleaning #{repo_name}..."

    # Remove .git directory
    FileUtils.rm_rf(File.join(repo_path, '.git'))

    # Remove specified directories
    DIRS_TO_REMOVE.each do |dir|
      dir_path = File.join(repo_path, dir)
      if File.directory?(dir_path)
        FileUtils.rm_rf(dir_path)
        puts "  Removed directory: #{dir}"
      end
    end

    # Remove specified files
    FILES_TO_REMOVE.each do |file|
      file_path = File.join(repo_path, file)
      if File.file?(file_path)
        FileUtils.rm_f(file_path)
        puts "  Removed file: #{file}"
      end
    end

    # Remove test files and binary files
    Dir.glob(File.join(repo_path, '**', '*')).each do |file_path|
      next unless File.file?(file_path)

      basename = File.basename(file_path)
      rel_path = file_path.sub("#{repo_path}/", '')

      if should_remove_file?(basename, file_path)
        FileUtils.rm_f(file_path)
        puts "  Removed file: #{rel_path}"
      end
    end
  end

  def should_remove_file?(basename, file_path)
    # Check for test files
    return true if basename.start_with?('test') ||
      basename =~ /test\.[^.]+$/ ||
      basename =~ /\.test\.[^.]+$/

    # Check for binary files by extension
    extension = File.extname(basename).downcase
    return true if BINARY_EXTENSIONS.include?(extension)

    # Check file content for binary data
    is_binary?(file_path)
  end

  def is_binary?(file_path)
    # Read first 512 bytes
    begin
      bytes = File.read(file_path, 512)
      return false unless bytes
    rescue
      return false
    end

    # Check for null bytes or high proportion of non-ASCII chars
    bytes.count("\x00") > 0 ||
      bytes.count("\x00-\x07\x0B\x0E-\x1F").to_f / bytes.length > 0.3
  end
end

if __FILE__ == $0
  cleaner = ReposCleaner.new
  cleaner.cleanup
end
