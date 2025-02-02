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
    validate_repos_yml
    validate_repo_count
    validate_repo_directories
    validate_multiple_repos_exist
    validate_repos_yml_age

    puts "All validations passed!"
  end

  def validate_repos_yml_age
    puts "Validating repos.yml age..."
    
    repos_file_path = REPOS_FILE
    unless File.exist?(repos_file_path)
      abort "#{repos_file_path} does not exist!"
    end

    file_age = Time.now - File.mtime(repos_file_path)
    max_age = 7 * 24 * 60 * 60  # 1 week in seconds

    if file_age > max_age
      abort "repos.yml is older than 1 week (#{file_age.to_i} seconds). Run script/clobber to refresh."
    end
  end

  private

  def validate_repos_yml
    puts "Validating repos.yml..."

    unless File.exist?(REPOS_FILE)
      abort "#{REPOS_FILE} does not exist!"
    end

    begin
      data = YAML.load_file(REPOS_FILE)
      unless data.is_a?(Hash) && data.any?
        abort "#{REPOS_FILE} does not contain valid repository data!"
      end

      data.each do |name, info|
        unless info.is_a?(Hash) &&
          info['description'].is_a?(String) &&
          info['last_updated'].is_a?(String)
          abort "Invalid data format for repository #{name}: #{info.inspect}"
        end
      end
    # rescue YAML::ParserError, YAML::ParseError => e
    #   abort "Failed to parse #{REPOS_FILE}: #{e.message}"
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

    data = YAML.load_file(REPOS_FILE)

    empty_repos = 0
    data.each do |name, _info|
      repo_dir = File.join(REPOS_DIR, name)
      unless File.directory?(repo_dir)
        abort "Repository directory missing: #{repo_dir}"
      end

      # Count empty repositories
      files = Dir.glob(File.join(repo_dir, '*'))
      if files.empty?
        empty_repos += 1
        puts "Warning: Repository #{name} appears empty"
      end

      # Check repo name format (no periods or slashes)
      if name.include?('.') || name.include?('/') || name.include?('\\')
        abort "Invalid repository name format: #{name}"
      end
    end

    # Allow up to 5 empty repositories
    if empty_repos > 5
      abort "Too many empty repositories: #{empty_repos} (max 5 allowed)"
    end
  end

  def validate_multiple_repos_exist
    puts "Validating at least 8 multiple_* repositories exist in repos.yml..."

    data = YAML.load_file(REPOS_FILE)
    multi_repos = data.select { |name, _info| name.start_with? 'multiple_' }.count
    if multi_repos < 8
      abort "Too few multiple repositories in repos.yml: #{multi_repos} (expected >= 8)"
    end
  end
end

if __FILE__ == $0
  validator = DownloadValidator.new(ARGV[0])
  validator.validate
end
