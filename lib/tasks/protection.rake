namespace :protection do
  desc 'Fetch and cache current Morph.io scraper statuses'
  task :fetch_status do
    require_relative '../protection/morph_status_fetcher'
    fetcher = Protection::MorphStatusFetcher.new
    fetcher.fetch
  end

  desc 'Match authority URLs from different sources'
  task :match_urls => :fetch_status do
    matcher = Protection::AuthorityUrlMatcher.new(Protection::MorphStatusFetcher::CACHE_FILE)
    results = matcher.match_scraper_urls

    # Save full results for later analysis
    File.write(
      File.join(ProcessBase::LOG_DIR, 'url_matching.yml'),
      YAML.dump(results)
    )
  end

  desc 'Get protection details from site urls and add to data'
  task :get_site_details => :match_urls do
    raise "TODO"
  end


  desc 'Analyze protection patterns and correlate with scraper status'
  task :analyze => :get_site_details do
    require_relative '../protection/analyzer'
    analyzer = Protection::Analyzer.new
    analyzer.analyze
  end
end
