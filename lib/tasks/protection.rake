namespace :protection do
  desc 'Refreshes planning alert authority list if its stale [stage 1]'
  task :refresh_config do
    require_relative '../url_analysis/te/morph_status_fetcher'
    fetcher = PlanniesMate::PlanningAlerts.new
    fetcher.freshon_config
  end

  desc 'Match authority URLs from different sources [stage 2]'
  task :match_urls => :fetch_status do
    matcher = Protection::AuthorityUrlMatcher.new(Protection::MorphStatusFetcher::CACHE_FILE)
    results = matcher.match_scraper_urls

    # Save full results for later analysis
    File.write(
      File.join(ProcessBase::LOG_DIR, 'url_matching.yml'),
      YAML.dump(results)
    )
  end

  desc 'Get url_analysis details from site urls and add to data [stage 3]'
  task :get_site_details => :match_urls do
    raise "TODO"
  end


  desc 'Analyze url_analysis patterns and correlate with scraper status [stage 4]'
  task :analyze => :get_site_details do
    require_relative '../url_analysis/analyzer'
    analyzer = Protection::Analyzer.new
    analyzer.analyze
  end
end
