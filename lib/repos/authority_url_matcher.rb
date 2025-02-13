module Protection
  class AuthorityUrlMatcher
    REQUIRED_KEYS = [:name, :url, :scraper, :last_month]

    def initialize(morph_cache_file)
      @cache = YAML.load_file(morph_cache_file)
      @authority_ids = @cache.keys.select { |k| k.is_a?(Symbol) } # Only want the authority keys, not metadata
      validate_cache
    end

    def match_scraper_urls
      @unmatched = { authorities: [], scrapers: [] }

      puts "Matching authority configuration files..."
      match_authority_files

      puts "Matching scraper files..."
      match_scraper_files

      generate_report
    end

    private

    def validate_cache
      @authority_ids.each do |auth_id|
        missing = REQUIRED_KEYS - @cache[auth_id].keys
        raise "Missing required keys #{missing} for #{auth_id}" unless missing.empty?
      end
    end

    def match_authority_files
      Dir.glob("repos/multiple_*/lib/*/authorities.rb").each do |file|
        begin
          extractor = Protection::AuthorityDataExtractor.new(file)
          authorities = extractor.extract_authorities

          puts "\nProcessing authorities from #{file}..."
          authorities.each do |authority_id, url|
            next unless url

            matched_authority = match_authority(authority_id)
            if matched_authority
              puts "  Matched #{authority_id} from repo to #{matched_authority} from morph.io"
              @cache[matched_authority][:scraper_url] = url
            else
              puts "  No match found for #{authority_id} from repo"
              @unmatched[:authorities] << {
                authority_id: authority_id,
                url: url,
                source: file
              }
            end
          end
        rescue => e
          puts "Error processing #{file}: #{e.message}"
        end
      end
    end

    def match_authority(authority_id)
      # Try exact match first
      return authority_id if @authority_ids.include?(authority_id)

      # Try without underscores
      no_underscores = authority_id.to_s.gsub('_', '')
      @authority_ids.each do |auth_id|
        return auth_id if auth_id.to_s.gsub('_', '') == no_underscores
      end

      # Try progressive partial matches
      parts = authority_id.to_s.split('_')
      while parts.length > 1
        partial = parts.join('_').to_sym
        return partial if @authority_ids.include?(partial)
        parts.pop
      end

      nil
    end

    def match_scraper_files
      Dir.glob("repos/*/scraper.*").each do |file|
        next if file.include?('multiple_') # Skip multiple_* scrapers as we handle them separately

        begin
          repo_name = file.split('/')[1]
          longest_url = extract_longest_url(file)
          next unless longest_url

          matched_authority = @authority_ids.find do |auth_id|
            @cache[auth_id][:scraper] == repo_name
          end

          if matched_authority
            @cache[matched_authority][:scraper_url] = longest_url
          else
            @unmatched[:scrapers] << {
              name: repo_name,
              url: longest_url,
              source: file
            }
          end
        rescue => e
          puts "Error processing #{file}: #{e.message}"
        end
      end
    end

    def extract_longest_url(file)
      content = File.read(file)
      urls = content.scan(%r{https?://[^'"#${}\s]*})
                    .reject { |url| url.downcase.start_with?('https://github.com', 'https://morph.io') }
      urls.max_by(&:length)
    end

    def generate_report
      puts '',
           "=" * 60,
           "AUTHORITY URL MATCHING REPORT",
           "=" * 60

      print_authority_sections
      print_unmatched_sections
      puts '', "=" * 60

      @cache
    end

    def print_authority_sections
      # Group authorities by URL status
      authorities_with_both = []
      authorities_missing_scraper = []

      @authority_ids.each do |auth_id|
        data = @cache[auth_id]
        if data[:scraper_url]
          authorities_with_both << [auth_id, data]
        else
          authorities_missing_scraper << [auth_id, data]
        end
      end

      print_matched_section(authorities_with_both)
      print_missing_section(authorities_missing_scraper)
    end

    def print_matched_section(authorities)
      puts '',
           "=" * 60,
           "#{authorities.size} Authorities with both URLs:",
           "=" * 60

      authorities.sort_by { |id, _| id.to_s }.each do |auth_id, data|
        puts "\n#{auth_id} (#{data[:name]}):"
        puts "  Morph URL: #{data[:url]}"
        puts "  Scraper URL: #{data[:scraper_url]}"
        puts "  Scraper: #{data[:scraper]}"
        puts "  Apps last month: #{data[:last_month]}"
      end
    end

    def print_missing_section(authorities)
      puts '',
           "=" * 60,
           "#{authorities.size} Authorities missing scraper URL:",
           "=" * 60

      authorities.sort_by { |id, _| id.to_s }.each do |auth_id, data|
        puts "\n#{auth_id} (#{data[:name]}):"
        puts "  Morph URL: #{data[:url]}"
        puts "  Scraper: #{data[:scraper]}"
        puts "  Apps last month: #{data[:last_month]}"
      end
    end

    def print_unmatched_sections
      if @unmatched[:authorities].any?
        puts '',
             "=" * 60,
             "Unmatched Authorities:",
             "=" * 60
        @unmatched[:authorities].each do |auth|
          puts "  #{auth[:authority_id]} #{auth[:url]} in #{auth[:source]}"
        end
      end

      if @unmatched[:scrapers].any?
        puts '',
             "=" * 60,
             "Unmatched Scrapers:",
             "=" * 60
        @unmatched[:scrapers].each do |scraper|
          puts "  #{scraper[:name]} #{scraper[:url]} in #{scraper[:source]}"
        end
      end
    end
  end
end
