$LOAD_PATH << "./lib"

require "bundler"
Bundler.require(:default, :development, :test)

Dir.glob('**/*.rb', base: 'lib/').each { |r| require r }

# Load all rake tasks from lib/tasks
Dir.glob('lib/tasks/*.rake').each { |r| load r }

desc 'Default task shows available commands'
task :default do
  puts "\nAvailable commands:"
  puts "\nMorph Status Tasks:"
  puts "  rake morph:status     # Generate a report of Planning Alerts authority statuses"
  puts "  rake morph:links      # Generate categorized links for authorities"
  puts "\nProtection Analysis Tasks:"
  puts "  rake protection:fetch_status  # Fetch and cache current Morph.io scraper statuses"
  puts "  rake protection:analyze       # Analyze protection patterns and correlate with scraper status"
  puts "                                 (includes running fetch_status first)"
  puts "\nBoth fetch_status and analyze accept an optional LIMIT parameter, e.g.:"
  puts "  rake protection:analyze LIMIT=5"
  puts "\nAdd DEBUG=1 for verbose output, e.g.:"
  puts "  rake protection:analyze DEBUG=1"
end

desc "Ensures required tools are available"
task :check_dependencies do
  missing = []

  # Check Ruby version
  required_version = '3.3'
  actual_version = RUBY_VERSION
  unless Gem::Version.new(actual_version) >= Gem::Version.new(required_version)
    missing << "Ruby #{required_version} or newer (you have #{actual_version})"
  end

  # Check for aspell
  unless system('which aspell > /dev/null 2>&1')
    missing << 'aspell (brew install aspell on macOS, apt-get install aspell on Ubuntu)'
  end

  # Check for git
  unless system('which git > /dev/null 2>&1')
    missing << 'git'
  end

  if missing.any?
    abort "\nMissing required dependencies:\n#{missing.map { |m| "  - #{m}" }.join("\n")}\n\n"
  end
end

# Add dependency check to all tasks except default
Rake.application.tasks.each do |task|
  next if %w[check_dependencies default].include? task.name
  task.enhance([:check_dependencies])
end
