module Protection
  class Analyzer < ProcessBase
    RESULTS_FILE = File.join(LOG_DIR, 'protection_analysis.yml')
    SUMMARY_FILE = File.join(LOG_DIR, 'protection_summary.yml')

    def initialize
      @detector = ProtectionDetector.new
      @results = {}
      super()
    end

    def analyze
      load_status_data
      analyze_repos
      generate_correlation_analysis
      output_results
    end

    private

    def load_status_data
      @status_cache = MorphStatusFetcher::CACHE_FILE
      unless File.exist?(@status_cache)
        raise "Please run rake protection:fetch_status first"
      end
      @scraper_statuses = YAML.load_file(@status_cache)
    end

    def analyze_repos
      puts "\nAnalyzing protection patterns..."
      repos.each do |repo_name, _data|
        analyze_repo(repo_name)
      end
    end

    def analyze_repo(repo_name)
      puts "  #{repo_name}..."
      url = find_longest_url(repo_name)
      return unless url

      begin
        protection_data = @detector.analyze(url)
        @results[repo_name] = {
          url: url,
          analysis: protection_data,
          scraper_status: matching_status(repo_name)
        }
      rescue => e
        puts "    Error: #{e.message}"
        @results[repo_name] = {
          url: url,
          error: e.message,
          scraper_status: matching_status(repo_name)
        }
      end
    end

    def matching_status(repo_name)
      # Match repo to morph status based on scraper.rb patterns
      authorities = MasterviewScraper.selected_authorities
      matching_authority = authorities.find do |authority|
        data = @scraper_statuses[authority]
        data && data[:scraper]&.downcase == repo_name.downcase
      end

      matching_authority ? @scraper_statuses[matching_authority] : nil
    end

    def find_longest_url(repo_name)
      repo_path = File.join(REPOS_DIR, repo_name)

      # Find scraper file
      scraper_file = find_scraper_file(repo_path)
      return nil unless scraper_file

      # Extract longest URL
      content = File.read(scraper_file)
      urls = content.scan(%r{https?://[^\s<>"']+})
                    .reject { |url| url.downcase.start_with?('https://github.com', 'https://morph.io') }

      urls.max_by(&:length)
    end

    def find_scraper_file(repo_path)
      RepoScanner::LANGUAGE_CONFIGS.each_key do |file|
        path = File.join(repo_path, file)
        return path if File.exist?(path)
      end
      nil
    end

    def output_results
      FileUtils.mkdir_p(LOG_DIR)
      File.write(RESULTS_FILE, YAML.dump(@results))
      File.write(SUMMARY_FILE, YAML.dump(@correlation))
      print_summary
    end

    # The rest of the summary printing methods would go here...
  end
end
