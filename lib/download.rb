#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'fileutils'
require 'net/http'
require 'uri'

require_relative 'process_base'

class RepoDownloader < ProcessBase
  SECONDS_PER_WEEK = 7 * 24 * 60 * 60
  MAX_REPOS_FILE_AGE = SECONDS_PER_WEEK # One week in seconds

  def initialize(limit = nil)
    @limit = limit ? limit.to_i : nil
    abort "LIMIT must be a positive number" if @limit && @limit < 1
    super()
  end

  def download_repos
    # Remove download and analysis output files before starting download
    ANALYSIS_OUTPUT_FILES.each do |file|
      FileUtils.rm_f(file)
    end

    repos = fetch_repos_list
    repo_count = @limit ? [@limit, repos.size].min : repos.size
    puts "Processing #{repo_count} out of #{repos.size} active repositories#{" (LIMIT=#{@limit})" if @limit}"

    repos.take(repo_count).each do |repo_name, data|
      puts "  REPO: #{repo_name}: #{data.inspect}" if ENV['DEBUG']
      clone_repo_if_missing(repo_name)
    end

    puts "\nCompleted checking #{repo_count} repositories are downloaded"
  end

  private

  def run_cmd(cmd)
    puts "Running: #{cmd}" if ENV['DEBUG']
    system(cmd, exception: true)
  end

  # returns cached repos list if its fresh and matches dir count
  def fetch_repos_list
    if File.exist?(REPOS_FILE)
      expect_names = repos_dirs
      repos_list = YAML.load_file(REPOS_FILE)
      cached_names = repos_list.keys.sort
      if expect_names != cached_names || expect_names.count < 20
        puts "WARNING: dirs under repos/ doesn't match log/repos.yml names"
        system 'script/clobber'
        nil
      elsif repos_cache_id_old?
        puts "NOTE: Forcing weekly refresh of repos"
        system 'script/clobber'
        nil
      else
        repos_list
      end
    end

    fetch_fresh_repos_list
  end

  private

  def repos_dirs
    puts "Checking existing repositories..."
    Dir.glob(File.join(REPOS_DIR, '*'))
       .select { |f| File.directory?(f) && File.basename(f) != '.git' }
       .map { |f| File.basename(f) }
       .sort
  end

  def repos_cache_id_old?
    return false unless File.exist?(REPOS_FILE)

    # Force weekly refresh of repositories
    (Time.now - File.mtime(REPOS_FILE)) > MAX_REPOS_FILE_AGE
  end

  # Fetch fresh repos list from github merged into private_repos list in config
  def fetch_fresh_repos_list
    puts "Fetching repository list..."
    page = 1
    repos_list = YAML.load_file(PRIVATE_REPOS_FILE)

    while !@limit || repos_list.size < @limit
      page_result = fetch_repo_page(page)
      break unless page_result

      repos, page_count = page_result
      repos.each do |repo|
        name = repo['name']
        repos_list[name] = {
          'description' => repo['description'] || '',
          'last_updated' => (
            repo['lastUpdated']&.dig('timestamp') ||
              Time.now.iso8601
          )
        }
      end

      break if @limit && repos_list.size >= @limit
      break if page >= page_count
      page += 1
    end

    FileUtils.mkdir_p(File.dirname(REPOS_FILE))
    File.write(REPOS_FILE, YAML.dump(repos_list))

    repos_list
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
    raise "Missing payload in response" unless payload&.any?

    repos = payload['repositories']
    page_count = payload['pageCount']&.to_i
    raise "Missing details in response" unless repos && page_count

    # Filter out archived repos
    active_repos = repos.reject { |repo| repo['archived'] }
    puts "Page #{page}: Found #{repos.size} repos: #{active_repos.size} active. #{repos.size - active_repos.size} archived"

    [active_repos, page_count]
  end

  def clone_repo_if_missing(name)
    target_dir = File.join(REPOS_DIR, name)
    return if Dir.exist?(target_dir)

    clone_url = "#{GITHUB_REPO_PREFIX}/#{name}.git"
    puts "Cloning #{clone_url} to #{target_dir} ..."

    begin
      # Use --no-checkout to avoid checking out files, then do a sparse checkout
      run_cmd("git clone --no-checkout #{clone_url} #{target_dir}")

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
          !screenshots/
          !Gemfile*
          !*.md 
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
  $stdout.sync = true
  $stderr.sync = true

  downloader = RepoDownloader.new(ARGV[0])
  downloader.download_repos
end
