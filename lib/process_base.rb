# frozen_string_literal: true

Bundler.require

class ProcessBase
  REPOS_DIR = 'repos'

  LOG_DIR = 'log'
  REPOS_FILE = "#{LOG_DIR}/repos.yml"
  SCRAPER_ANALYSIS_FILE = "#{LOG_DIR}/scraper_analysis.js"
  ANALYSIS_RESULTS_FILE = "#{LOG_DIR}/analysis_results.yml"

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
