#!/usr/bin/env ruby

require 'scraperwiki'
require 'mechanize'
require 'uri'
require 'date'

class BadData < Exception
end

agent = Mechanize.new

# Read in a page
WEBSITE_URI=URI('http://www.busselton.wa.gov.au')
WEBSITE_URI.path = '/Developing-Busselton/Public-Consultation'

page = agent.get(WEBSITE_URI.to_s)

# get the list of development applications
list = page.search('div.list-item-container')

list.each do |row|
  # most of the required information is contained in one string
  # inside the h2 element h2.list-item-title

  title = row.search('h2.list-item-title').inner_html.strip

  begin
    puts "Attempting '#{title}'"
    record = {}
    if title !~ /^DA/
      raise BadData, "Skipping #{title} because it is not a DA"
    end

    if title =~ /^DA(\d{2})\/(\d{4}) -? (.*) -?\s*Lot (\d+) \(Hse (\d+)\) (.*)/
      #               year    int      description   lot-number rest-of-address
      record['council_reference'] = "DA#{$1}/#{$2}"
      record['address']           = "#{$5} #{$6}, WA"
      record['lot_number']        = $4
      record['description']       = $3.gsub(/ -$/, '')
      record['info_url']          = row.search('a').attr("href").to_s
      record['comment_url']       = "mailto:city@busselton.wa.gov.au?subject=#{record['council_reference']}"
      record['date_scraped']      = Date.today.to_s

      on_notice_to_text           = row.search('p.applications-closing').inner_html.match(/Submissions closing on (.*)/)[1]
      record['on_notice_to']      = Date.parse(on_notice_to_text).iso8601
    end

    if record.empty?
      # maybe the information can be obtained from the info page
      inner_page = agent.get(row.search('a').attr('href').to_s)
 
      title = inner_page.search('head > title')
      if title.inner_html =~ /DA(\d{2})\/(\d{4})/
        record['council_reference'] = "DA#{$1}/#{$2}"
      else
        raise BadData, "Failed to find council reference number in second level page"
      end

      inner_page.search('strong').each do |element|
        element.text.gsub!('&nbsp;', ' ')

        if element.text.include?('PROPERTY:')
          if element.text =~ /Lots? (.+) \(Hse (?:NO)? ?(\d+)\) (.*)/i
            record['address'] = "#{$2} #{$3}, WA"
            record['lot_number'] = $1
          end
        elsif element.text =~ /PROPOSED DEVELOPMENT:\s*(.*)/
          record['description'] = $1.strip
        end

        begin
          record['on_notice_to'] = Date.parse(element.text).iso8601
        rescue ArgumentError; end
      end

      ['address', 'lot_number', 'description', 'on_notice_to'].each do |f|
        raise BadData, "Could not find #{f.gsub('_', ' ')} in second level page." unless record[f]
      end

      record['info_url']     = row.search('a').attr('href').to_s or raise BadData, "Could not find info url"
      record['comment_url']  = "mailto:city@busselton.wa.gov.au?subject=#{record['council_reference']}"
      record['date_scraped'] = Date.today.to_s
    end

    raise BadData, "Failed to match #{title} to any expression" if record.empty?

    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  rescue BadData
    # selector #main-content > div > div:nth-child(1) > p:nth-child(8) > strong:nth-child(3)
    # head > title
    $stderr.puts $!
  end
end
