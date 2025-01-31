class RepoScanner
  SCRAPER_PATTERNS = %w[scraper.rb scraper.php scraper.py scraper.pl scraper.js].freeze
  
  LANGUAGE_CONFIGS = {
    'scraper.rb' => { comment_start: '#', import_start: 'Bundler.require', echo_cmd: 'puts' },
    'scraper.php' => { comment_start: '//', import_start: 'require_once', echo_cmd: 'echo' },
    'scraper.py' => { comment_start: '#', import_start: 'import', echo_cmd: 'print' },
    'scraper.pl' => { comment_start: '#', import_start: 'use', echo_cmd: 'print' },
    'scraper.js' => { comment_start: '//', import_start: 'require', echo_cmd: 'console.log' }
  }.freeze

  def initialize(repo_path)
    @repo_path = repo_path
    @scraper_file = detect_scraper_file
    @language_config = @scraper_file ? LANGUAGE_CONFIGS[File.basename(@scraper_file)] : nil
  end

  def has_scraper?
    !@scraper_file.nil?
  end

  def active_lines(only_scraper: false)
    return [] unless @scraper_file

    content = File.read(@scraper_file)
    lines = content.lines.map(&:strip)

    # Remove passive lines based on language
    active = lines.reject do |line| 
      line.empty? || 
      line.start_with?(@language_config[:comment_start]) || 
      line.start_with?(@language_config[:import_start])
    end

    if only_scraper
      return active
    end

    # If not only scraper, include lines from all Ruby files
    ruby_lines = Dir.glob(File.join(@repo_path, '**/*.rb'))
      .flat_map { |file| File.readlines(file).map(&:strip) }
      .reject { |line| line.empty? || line.start_with?('#') }

    (active + ruby_lines).uniq
  end

  private

  def detect_scraper_file
    SCRAPER_PATTERNS.each do |pattern|
      file_path = File.join(@repo_path, pattern)
      return file_path if File.exist?(file_path)
    end
    nil
  end
end
