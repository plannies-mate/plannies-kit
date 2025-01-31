class ProcessBase
  REPOS_DIR = 'repos'

  LOG_DIR = 'log'
  REPOS_FILE = "#{LOG_DIR}/repos.json"
  SCRAPER_ANALYSIS_FILE = "#{LOG_DIR}/scraper_analysis.js"
  DEBUG_ANALYSIS_FILE = "#{LOG_DIR}/debug_analysis.json"
  BROKEN_SCRAPERS_FILE = "#{LOG_DIR}/broken_scrapers.txt"
  TRIVIAL_SCRAPERS_FILE = "#{LOG_DIR}/trivial_scrapers.txt"
  NO_SCRAPER_FILE = "#{LOG_DIR}/no_scraper.txt"

  ANALYSIS_OUTPUT_FILES = [
    REPOS_FILE,
    SCRAPER_ANALYSIS_FILE,
    DEBUG_ANALYSIS_FILE,
    BROKEN_SCRAPERS_FILE,
    TRIVIAL_SCRAPERS_FILE,
    NO_SCRAPER_FILE
  ].freeze

  def initialize
    abort "Directory #{REPOS_DIR} does not exist!" unless Dir.exist?(REPOS_DIR)
  end
end
