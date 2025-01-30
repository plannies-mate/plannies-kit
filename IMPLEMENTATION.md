# IMPLEMENTATION

This project's documentation is split across several files:
- GUIDELINES.md - Guidelines for AI assistants and developers
- SPECS.md - Core requirements and system architecture
- IMPLEMENTATION.md (this file) - Detailed implementation guidance and algorithms

Please read ALL three files before proceeding.

Note: README.md contains installation and usage instructions which are not relevant for AIs.

## repo classification algorithm

Repos are classified so placeholder and trivial repos can be eliminated from the output list.

### Programming language

Scrapers are written in the following languages.

| Language | Scraper file | Comments start with | echo command | import command |
| Ruby | scraper.rb | # | puts | Bundler.require |
| PHP | scraper.php | // | echo | require_once |
| Python | scraper.py | # | print | import |
| Perl | scraper.pl | # | print | use |
| Node.js | scraper.js | // | console.log | require |

Based on the scraper file name, lines are regarded as passive if they are blank, or the lead with the comment or
import command listed above (after being stripped of leading spaces)

### placeholder

A repo is regarded as a placeholder if its scrapper file only contains passive lines AND the repo is not trivial.
These repos were previously called broken, but that is a guess as to why this repo is a placeholder, not a fact.

### trivial

A repo is regarded as trivial if there are only between 1 and 15 lines in total across all its files ignoring passive
lines.

FYI (currently) the smallest useful scraper is `HuonValleyDA/scraper.rb` at 25 lines long.

## Scripts and Their Responsibilities

### download.rb

- Downloads list of github repositories
- Supports optional LIMIT parameter for testing
- Stores repository descriptions in descriptions.json
- Skips existing repositories

### cleanup.rb

- Removes test files, binary files, and test directories
- Removes .git directories and unnecessary project files
- Handles common binary file extensions

### analyze.rb

- Analyzes code files for unique terms
- Extracts and processes URLs
- Filters words using aspell and COMMON_WORDS
- Outputs scraper_analysis.js and debug_analysis.json

## Status files

These are internal status passed between different stages as well as logs for debugging

### Download state

When run download is run it maintains two status files:

* `log/download_run.json` - Json file with `{ last_run: "date and time" }` - updated if missing or run for all
* `log/descriptions.json` - json files with hash of name to description, - updates repos downloaded

```json
{
  "city_of_sydney": "City of Sydney Development Applications",  
  "whittlesea": "City of Whittlesea development applications"
}
```

### `log/debug_analysis.json`

This format is flexible - it needs to include all relevant information useful for debugging but can change as
processing needs change.

```json
{
  "metadata": {
    "generated_at": "2025-01-29T11:40:09Z",
    "repos_analyzed": 40,
    "trivial_scrapers_skipped": 4,
    "broken_scrapers_found": 2,
    "no_scraper_file": 3
  },
  "repos": {
    "yarra": {
      "name": "yarra",
      "description": "Yarra City Development Applications",
      "status": "active",
      "urls": [
        "https://www.yarracity.vic.gov.au/MyPlanning-application-xsearch"
      ],
      "words": ["myplanning", "xearch"],
      "main_line_count": 47,
      "total_line_count": 47
    }
    // ... more repos
  }
}
```

## Error Handling

- Scripts validate arguments and fail fast
- Fail fast on GitHub API errors
- Fail fast on errors from external programs
- Report progress clearly but concisely
- Output clear error messages with potential solutions
- clean up any temp files used
  - Use at_exit hook as needed to ensure process and temp file clean up

## Code Structure & Style

- Ruby code in `lib/` directory, executed from project root
    - script/process runs all the lib/*.rb files
- Scripts require explicit repo directory parameter that exists (created by `process/process`)
- Each file / class handles one focused responsibility each
- Keep methods under 20 lines and files under 200 lines
- Variable names reflect planning/scraping domain
- Follow standard Ruby style best practices

## Command Line Interface

- Scripts validate arguments and fail fast with clear errors
- Progress reporting is clear but concise
- Optional LIMIT parameter to process fewer repos for testing

## Performance & Security

- Skip re-downloading existing repos more than once a week
    - if the download state is more than a week old then call
      `script/clobber` to force re-download of all repos
- Cleanup removes binary files so process just processes the files that are left
- Handle GitHub pagination
- Fail on API rate limiting return
- Validate repository names and file paths (no periods (`.`) nor slashes (`/` or `\`) in repo name )
- Don't execute content from repos

## Development Practices

- Use RuboCop for code style (when/if needed)
- Document dependencies in Gemfile
- Keep commits focused and well-described
- Ignore appropriate files (repos/, log/, temp files)
- Test with small LIMIT values during development
- Add new common words to COMMON_WORDS when found
    - dictionary words are handled by aspell
- Document any aspell configuration changes needed

## Implementation Requirements

- Double-check word extraction rules before making changes
- No assumptions about URL formats
- Process paths and query parameters separately
- Use consistent word extraction across all sources
- Extract words ONLY from urls found in the files
- Skip archived repositories during download
- Handle GitHub API pagination correctly

## Common Words Management

- Common (non dictionary) words list is maintained in COMMON_WORDS constant
- Words must be lowercase
- Words should be commonly found in planning/government contexts
- Review and update list periodically based on results

## Process Flow

1. Download repositories:
    - Skip if repos exist and recent
    - Handle rate limits and pagination
    - Store descriptions.json
2. Clean repositories:
    - Remove docs, test files and binaries
    - Keep main scraper files
3. Analyze code:
    - Find and read scraper files
    - Extract and normalize words
    - Filter through aspell
    - Generate output files

## Quality Checks

- Verify word extraction matches rules exactly
- Check aspell process cleanup
- Validate output file formats
- Confirm repository counts match
- Ensure proper error handling
