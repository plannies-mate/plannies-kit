# Plannies Mate

A tool to analyze PlanningAlerts scrapers and extract unique identifiers and terms. These help the "Cricky, what's that?" frontend tool identify which scraper to use for different council websites.

## Requirements

- Ruby 3.3 or newer
- Aspell (`brew install aspell` on macOS, `apt-get install aspell` on Ubuntu)
- Git

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/plannies-mate.git
   cd plannies-mate
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

## Usage

Run the entire process:
```bash
./script/process
```

Or run individual scripts with optional LIMIT parameter:
```bash
./lib/download.rb repos        # Downloads all repositories to repos/
./lib/download.rb repos 5      # Downloads only 5 repositories
./lib/cleanup.rb repos         # Removes test files, binary files and .git directories
./lib/analyze.rb repos         # Analyzes code and outputs terms
```

The analysis generates:
- `tmo/scraper_analysis.js`: Words and descriptions for frontend use
- `tmp/debug_analysis.json`: Full analysis including URLs (for debugging)

## Scripts

- `lib/download.rb`: Downloads PlanningAlerts scraper repositories. Supports optional LIMIT parameter for testing
- `lib/cleanup.rb`: Removes test files, binary files, test directories, and .git directories
- `lib/analyze.rb`: Extracts unique non-dictionary terms from code files
- `script/process`: Runs all scripts in sequence
- `script/clobber`: Removes the repos directory

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
6. 