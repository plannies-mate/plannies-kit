# Plannies Mate Implementation Guide

### Passive lines of code
Based on language detected - see "Scraper Language Classification" in SPECS.md
- Passive lines of code are defined as
  * Lines starting with "Comments start with", "echo command" or "import command" from the language table
  * Blank lines

### Trivial Scrapers
- is not detected as placeholder scraper
- Less than 15 lines that are not passive in total across all the files

### Placeholder Scrapers
- The scraper file only contains passive lines

### Active Scrapers
- Has a scraper file
- Not classified as placeholder or trivial

## STATUS Files

### `log/rpos.json`
- Created by download for future stages

### `log/debug_analysis.yml`
- Logs what analyse determined to assist in debugging
- not read by code, just humans
  - Detailed repository analysis
  - Metadata about processing
  - Classification information

## Performance Considerations
- Efficient word extraction
- Minimal external command usage

## Development Practices
- Clear, concise progress reporting
- Methods under 20 lines
- Files under 200 lines
- Clear variable names
- Explicit error handling (Fail fast)
- Sufficient logging
- Tests are informative when they fail, not just asserting a boolean condition

