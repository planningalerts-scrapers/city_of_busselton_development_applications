#!/usr/bin/env ruby

require 'scraperwiki'
require 'mechanize'
require 'uri'
require 'date'

agent = Mechanize.new

# Read in a page
WEBSITE_URI=URI('http://www.busselton.wa.gov.au/Developing-Busselton/Public-Consultation')
page = agent.get(WEBSITE_URI.to_s)

# get the list of development applications
list = page.search('div.list-item-container')

list.each do |row|
  title = row.search('h2.list-item-title').inner_html
  if title =~ /DA(\d{2})\/(\d{4}) -? (.*) -?\s*Lot (\d+) (.*)/
    record = {}
    record['council_reference'] = "DA#{$1}/#{$2}"
    record['address']           = "Lot #{$4} #{$5}, WA"
    record['description']       = $3.gsub(/ -$/, '')
    record['info_url']          = row.search('a').attr("href").to_s
    record['comment_url']       = "mailto:city@busselton.wa.gov.au?subject=#{record['council_reference']}"
    record['date_scraped']      = Date.today.to_s

    on_notice_to_text           = row.search('p.applications-closing').inner_html.match(/Submissions closing on (.*)/)[1]
    record['on_notice_to']      = Date.parse(on_notice_to_text).iso8601

    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  else
    # if it doesn't match the regexp above it's probably not a DA
    # hopefully it's not just a strange string form..
    $stderr.puts "Skipping #{title.strip.chomp.strip.chomp} as it is not a DA"
  end
end
