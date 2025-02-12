module Protection
  class AuthorityUrlMatcher
    REQUIRED_KEYS = [:name, :url, :scraper, :last_month]

    def initialize(morph_cache_file)
      @cache = YAML.load_file(morph_cache_file)
      @authority_ids = @cache.keys.select { |k| k.is_a?(Symbol) } # Only want the authority keys, not metadata
      validate_cache
    end

    def match_scraper_urls
      @duplicates = []

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

    def match_authority(authority_id)
      multiple_matches = nil
      [
        "/authorities/#{authority_id}",
        "/authorities/#{authority_id.to_s.gsub('_', '')}",
        "/authorities/#{authority_id.to_s.sub(/_[^_]*$/, '')}",
        "/authorities/#{authority_id.to_s.sub(/_[^_]*_[^_]*$/, '')}"
      ].uniq.each do |href|
        return href.sub('/authorities/', '') if @authority_ids.include?(href.sub('/authorities/', ''))

        matches = @authority_ids.select { |auth_id| href.sub('/authorities/', '') == auth_id.to_s }
        return matches.first if matches.size == 1

        multiple_matches = matches if matches.any?
      end

      warn "No unique match found for authority: #{authority_id}, found: #{multiple_matches&.join(', ')}"
      nil
    end

    def match_authority_files
      puts "Looking for authority configuration files..."

      Dir.glob("lib/*/authorities.rb").each do |file|
        puts "\nProcessing #{file}..."
        begin
          content = File.read(file)
          module_name = content.match(/module\s+(\w+)/)[1]
          puts "  Found module: #{module_name}"

          # Load the config without requiring the file
          config_text = content.match(/AUTHORITIES\s*=\s*{([^}]+)}/m)[1]
          config = eval("{#{config_text}}")

          puts "  Found #{config.size} authorities"
          config.each do |key, data|
            puts "    Checking #{key}..."
            matched_authority = match_authority(key)

            if matched_authority
              auth_id = matched_authority
              puts "      Matched to #{auth_id}"

              # Track duplicates
              if @cache[auth_id][:config_file]
                @duplicates << {
                  authority: auth_id,
                  files: [@cache[auth_id][:config_file], file],
                  keys: [@cache[auth_id][:config_key], key]
                }
                puts "      WARNING: Duplicate configuration found!"
              end

              # Add to existing data
              @cache[auth_id][:config_file] = file
              @cache[auth_id][:config_key] = key
              @cache[auth_id][:config_url] = data[:url] if data[:url]
            else
              puts "      No match found"
              @cache[:unmatched_authorities] ||= []
              @cache[:unmatched_authorities] << {
                key: key,
                url: data[:url],
                file: file,
                module: module_name
              }
            end
          end
        rescue => e
          puts "  Error processing #{file}: #{e.message}"
          puts e.backtrace
        end
      end
    end

    def match_scraper_files
      require_relative "repo_scanner"

      Dir.glob("repos/*/scraper.*").each do |file|
        begin
          content = File.read(file)
          repo_name = file.split('/')[1]

          # Use RepoScanner to get active lines without comments
          scanner = RepoScanner.new(repo_name)
          active_lines = scanner.active_lines(only_scraper: true)

          if (url = find_longest_url(active_lines.join("\n")))
            matched_authority = @authority_ids.find do |auth_id|
              @cache[auth_id][:scraper]&.to_s == repo_name
            end

            if matched_authority
              auth_id = matched_authority
              @cache[auth_id][:scraper_file] = file
              @cache[auth_id][:scraper_url] = url
            else
              @cache[:unmatched_scrapers] ||= []
              @cache[:unmatched_scrapers] << {name: repo_name, url: url, file: file}
            end
          end
        rescue => e
          puts "Error processing #{file}: #{e.message}"
        end
      end
    end

    def find_longest_url(content)
      urls = content.scan(%r{https?://[^'"#${}\s]*})
                    .reject { |url| url.downcase.start_with?('https://github.com', 'https://morph.io') }
      urls.max_by(&:length)
    end

    def generate_report
      puts '',
           "=" * 60,
           "AUTHORITY MATCHING REPORT",
           "=" * 60

      # First show authorities with URLs
      authorities_with_both_urls = []
      authorities_with_scraper_urls = []
      authorities_with_site_urls = []
      authorities_without_urls = []

      @authority_ids.each do |auth_id|
        next unless auth_id.is_a?(Symbol) # Skip metadata keys
        data = @cache[auth_id]

        if data[:scraper_url] && data[:url]
          authorities_with_both_urls << [auth_id, data]
        elsif data[:scraper_url]
          authorities_with_scraper_urls << [auth_id, data]
        elsif data[:url]
          authorities_with_site_urls << [auth_id, data]
        else
          authorities_without_urls << [auth_id, data]
        end
      end

      puts '',
           "=" * 60,
           "#{authorities_with_both_urls.size} Authorities with BOTH URLs found:",
           "=" * 60
      authorities_with_both_urls.sort_by { |id, _| id.to_s }.each do |auth_id, data|
        puts "\n#{auth_id} (#{data[:name]}):"
        puts "  Morph URL: #{data[:url]}" if data[:url]
        # puts "  Config URL: #{data[:config_url]}" if data[:config_url]
        puts "  Scraper URL: #{data[:scraper_url]}" if data[:scraper_url]
        puts "  Scraper: #{data[:scraper]}"
        puts "  Apps last month: #{data[:last_month]}"
      end

      puts '',
           '=' * 60,
           "#{authorities_with_scraper_urls.size} Authorities with ONLY SCRAPER URLs found:",
           "=" * 60
      authorities_with_scraper_urls.sort_by { |id, _| id.to_s }.each do |auth_id, data|
        puts "\n#{auth_id} (#{data[:name]}):"
        puts "  Morph URL: #{data[:url]}" if data[:url]
        # puts "  Config URL: #{data[:config_url]}" if data[:config_url]
        puts "  Scraper URL: #{data[:scraper_url]}" if data[:scraper_url]
        puts "  Scraper: #{data[:scraper]}"
        puts "  Apps last month: #{data[:last_month]}"
      end

      puts '',
           '=' * 60,
           "#{authorities_with_site_urls.size} Authorities with ONLY Morph URLs found:",
           "=" * 60
      authorities_with_site_urls.sort_by { |id, _| id.to_s }.each do |auth_id, data|
        puts "\n#{auth_id} (#{data[:name]}):"
        puts "  Morph URL: #{data[:url]}" if data[:url]
        # puts "  Config URL: #{data[:config_url]}" if data[:config_url]
        puts "  Scraper URL: #{data[:scraper_url]}" if data[:scraper_url]
        puts "  Scraper: #{data[:scraper]}"
        puts "  Apps last month: #{data[:last_month]}"
      end

      puts '',
           '=' * 60,
           "#{authorities_without_urls.size} Authorities with NO URLs found:",
           "=" * 60
      authorities_without_urls.sort_by { |id, _| id.to_s }.each do |auth_id, data|
        puts "\n#{auth_id} (#{data[:name]}):"
        puts "  Scraper: #{data[:scraper]}"
        puts "  Apps last month: #{data[:last_month]}"
      end

      if @cache[:unmatched_authorities]&.any?
        puts '',
             '=' * 60,
             "#{@cache[:unmatched_authorities].size} Unmatched Authorities:",
             "=" * 60
        @cache[:unmatched_authorities].each do |auth|
          puts "  #{auth[:key]} in #{auth[:file]}"
        end
      end

      if @cache[:unmatched_scrapers]&.any?
        puts '',
             '=' * 60,
             "Unmatched Scrapers:",
             "=" * 60
        @cache[:unmatched_scrapers].each do |scraper|
          puts "  #{scraper[:name]} (#{scraper[:url]}) in #{scraper[:file]}"
        end
      end

      puts '',
           '=' * 60

      # Return structured data for the next stage
      {
        matched: @cache.reject { |k| !k.is_a?(Symbol) },
        unmatched_authorities: @cache[:unmatched_authorities] || [],
        unmatched_scrapers: @cache[:unmatched_scrapers] || [],
        duplicates: @duplicates
      }
    end

    # Return structured data for the next stage
    {
      matched: @cache.reject { |k| !k.is_a?(Symbol) },
      unmatched_authorities: @cache[:unmatched_authorities] || [],
      unmatched_scrapers: @cache[:unmatched_scrapers] || [],
      duplicates: @duplicates
    }

    # Return structured data for the next stage
    {
      matched: @cache.reject { |k| !k.is_a?(Symbol) },
      unmatched_authorities: @cache[:unmatched_authorities] || [],
      unmatched_scrapers: @cache[:unmatched_scrapers] || [],
      duplicates: @duplicates
    }
  end
end
end
