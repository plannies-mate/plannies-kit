# Plannies Mate

A tool to analyze PlanningAlerts scrapers and extract unique identifiers and terms.

## Requirements

- Ruby 3.0 or newer
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

3. Make scripts executable:
   ```bash
   chmod +x script/*
   ```

## Usage

Run the entire process:
```bash
./script/process
```

Or run individual steps:
```bash
./script/download.rb     # Downloads repositories to repos/
./script/cleanup.rb repos  # Removes test files and .git directories
./script/analyze.rb      # Analyzes code and outputs terms
```

The analyzer will output a JavaScript object mapping repository names to arrays of unique terms, ready to paste into your extraMatchWords configuration.

## Scripts

- `download.rb`: Downloads PlanningAlerts scraper repositories using sparse checkout to skip test directories
- `cleanup.rb`: Removes test files, test directories, and .git directories
- `analyze.rb`: Extracts unique non-dictionary terms from code files
- `process`: Runs all scripts in sequence

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
