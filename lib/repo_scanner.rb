class RepoScanner < ProcessBase
  LANGUAGE_CONFIGS = {
    'scraper.rb' => { comment_start: '#', import_start: 'Bundler.require', echo_cmd: 'puts' },
    'scraper.php' => { comment_start: '//', import_start: 'require_once', echo_cmd: 'echo' },
    'scraper.py' => { comment_start: '#', import_start: 'import', echo_cmd: 'print' },
    'scraper.pl' => { comment_start: '#', import_start: 'use', echo_cmd: 'print' },
    'scraper.js' => { comment_start: '//', import_start: 'require', echo_cmd: 'console.log' }
  }.freeze

  NO_SCRAPER_REASON = 'no_scraper'.freeze
  PLACEHOLDER_REASON = 'placeholder'.freeze
  TRIVIAL_REASON = 'trivial'.freeze

  IGNORE_REASONS = [
    NO_SCRAPER_REASON,
    PLACEHOLDER_REASON,
    TRIVIAL_REASON
  ].freeze

  attr_reader :repo_name, :repo_path, :scraper_file

  def initialize(repo_name)
    @repo_name = repo_name
    @repo_path = File.join(REPOS_DIR, repo_name)
    @scraper_file = detect_scraper_file
    @language_config = LANGUAGE_CONFIGS[File.basename(@scraper_file)] if @scraper_file
  end

  def ignore?
    !ignore_reason.nil?
  end

  # ignore_reason - string if this repo should be ignored, otherwise nil
  def ignore_reason
    if !has_scraper?
      NO_SCRAPER_REASON
    elsif placeholder_scraper?
      PLACEHOLDER_REASON
    elsif trivial_scraper?
      TRIVIAL_REASON
    elsif !active_scraper?
      raise "Unable to classify SCRAPER #{@repo_name} with scraper file: #{@scraper_file}"
    end
  end

  # active_lines(only_scraper: false)
  # Excludes Passive lines of code which are
  # Based on language detected - see "Scraper Language Classification" in SPECS.md
  # - Passive lines of code are defined as
  # * Lines starting with "Comments start with", "echo command" or "import command" from the language table
  # * Blank lines
  # Result is cached
  def active_lines(only_scraper: false)
    return [] unless @scraper_file

    @active_lines ||= {}
    @active_lines[only_scraper] ||=
      begin
        content = if only_scraper
                    File.read(@scraper_file)
                  else
                    Dir.glob(File.join(@repo_path, '**/*'))
                       .map { |file| File.read(file) }
                       .join("\n")
                  end
        lines = content.lines.map(&:strip)

        # Remove passive lines based on language
        lines.reject do |line|
          line.empty? ||
            line.start_with?(@language_config[:comment_start]) ||
            line.start_with?(@language_config[:echo_cmd]) ||
            line.start_with?(@language_config[:import_start])
        end
      end
  end

  private

  def detect_scraper_file
    LANGUAGE_CONFIGS.each do |scraper_file, _data|
      file_path = File.join(@repo_path, scraper_file)
      return file_path if File.exist?(file_path)
    end
    nil
  end

  def has_scraper?
    !@scraper_file.nil?
  end

  def trivial_scraper?
    has_scraper? && !placeholder_scraper? && active_lines(only_scraper: false).count < 15
  end

  def placeholder_scraper?
    has_scraper? && active_lines(only_scraper: true).empty?
  end

  def active_scraper?
    has_scraper? && !(placeholder_scraper? || trivial_scraper?)
  end
end

