# Project Guidelines: Plannies Mate

## Project Purpose

A Ruby command-line tool that analyzes PlanningAlerts scrapers to extract unique identifiers and terms. These help the "
Cricky, what's that?" frontend tool identify which scraper to use for different council websites.

## Code Structure & Style

- Ruby code in `lib/` directory, executed from project root,
  - script/process runs all the lib/*.rb files 
- Scripts require explicit repo directory parameter
- Scripts handle one focused task each
- Variable names reflect planning/scraping domain
- Follow standard Ruby style practices

## Command Line Interface

- Scripts validate arguments and fail fast with clear errors
- Progress reporting is clear but concise
- Optional LIMIT parameter to process fewer repos for testing

## Error Handling & Output

- Check prerequisites before processing (directories, files, etc)
- Handle GitHub API errors gracefully
- Output formats:
    - scraper_analysis.js: Structured data for frontend use
    - debug_analysis.json: Full analysis with URLs (for debugging)

## Development Practices

- Use RuboCop for code style (when/if needed)
- Document dependencies in Gemfile
- Keep commits focused and well-described
- Ignore appropriate files (repos/, temp files)

## Documentation

- README covers installation, dependencies and usage for the human
- GUIDELINES.md is focused mainly on AI's but includes design for both
- Document any special configurations as needed

## Performance & Security

- Skip re-downloading existing repos
- Cleanup removes binary files so process just processes the files that are left
- Handle GitHub API rate limiting and pagination
  - do a git clone on the page you got before requesting the next page
- Validate repository names and file paths
- Don't execute content from repos

Remember: The focus is on making scraper identification easier and more reliable for the "Cricky, what's that?" frontend
tool.
