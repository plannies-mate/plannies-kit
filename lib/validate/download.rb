#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require_relative '../process_base'

class DownloadValidator < ProcessBase
  def initialize(limit = nil)
    @limit = limit ? limit.to_i : nil
    abort "LIMIT must be a positive number" if @limit && @limit < 1
    super()
  end

  def validate
    validate_repos_json
    validate_repo_count
    validate_repo_directories
  end

  private

  def validate_repos_json
    puts "Validating repos.json..."
    
    unless File.exist?(REPOS_FILE)
      abort "#{REPOS_FILE} does not exist!"
    end

    begin
      data = JSON.parse(File.read(REPOS_FILE))
      unless data.is_a?(Hash) && data.any?
        abort "#{REPOS_FILE} does not contain valid repository data!"
      end

      data.each do |name, info|
        unless info.is_a?(Hash) && 
               info['description'].is_a?(String) && 
               info['last_updated'].is_a?(String)
          abort "Invalid data format for repository #{name}"
        end
      end
    rescue JSON::ParserError => e
      abort "Failed to parse #{REPOS_FILE}: #{e.message}"
    end
  end

  def validate_repo_count
    puts "Validating repository count..."
    
    # Count directories in repos/ excluding .git
    repo_count = Dir.glob(File.join(REPOS_DIR, '*'))
                   .count { |f| File.directory?(f) && File.basename(f) != '.git' }

    if @limit
      unless repo_count == @limit
        abort "Expected #{@limit} repositories, but found #{repo_count}"
      end
    else
      # Default requirement is at least 40 repos
      unless repo_count >= 40
        abort "Found only #{repo_count} repositories, expected at least 40"
      end
    end
  end

  def validate_repo_directories
    puts "Validating repository directories..."
    
    data = JSON.parse(File.read(REPOS_FILE))
    
    data.each do |name, _info|
      repo_dir = File.join(REPOS_DIR, name)
      unless File.directory?(repo_dir)
        abort "Repository directory missing: #{repo_dir}"
      end

      # Each repo should have at least one file
      files = Dir.glob(File.join(repo_dir, '*'))
      if files.empty?
        abort "Repository #{name} appears empty"
      end

      # Check repo name format (no periods or slashes)
      if name.include?('.') || name.include?('/') || name.include?('\\')
        abort "Invalid repository name format: #{name}"
      end
    end

    puts "All validations passed!"
  end
end

if __FILE__ == $0
  validator = DownloadValidator.new(ARGV[0])
  validator.validate
end
