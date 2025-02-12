# frozen_string_literal: true

require "mechanize"

class MorphScraper
  MORPH_SCRAPER_LINK_PATTERN = %r{https://morph\.io/planningalerts-scrapers/([^"]+)}.freeze

  def fetch_authority_data(authority)
    @authority_data ||= {}
    @authority_data[authority] ||= fetch_data(authority)
  end

  private

  def scraper_in_use(authority_href)
    @scraper_in_use ||= {}
    @scraper_in_use[authority_href] ||=
      begin
        url = "https://www.planningalerts.org.au/#{authority_href}/under_the_hood"
        page = Mechanize.new.get(url)

        # Look for morph.io scraper link
        page.search("a").each do |link|
          # puts "LINK: #{link.text.inspect}, href: #{link['href'].inspect}"
          next unless link.text.include?("scraper")

          match = link["href"]&.match(MORPH_SCRAPER_LINK_PATTERN)
          next unless match

          scraper = match[1]
          puts "Found #{authority_href} uses scraper: #{scraper.inspect}" if ENV["DEBUG"]
          return scraper
        end
      rescue StandardError => e
        warn "Ignored: #{e} for #{url}" if ENV["DEBUG"]
        false
      end
    nil
  end

  def extract_applications_count(page, period)
    # Find the row with the specified period
    row = page.search("table > tbody > tr").find do |tr|
      cells = tr.search("td, th")
      next false if cells.size != 2

      second_cell_text = cells[1].text.strip.downcase
      second_cell_text == "in the last #{period}"
    end

    return nil unless row

    # Extract the number from the first cell, handling commas
    first_cell = row.search("td")[0]
    return nil unless first_cell

    first_cell.text.strip.gsub(",", "").to_i
  end

  def extract_warning(page)
    # Find paragraphs starting with the specific warning phrase
    page.search("p").each do |paragraph|
      text = paragraph.text.strip
      if text.start_with?("It looks like something might be wrong.")
        # If the text is exactly the warning phrase, return it
        return text if text == "It looks like something might be wrong."

        # Remove the initial phrase, remove extra whitespace, and remove " Why?"
        cleaned_text =
          text.sub(/^It looks like something might be wrong\.\s*/, "")
              .gsub(/\s+/, " ")
              .sub(/\s*Why\?$/, "")
              .sub("The last new application was received",
                   "Last application received")
              .strip
        return cleaned_text unless cleaned_text.empty?
      end
    end

    nil
  end

  def extract_population(page)
    # Try multiple population selectors
    population_selectors = [
      ".py-4.mt-8.text-xl.border-y.text-navy.border-light-grey2",
      ".text-xl.border-y"
    ]

    population_selectors.each do |selector|
      population_element = page.at(selector)
      next if population_element.nil?

      population_text = population_element.text.strip
      population = population_text[/(\d{1,3}(?:,\d{3})*)/]
      return population if population
    end

    nil
  end

  def fetch_data(authority)
    href = MorphStatus::AuthorityUrlResolver.get_href_for(authority)
    return {} unless href

    url = "https://www.planningalerts.org.au#{href}"
    page = Mechanize.new.get(url)
    result = {
      week: extract_applications_count(page, "week"),
      month: extract_applications_count(page, "month"),
      warning: extract_warning(page),
      population: extract_population(page)
    }
    result[:scraper] = scraper_in_use(href)
    result
  rescue Mechanize::ResponseCodeError => e
    {
      week: nil,
      month: nil,
      warning: "Unable to fetch data (#{e.response_code})",
      population: nil,
      scanner: nil
    }
  end
end
