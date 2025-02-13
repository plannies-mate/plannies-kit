# Plannies Mate

Plannies Mate is a Ruby command-line tool that analyzes PlanningAlerts scrapers to extract unique identifiers and terms.

This helps the "Crikey! What's That?" (AKA WhatsThat) frontend project identify which scraper to use for different
council websites, minimizing the need to check repositories added after this analysis.

Note: This README focuses on installation and usage. For development:

- See GUIDELINES.md for development guidelines
- See SPECS.md for requirements and architecture
- See IMPLEMENTATION.md for implementation details

## Dependencies

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
./lib/validate_download.rb repos        # Downloads all repositories to repos/ AND updates status/download_run.json and status/descriptions.json
./lib/validate_download.rb repos 5      # Downloads only 5 repositories
./lib/validate_cleanup.rb repos         # Removes test files, binary files and .git directories
./lib/validate_analyze.rb repos         # Analyzes code and outputs terms
```

And run individual validate scripts with optional LIMIT parameter:

```bash
./lib/validate/validate_download.rb repos        # Validates at least 40 repositories where downloaded but less than 50
./lib/validate/validate_download.rb repos 5      # Validates at least 5 repositories where downloaded and less than 50
./lib/validate/validate_cleanup.rb repos         # Validates test files, binary files and .git directories are missing from repos
./lib/validate/validate_analyze.rb repos         # Validates output from Analyzes in log/*
```

The analysis generates:

- `log/scraper_analysis.js`: Words and descriptions for frontend use AND date download was run
- `log/debug_analysis.json`: Full analysis including URLs (for debugging)

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
