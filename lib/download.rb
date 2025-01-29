#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'net/http'
require 'uri'

class RepoDownloader
  def initialize(repo_dir)
    @repo_dir = repo_dir
    abort "Directory #{repo_dir} does not exist!" unless Dir.exist?(repo_dir)
  end

  def download_repos
    repos = fetch_repo_list
    puts "Found #{repos.size} repositories"

    repos.each do |repo|
      clone_repo(repo)
    end
  end

  private

  def fetch_repo_list
    puts "Fetching repository list..."
    page = 1
    all_repos = []

    loop do
      url = "https://api.github.com/orgs/planningalerts-scrapers/repos?page=#{page}&per_page=30"
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        repos = JSON.parse(response.body)
        break if repos.empty?
        all_repos.concat(repos)
        page += 1
      else
        puts "Error fetching page #{page}: #{response.code} #{response.message}"
        break
      end
    end

    # Save descriptions to file
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
  if ARGV.empty?
    abort "Usage: #{$0} REPO_DIR"
  end

  downloader = RepoDownloader.new(ARGV[0])
  downloader.download_repos
end
