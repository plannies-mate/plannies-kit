# frozen_string_literal: true

require "mechanize"

module Protection
  class AuthorityUrlResolver
    AuthorityRecord = Struct.new(:id, :url, :name, :scraper, keyword_init: true)

    def self.authorities_list
      @authorities_list ||=
        begin
          agent = Mechanize.new
          page = agent.get("https://www.planningalerts.org.au/authorities")

          # Store links with their text
          result = page.links
                       .select { |link| link.href.start_with?("https://www.planningalerts.org.au/authorities/") }
                       .map do |link|
            id = link.href.sub("https://www.planningalerts.org.au/authorities/", "")&.to_sym
            record = AuthorityRecord.new(
              id: id,
              url: link.href,
              name: link.text.strip
            )
            puts "AUTHORITY RECORD: #{record.to_h.inspect}" if ENV["DEBUG"]
            record
          end
                       .sort_by { |auth| auth[:id] }
                       .uniq { |auth| auth[:id] }

          puts "AUTHORITY DETAILS: #{result.to_yaml}" if ENV["DEBUG"]
          result
        end
    end

    def self.get_authority_details
      @authority_details ||=
        begin
          result = {}
          authorities_list.each do |record|
            result[record[:id]] = record
          end
          result
        end
    end

    def self.get_authority_detail(id)
      get_authority_details[id]
    end

    def self.authority_ids
      get_authority_details.keys
    end

    def self.selected_authorities
      if ENV["AUTHORITIES"]
        authorities = ENV["AUTHORITIES"].split(",").map(&:strip).map(&:to_sym)
        invalid = authorities - authority_ids
        raise "Invalid authorities specified: #{invalid.join(', ')}" unless invalid.empty?

        authorities
      else
        authority_ids
      end
    end
  end
end
