# frozen_string_literal: true

require "mechanize"

module Protection
  class AuthorityUrlResolver
    def self.authority_hrefs
      @authority_hrefs ||=
        begin
          agent = Mechanize.new
          page = agent.get("https://www.planningalerts.org.au/authorities")

          # Store all links directly
          result = page.links
                       .map(&:href)
                       .map(&:to_s)
                       .map { |href| href.sub("https://www.planningalerts.org.au", "") }
                       .select { |href| href.start_with?("/authorities/") }
                       .sort
                       .uniq
          puts "AUTHORITY HREFS: #{result.to_yaml}" if ENV["DEBUG"]
          result
        end
    end

    def self.all_authorities
      authority_hrefs.map { |href| href.sub("/authorities/", "")}
    end

    def self.selected_authorities
      if ENV["AUTHORITIES"]
        authorities = ENV["AUTHORITIES"].split(",").map(&:strip).map(&:to_sym)
        invalid = authorities - all_authorities
        raise "Invalid authorities specified: #{invalid.join(', ')}" unless invalid.empty?

        authorities
      else
        all_authorities
      end
    end
  end
end
