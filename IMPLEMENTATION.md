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
- Automatic weekly repository refresh mechanism
    * repos.yml is automatically invalidated after 1 week
    * Running script/process will trigger a full repository re-download
    * Ensures repository data stays current without manual intervention

## Development Practices

- Clear, concise progress reporting
- Methods under 20 lines
- Files under 200 lines
- Clear variable names
- Explicit error handling (Fail fast)
- Sufficient logging
- Tests are informative when they fail, not just asserting a boolean condition

# Generated Config files

Terminology:
* `multi repo` is any repo whose name starts with the string 'multiple' and then a dash (-) or underscore (_).

## `config/authorities.yml`

Run `bin/rake refresh:authorities [FORCE=1]` to scrape the planningalerts.org.au site and produce the following file if
it is stale (more than 1 week
old) OR FORCE is set.

The key is referred to as `short_name` and is a string

```yaml
wyong:
  # From initial index page
  :long_name: Central Coast Council
  :state: NSW
  :status_url: https://www.planningalerts.org.au/authorities/wyong
  # From authority name to status page
  :last_week: 15
  :last_month: 110
  :median_pw: 11
  :warning:
  # Working is true if last_month is not zero and no warning
  :working: true
  # From "Look under the Hood" link to page:
  # From "Watch the scraper" link
  # Validate it is the same basename as "Fork the scraper on Github" link
  #:morph_url is https://morph.io/planningalerts-scrapers/#{scraper}
  # github_url is https://github.com/planningalerts-scrapers/#{scraper}
  :scraper: multiple_epathway_scraper
```

## `config/repos.yml`

Run `bin/rake refresh:repos [FORCE=1]` to check the repositories on github.com if the file is stale (more than 1 week
old) OR FORCE is set.
It

1. refreshes the repos directory
2. produces the following file
3. Calls the `cleanup:repos` task (which removes unnecessary content)
4. The scrpaer_url is the biggest url found in the scraper file

```yaml
multiple_epathway_scraper:
  description: the description on github
  last_updated: '2024-12-31T01:02:03Z'
  # the language is simply the extension the `scraper.*` file has
  language: rb
  scraper_url: 'https://the.url.domain/path/from/scraper.rb?and=any+query'
```

## `config/authority_repos_overrides.yml`

The entries of this file is copied into the authority_repos below and then the remaining entries added as described
below. The format is the same as below.

## `config/authority_repos.yml`

Run `bin/rake refresh:authority_repos [FORCE=1]` to refresh this table of links between authorities (from
planningalerts.org.au) and reports. the additional authority_label is required for `multiple_*` repos and is derived
from the authorities file.

Strategy:

1. Look through the open github issues - looking upo the issue's name as authorities.long_name and the basename of
   "Scraper (Morph)" to determine the scraper.
2. Do search for issues with the authorites.long_name (enclosed in double quotes). Where all the issues in the first
   page have the same scraper url, then use that.
3. For multi repos, examine the authorities.rb file and use the labels and the urls in that where they match an authority
   that uses that scraper
    * any that don't match are listed in the `config/unused_authority_labels.yml` file
4. For non-multi repos Where there is a authorities.short_name that matches the scraper name, add that
   to the mapping.

```
authority.shortname => {
  scraper: 'multiple_epathway_scraper'
  authority_label: key from authorities file.to_s (for multis)
  scraper_url: https://the.url.used/by/the/scraper/to/get/data
}
```

## `log/unused_authority_labels.yml`

Unused authority_labels are recorded in this file as an array of the following hash:

* scraper
* authority_label
* scraper_url

## `log/unused_scrapers.yml`

Unused scrapers are recorded in this file as an array of scraper names.
These will be considered for archiving if they are not recent.

## `log/url_protections.yml`

This file contains a list of scraper_urls mapped to the details determined about the url, including: 
* hostname_valid: true
* 

```yaml
bogan:

```