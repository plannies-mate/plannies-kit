class ProcessBase
  REPOS_DIR = 'repos'
  LOG_DIR = 'log'
  REPOS_FILE = "#{LOG_DIR}/repos.json"

  def initialize
    abort "Directory #{REPOS_DIR} does not exist!" unless Dir.exist?(REPOS_DIR)
  end
end