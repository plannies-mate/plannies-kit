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

### `log/repos.yml`
 
- Created by download for future stages, does not include archived repos
- contains all the data used internally by download

```yaml
---
Brimbank_City_Council:
  description: Planning applications in Brimbank City Council, Victoria
  last_updated: '2024-07-18T05:10:54.712Z'
northern_territory:
  description: Northern Territory Development Applications
  last_updated: '2024-07-16T03:46:42.235Z'
act:
  description: ''
  last_updated: '2024-04-22T04:03:04.483Z'
```

### `log/analysis_results.yml`
- 
- Logs what analyse determined to assist in debugging
- not read by code, just humans
- is a dump of the internal @results data created and reported on within analyze

```yaml
---
   generated_at: "iso8601 time"
   stats:
     active: 4
     no_scraper: 3
     trivial: 2
     placeholder: 1  
   ignored_repos:
    "alerts":
      description: "github desc"
      reason: "no_scraper"
   active_repos:
     "multiple_icon":
       description: "github desc"
       words:
         - "word1"
         - "word2"
       urls:
         - "http://some.council.au/program/path/daQuery.do"
```

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
