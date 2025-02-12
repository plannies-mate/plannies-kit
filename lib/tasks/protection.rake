namespace :protection do
  desc 'Fetch and cache current Morph.io scraper statuses'
  task :fetch_status do
    require_relative '../protection/morph_status_fetcher'
    fetcher = Protection::MorphStatusFetcher.new
    fetcher.fetch
  end

  desc 'Analyze protection patterns and correlate with scraper status'
  task :analyze => :fetch_status do
    require_relative '../protection/analyzer'
    analyzer = Protection::Analyzer.new
    analyzer.analyze
  end
end
