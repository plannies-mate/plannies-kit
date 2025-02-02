# frozen_string_literal: true

Bundler.require

class ProcessBase
  REPOS_DIR = 'repos'

  LOG_DIR = 'log'
  REPOS_FILE = "#{LOG_DIR}/repos.yml"
  SCRAPER_ANALYSIS_FILE = "#{LOG_DIR}/scraper_analysis.js"
  ANALYSIS_RESULTS_FILE = "#{LOG_DIR}/analysis_results.yml"

  # Load private repos from private_repos.yml
  PRIVATE_REPOS_FILE = File.join('config', 'private_repos.yml')

  GITHUB_ORG = "planningalerts-scrapers"
  GITHUB_REPOS_URL = "https://github.com/orgs/#{GITHUB_ORG}/repositories.json?q=archived%3Afalse"
  GITHUB_REPO_PREFIX = "git@github.com:#{GITHUB_ORG}"

  DOWNLOAD_OUTPUT_FILES = [
    REPOS_FILE
  ].freeze

  ANALYSIS_OUTPUT_FILES = [
    SCRAPER_ANALYSIS_FILE,
    ANALYSIS_RESULTS_FILE
  ].freeze

  def initialize
    abort "Directory #{REPOS_DIR} does not exist!" unless Dir.exist?(REPOS_DIR)
  end
end
