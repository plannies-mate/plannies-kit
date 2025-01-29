#!/usr/bin/env ruby

require 'json'
require 'fileutils'

class RepoDownloader
  @repo_dir = 'repos'

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
    output = `curl -s https://api.github.com/orgs/planningalerts-scrapers/repos`
    JSON.parse(output)
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
