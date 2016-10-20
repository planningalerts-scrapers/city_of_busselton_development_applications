#!/usr/bin/env ruby

require 'scraperwiki'
require 'uri'
require 'rexml/document'
require 'logger'

DATA_URI=URI('http://www.busselton.wa.gov.au/externaldata/CoB_Advertised_DAs.xml')
WEBSITE_URI=URI('http://www.busselton.wa.gov.au/Developing-Busselton/Public-Consultation')

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

@logger = Logger.new(STDOUT)

@document = REXML::Document.new(open(DATA_URI.to_s))

@document.elements.each('/planning/applications/application') do |application|
  record = TEMPLATE_RECORD.clone
  record.each do |key, value|
    record[key] = application.elements[key].text
  end

  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    @logger.info "Saving new record #{record['council_reference']} #{record['description']}"
    ScraperWiki.save_sqlite(['council_reference'], record)
  else
    @logger.info "Skipping already saved record " + record['council_reference']
  end
end
