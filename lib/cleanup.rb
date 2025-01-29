#!/usr/bin/env ruby

require 'fileutils'

class ReposCleaner
  DIRS_TO_REMOVE = %w[
    test tests spec specs
    doc docs fixtures expected
  ]

  FILES_TO_REMOVE = %w[
    Gemfile
    Gemfile.lock
  ]

  def initialize(repo_dir)
    @repo_dir = repo_dir
    abort "Directory #{repo_dir} does not exist!" unless Dir.exist?(repo_dir)
  end

  def cleanup
    puts "Cleaning #{@repo_dir}..."

    Dir.glob(File.join(@repo_dir, '*')).each do |repo_path|
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

    # Remove test files
    Dir.glob(File.join(repo_path, '**', '*')).each do |file_path|
      next unless File.file?(file_path)

      basename = File.basename(file_path)
      if basename.start_with?('test') ||
        basename =~ /test\.[^.]+$/ ||
        basename =~ /\.test\.[^.]+$/
        FileUtils.rm_f(file_path)
        puts "  Removed test file: #{file_path.sub("#{repo_path}/", '')}"
      end
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    abort "Usage: #{$0} REPO_DIR"
  end

  cleaner = ReposCleaner.new(ARGV[0])
  cleaner.cleanup
end
