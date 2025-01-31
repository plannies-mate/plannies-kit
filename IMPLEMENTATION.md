# Plannies Mate Implementation Guide

## Scraper Language Classification

| Language | Scraper file | Comments start with | echo command | import command |
| Ruby | scraper.rb | # | puts | Bundler.require |
| PHP | scraper.php | // | echo | require_once |
| Python | scraper.py | # | print | import |
| Perl | scraper.pl | # | print | use |
| Node.js | scraper.js | // | console.log | require |

## Repository Classification

### Placeholder Scrapers
- Contains ONLY:
  * `Bundler.require`
  * `puts` statements (or equivalent print commands)
- Checked ONLY in the main scraper file
- Excludes any other meaningful code

### Trivial Scrapers
- Less than 15 lines of code across ALL Ruby files
- Ignores comment and import lines
- Applies across entire repository, not just scraper file

### Active Scrapers
- Has a scraper file
- Not classified as placeholder
- Not classified as trivial
- 15 or more lines of code

## Word Extraction Strategy

### URL Extraction
- Scan content for HTTP/HTTPS URLs
- Reject GitHub and Morph.io URLs
- Remove duplicates

### Word Processing
- Remove scheme and hostname
- Extract alphanumeric sequences
- Reject:
  * Words ≤ 2 characters
  * Words in COMMON_WORDS list

## Output Files

### `log/scraper_analysis.js`
- Timestamp of generation
- Active scraper metadata
- Extracted unique words per repository

### `log/debug_analysis.json`
- Detailed repository analysis
- Metadata about processing
- Classification information

## Performance Considerations
- Efficient word extraction
- Minimal external command usage
- Clear, concise progress reporting

## Development Practices
- Methods under 20 lines
- Files under 200 lines
- Clear variable names
- Explicit error handling
- Comprehensive logging

## Smallest Useful Scraper
Currently `HuonValleyDA/scraper.rb` at 25 lines long


