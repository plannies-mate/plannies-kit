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
    puts "Processing #{total_repos} out of #{repos.size} repositories#{" (LIMIT=#{@limit})" if @limit}"

    repos.take(total_repos).each do |repo|
      clone_repo(repo)
    end

    puts "\nCompleted downloading #{total_repos} repositories"
  end

  private

  def fetch_repo_list
    puts "Fetching repository list..."
    page = 1
    all_repos = []
    per_page = 30

    # Count existing repos
    existing_count = Dir.glob(File.join(@repo_dir, '*'))
                        .select { |f| File.directory?(f) && File.basename(f) != '.git' }
                        .count

    loop do
      url = "https://api.github.com/orgs/planningalerts-scrapers/repos?page=#{page}&per_page=#{per_page}"
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        repos = JSON.parse(response.body)
        break if repos.empty?
        all_repos.concat(repos)

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
    descriptions = all_repos.map { |r| [r['name'], r['description']] }.to_h
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
    system("git clone --no-checkout #{repo['clone_url']} #{target_dir}")

    Dir.chdir(target_dir) do
      # Configure sparse checkout to exclude test directories
      system("git config core.sparseCheckout true")
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
      system("git checkout")
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
