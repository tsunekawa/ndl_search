#-*- coding:utf-8 -*-

require 'rest-client'
require 'uri'
require 'nokogiri'
require 'facets/kernel'
require 'rss'

module NDLSearch
  VERSION  = File.open(File.join(File.dirname(__FILE__), %w{ .. VERSION })).read
  API_PATH = "http://iss.ndl.go.jp/api/opensearch"

  ::RSS::Rss::Channel.install_text_element("openSearch:totalResults", "http://a9.com/-/spec/opensearchrss/1.0/", "?", "totalResults", :text, "openSearch:totalResults")
  ::RSS::BaseListener.install_get_text_element("http://a9.com/-/spec/opensearchrss/1.0/", "totalResults", "totalResults=")

  class NDLSearch
    attr_accessor :feed

    def initialize
      @feed = nil
    end

    def format_query(query)
      URI.escape(query.to_s.gsub('　',' '))
    end

    def search(query, options = {})
      options = {:dpid => 'iss-ndl-opac', :item => 'any', :idx => 1, :per_page => 10}.merge(options)
      startrecord = options[:idx].to_i
      if startrecord == 0
	startrecord = 1
      end

      url = "http://iss.ndl.go.jp/api/opensearch?dpid=#{options[:dpid]}&#{options[:item]}=#{format_query(query)}&cnt=#{options[:per_page]}&idx=#{startrecord}"

      feed = RSS::Parser.parse(url, false)
      ::NDLSearch::SearchResult.new(feed)
    end

    def construct_query(query)
      url = API_PATH+"?"+create_params(query)
      URI.escape(url)
    end

    def create_params(hash)
      hash.to_a.map{|item| "#{item[0]}=#{item[1]}"}.join("&")
    end
  end

  class SearchResult
    attr_accessor :feed

    def initialize(feed)
      @feed = feed
    end

    def items
      @items ||= feed.channel.items.map do |item|
	item.extend ::NDLSearch::Item
      end
    end
  end

  module Item
    def detail
      ::NDLSearch::RdfItem.new(open("#{self.link}.rdf").read)
    end
  end

  class RdfItem
    attr_accessor :doc

    def initialize(rdf)
      @doc = rdf.instance_of?(String) ? ::Nokogiri::XML.parse(rdf) : rdf
    end

    def title
      @title ||= {
	:manifestation => doc.xpath('//dc:title/rdf:Description/rdf:value').collect(&:content).join(' '),
	:transcription => doc.xpath('//dc:title/rdf:Description/dcndl:transcription').collect(&:content).join(' '),
	:alternative => doc.at('//dcndl:alternative/rdf:Description/rdf:value').try(:content),
	:alternative_transcription => doc.at('//dcndl:alternative/rdf:Description/dcndl:transcription').try(:content)
      }
    end

    def permalink
      @guid ||=  doc.at('guid').text
    end

    def language
      @language  ||= doc.at('//dcterms:language[@rdf:datatype="http://purl.org/dc/terms/ISO639-2"]')
                        .try(:content)
		        .try(:downcase)
    end

    def ndc
      ndc = doc.xpath('dc:subject[@xsi:type="dcndl:NDC9"]').text
      ndc = doc.xpath('dc:subject[@xsi:type="dcndl:NDC"]').text if ndc=="" or ndc.nil?
      if ndc=="" or ndc.nil? then
        item = doc.xpath('//dcterms:subject/@rdf:resource').text.try(:find) {|e| e=~ /ndc9/ }
        ndc  = item.nil? ? nil: item.scan(/ndc9\/(.*)/).first.try(:first)
      end

      @ndc ||= ndc
    end
  end
end
