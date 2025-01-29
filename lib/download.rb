#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'net/http'
require 'uri'

class RepoDownloader
  def initialize(repo_dir, limit = nil)
    @repo_dir = repo_dir
    @limit = limit ? limit.to_i : nil
    abort "Directory #{repo_dir} does not exist!" unless Dir.exist?(repo_dir)
    abort "LIMIT must be a positive number" if @limit && @limit < 1
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

  def fetch_repo_list
    puts "Checking existing repositories..."
    # Count actual repo directories, excluding .git and descriptions.json
    existing_count = Dir.glob(File.join(@repo_dir, '*'))
                        .select { |f| File.directory?(f) && File.basename(f) != '.git' }
                        .count

    desc_file = File.join(@repo_dir, 'descriptions.json')
    if File.exist?(desc_file)
      # If descriptions.json is more than a week old, clean and redownload
      if (Time.now - File.mtime(desc_file)) > 7 * 24 * 60 * 60
        puts "descriptions.json is over a week old - cleaning and redownloading..."
        FileUtils.rm_rf(Dir.glob(File.join(@repo_dir, '*')))
      elsif existing_count > 0 # Only skip if we have repos
        puts "Already have #{existing_count} repositories - skipping download"
        return JSON.parse(File.read(desc_file)).map { |name, info| { 'name' => name, 'description' => info['description'] } }
      end
    end

    puts "Fetching repository list..."
    page = 1
    all_repos = []
    per_page = 30

    loop do
      # Try to filter archived repos at API level, but still check response
      # url = "https://github.com/orgs/planningalerts-scrapers/repositories.json?q=archived%3Afalse
      url = "https://api.github.com/orgs/planningalerts-scrapers/repos?archived=false&page=#{page}&per_page=#{per_page}"
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        repos = JSON.parse(response.body)
        break if repos.empty?

        # Filter out archived repos
        active_repos = repos.reject { |repo| repo['archived'] }
        puts "Page #{page}: Found #{repos.size} repos, #{repos.size - active_repos.size} archived" if active_repos.size < repos.size
        all_repos.concat(active_repos)

        # Check if we already have all repos
        if page == 1
          total_count = response['x-total-count']&.to_i || 0
          if total_count > 0 && total_count <= existing_count
            puts "Already have #{existing_count} repos out of #{total_count} total"
            break
          end
        end

        # Break early if we've hit our limit
        break if @limit && all_repos.size >= @limit

        page += 1
      else
        puts "Error fetching page #{page}: #{response.code} #{response.message}"
        break
      end
    end

    # Save descriptions to file (using all fetched repos even if limited)
    descriptions = all_repos.map { |r| [r['name'], { 'description' => r['description'] }] }.to_h
    File.write(File.join(@repo_dir, 'descriptions.json'), JSON.pretty_generate(descriptions))

    all_repos
  end

  def clone_repo(repo)
    name = repo['name']
    target_dir = File.join(@repo_dir, name)

    if Dir.exist?(target_dir)
      puts "Skipping #{name} - directory already exists"
      return
    end

    puts "Cloning #{name}..."
    # Use --no-checkout to avoid checking out files, then do a sparse checkout
    unless system("git clone --no-checkout #{repo['clone_url']} #{target_dir}")
      FileUtils.rm_rf(target_dir)
      raise "Error cloning #{name} - failed to clone #{repo['clone_url']}"
    end

    Dir.chdir(target_dir) do
      # Configure sparse checkout to exclude test directories
      unless system("git config core.sparseCheckout true")
        FileUtils.rm_rf(target_dir)
        raise "Error configuring #{name} - failed to clone #{repo['clone_url']}"
      end
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
      unless system("git checkout")
        FileUtils.rm_rf(target_dir)
        raise "Error checking out #{name} - failed to clone #{repo['clone_url']}"
      end
    end
  end
end

if __FILE__ == $0
  case ARGV.size
  when 1
    downloader = RepoDownloader.new(ARGV[0])
  when 2
    downloader = RepoDownloader.new(ARGV[0], ARGV[1])
  else
    abort "Usage: #{$0} REPO_DIR [LIMIT]"
  end

  downloader.download_repos
end
