#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'fileutils'
require 'net/http'
require 'uri'

require_relative 'process_base'

class RepoDownloader < ProcessBase
  SECONDS_PER_WEEK = 7 * 24 * 60 * 60
  GITHUB_REPOS_URL = "https://github.com/orgs/planningalerts-scrapers/repositories.json?q=archived%3Afalse"

  def initialize(limit = nil)
    @limit = limit ? limit.to_i : nil
    abort "LIMIT must be a positive number" if @limit && @limit < 1
    super()
  end

  def download_repos
    repos = fetch_repo_list
    total_repos = @limit ? [@limit, repos.size].min : repos.size
    puts "Processing #{total_repos} out of #{repos.size} active repositories#{" (LIMIT=#{@limit})" if @limit}"

    repos.take(total_repos).each do |repo|
      clone_repo(repo)
    end

    puts "\nCompleted downloading #{total_repos} repositories"
  end

  private

  def run_cmd(cmd)
    puts "Running: #{cmd}" if ENV['DEBUG']
    system(cmd, exception: true)
  end

  def fetch_repo_list
    existing_count = count_existing_repos

    if should_use_cached_descriptions?(existing_count)
      return load_cached_descriptions
    end

    fetch_and_process_repos(existing_count)
  end

  private

  def count_existing_repos
    puts "Checking existing repositories..."
    Dir.glob(File.join(REPOS_DIR, '*'))
       .count { |f| File.directory?(f) && File.basename(f) != '.git' }
  end

  def should_use_cached_descriptions?(existing_count)
    return false unless File.exist?(REPOS_FILE)

    if (Time.now - File.mtime(REPOS_FILE)) > SECONDS_PER_WEEK
      puts "descriptions.json is over a week old - cleaning and re-downloading..."
      run_cmd('script/clobber')
      return false
    end

    if existing_count > 0
      puts "Already have #{existing_count} repositories - skipping download"
      return true
    end
    false
  end

  def load_cached_descriptions
    JSON.parse(File.read(REPOS_FILE)).map do |name, info|
      { 'name' => name, 'description' => info['description'] }
    end
  end

  def fetch_and_process_repos(existing_count)
    puts "Fetching repository list..."
    page = 1
    all_repos = []

    loop do
      page_result = fetch_repo_page(page)
      break unless page_result

      repos, page_count, repo_count = page_result
      all_repos.concat(repos)

      # Check if we already have all repos
      if repo_count <= existing_count
        puts "Already have #{existing_count} repos out of #{repo_count} total"
        break
      end

      break if @limit && all_repos.size >= @limit
      break if page >= page_count
      page += 1
    end

    # Save descriptions to file
    descriptions = all_repos.map { |r| [r['name'], r['description']] }.to_h
    File.write(File.join('log', 'descriptions.json'), JSON.pretty_generate(descriptions))

    all_repos
  end


  def fetch_repo_page(page)
    url = "#{GITHUB_REPOS_URL}&page=#{page}"
    uri = URI(url)
    puts "REQUEST: #{uri}" if ENV['DEBUG']
    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      puts "Error fetching page #{page}: #{response.code} #{response.message}"
      return nil
    end

    puts "RESPONSE: #{response.body}" if ENV['DEBUG']
    repos = JSON.parse(response.body)
    payload = repos['payload']
    return nil unless payload&.any?

    repos = payload['repositories']
    page_count = payload['pageCount']&.to_i
    repo_count = payload['repositoryCount']&.to_i
    return nil unless repos && page_count && repo_count

    # Filter out archived repos
    active_repos = repos.reject { |repo| repo['archived'] }
    if active_repos.size < repos.size
      puts "Page #{page}: Found #{repos.size} repos, #{repos.size - active_repos.size} archived"
    end

    [active_repos, page_count, repo_count]
  end

  def clone_repo(repo)
    name = repo['name']
    target_dir = File.join(REPOS_DIR, name)

    if Dir.exist?(target_dir)
      puts "Skipping #{name} - directory already exists"
      return
    end

    puts "Cloning #{name}... #{repo.inspect}"
    begin
      # Use --no-checkout to avoid checking out files, then do a sparse checkout
      run_cmd("git clone --no-checkout #{repo['clone_url']} #{target_dir}")

      Dir.chdir(target_dir) do
        # Configure sparse checkout to exclude test directories
        run_cmd("git config core.sparseCheckout true")
        File.write('.git/info/sparse-checkout', <<~SPARSE)
          /*
          !test/
          !tests/
          !spec/
          !specs/
          !fixtures/
          !doc/
          !docs/
          !expected/
        SPARSE
        run_cmd("git checkout")
      end
    rescue StandardError => _e
      FileUtils.rm_rf(target_dir)
      raise
    end
  end
end

if __FILE__ == $0
  downloader = RepoDownloader.new(ARGV[0])
  downloader.download_repos
end
