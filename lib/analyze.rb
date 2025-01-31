#!/usr/bin/env ruby

require 'bundler/setup'
Bundler.require

require 'uri'
require 'fileutils'
require 'time'
require 'set'

require_relative 'process_base'

class ScraperAnalyzer < ProcessBase
  SCRAPER_PATTERNS = [
    'scraper.rb',
    'scraper.php',
    'scraper.py',
    'scraper.pl',
    'scraper.js'
  ]

  COMMON_WORDS = Set.new([
                           'scraper', 'scrapers',
                           'http', 'https', 'www', 'com', 'org', 'gov', 'edu',
                           'search', 'query', 'find', 'page', 'data',
                           'format', 'type', 'view', 'index', 'list',
                           'application', 'applications',
                           'development', 'developments',
                           'planning', 'plan', 'plans',
                           'council', 'shire', 'city',
                           'current', 'date', 'status',
                           'true', 'false', 'null', 'undefined'
                         ])

  def initialize
    abort "Directory #{REPOS_DIR} does not exist!" unless Dir.exist?(REPOS_DIR)
    load_descriptions
    @broken_scrapers = []
    @no_scraper_repos = []

    # Initialize aspell
    @speller = IO.popen("aspell -a", "r+")
    @speller.readline # Read first line to clear aspell header
  end

  # Rest of the code remains the same as the SEARCH block
