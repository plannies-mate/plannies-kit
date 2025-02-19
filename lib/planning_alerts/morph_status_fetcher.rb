module Protection
  class MorphStatusFetcher
    CACHE_FILE = File.join('config', 'planning_alert_authorities.yml')
    CACHE_EXPIRY = 86400 # 24 hours in seconds

    def initialize
      @morph_scraper = Protection::PlanningAlertsScraper.new
    end

    def fetch
      return load_cache if cache_valid?

      fetch_fresh_data
    end

    private

    def cache_valid?
      return false unless File.exist?(CACHE_FILE)

      cache_age = Time.now - File.mtime(CACHE_FILE)
      cache_age < CACHE_EXPIRY
    end

    def load_cache
      YAML.load_file(CACHE_FILE)
    end

    def fetch_fresh_data
      puts "Fetching fresh Morph.io status data..."
      statuses = {}

      authorities = Protection::AuthorityUrlResolver.selected_authorities
      authorities.each do |authority|
        begin
          data = @morph_scraper.fetch_authority_data(authority)
          details = Protection::AuthorityUrlResolver.get_authority_detail(authority)
          statuses[authority] = analyze_status(data, details)
        rescue => e
          puts "Error fetching #{authority}: #{e.message}"
        end
      end

      save_cache(statuses)
      statuses
    end

    def analyze_status(data, details)
      {
        working: !data[:warning],
        scraper: data[:scraper],
        last_week: data[:week],
        last_month: data[:month],
        warning: data[:warning],
        url: details[:url],
        name: details[:name]
      }
    end

    def save_cache(data)
      FileUtils.mkdir_p(File.dirname(CACHE_FILE))
      File.write(CACHE_FILE, YAML.dump(data))
    end
  end
end
