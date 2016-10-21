#!/usr/bin/env ruby

require 'scraperwiki'
require 'mechanize'
require 'uri'
require 'rexml/document'

class CoBPlanningScraper

  # Error to raise when you can't find stuff.
  class BadData < Exception; end

  # URI of the generated XML document containing the advertised proposals for
  # comment
  DATA_URI=URI('http://www.busselton.wa.gov.au/externaldata/CoB_Advertised_DAs.xml')

  # The advertising document for public consultations
  WEBSITE_URI=URI('http://www.busselton.wa.gov.au/Developing-Busselton/Public-Consultation')

  # A template of the object that is ultimately recorded into the database.
  TEMPLATE_RECORD = {
    'council_reference' => nil,
    'address' => nil,
    'description' => nil,
    'info_url' => nil,
    'comment_url' => nil,
    'date_received' => nil,
    'on_notice_from' => nil,
    'on_notice_to' => nil,
  }

  def initialize()
    @agent = Mechanize.new

    @document = REXML::Document.new(open(DATA_URI.to_s))

    @page = @agent.get(WEBSITE_URI.to_s)

    # get the list of development applications
    @list = @page.search('div.list-item-container')

  end

  def find_info_url(council_reference)
    @list.each do |row|
      title = row.search('h2.list-item-title').inner_html.strip
      href = row.search('a').attr('href').to_s

      if title =~ /#{council_reference}/
        return href
      end

      if council_reference =~ /^AMD(\d{2})\/(\d{4})/
        scheme_number = $1.to_i
        amendment_number = $2.to_i

        if title =~ /local planning scheme no. ?#{scheme_number}.* amendment no. ?#{amendment_number}/i
          return href
        end
      end
    end

    raise BadData, "Could not find the page URL for #{council_reference}"
  end


  def process
    @document.elements.each('/planning/applications/application') do |application|
      begin
        record = TEMPLATE_RECORD.clone

        record.each do |key, value|
          begin
            record[key] = application.elements[key].text
          rescue NoMethodError
            record[key] = "No #{key} found in XML record"
            raise BadData, record[key]
          end
        end

        # override XML supplied values with scraped values
        record['info_url'] = find_info_url(record['council_reference'])
        record['comment_url'] = record['info_url']

        if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
          puts "Saving new record #{record['council_reference']} #{record['description']}"
          ScraperWiki.save_sqlite(['council_reference'], record)
        else
          puts "Skipping already saved record " + record['council_reference']
        end

      rescue BadData
        $stderr.puts $!
      end
    end
  end
end

CoBPlanningScraper.new.process
