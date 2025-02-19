# frozen_string_literal: true

require 'open3'

class DictionaryChecker
  COMMON_WORDS = %w[
    application applications base_url capybara city com council current data date
    development developments edu false find format gov http httparty https
    index info_url json list mechanize multiple nokogiri nsw null org
    page plan planning plans qld query regional root_url rspec rubygems
    scraper scrapers scraperwiki search selenium-webdriver shire status tas true type
    undefined vic view www
  ].freeze

  def initialize
    @known_words = Set.new(COMMON_WORDS)
    @unknown_words = Set.new
    check_aspell_installed
  end

  attr_reader :known_words, :unknown_words

  def known?(word)
    key = word.downcase
    return true if word.match(/^\d+$/)
    return false if word.match(/\d/)
    return true if @known_words.include?(key)
    return false if @unknown_words.include?(key)

    if HTMLFilter.html_token?(key)
      @known_words.add(key)
      return true
    end

    Open3.popen3('aspell list') do |stdin, stdout, stderr, _wait_thread|
      stdin.puts(word)
      stdin.close

      result = stdout.read.strip

      if result.empty?
        @known_words.add(key)
        return true
      end

      parts = result.split(/\s+/)
      unless parts.all? { |part| word.include?(part) }
        raise "Aspell returned invalid parts for word '#{word}': '#{result}', stderr: #{stderr.read}"
      end

      @unknown_words.add(key)
      false
    end
  end

  private

  def check_aspell_installed
    _, status = Open3.capture2e('which aspell')
    raise "Aspell is not installed. Please install aspell first." unless status.success?
  end
end
