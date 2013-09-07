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

    def creators
      @creators ||= doc.xpath('//dcterms:creator/foaf:Agent').inject(Array.new) do |array, creator|
	array << {
	  :full_name => creator.at('./foaf:name').content,
	  :full_name_transcription => creator.at('./dcndl:transcription').try(:content),
	  :agent_identifier => creator.attributes["about"].try(:content)
	}
	array
      end
    end

    def subjects
      @subjects ||= doc.xpath('//dcterms:subject/rdf:Description').inject(Array.new) do |array,subject|
	array << {
	  :term => subject.at('./rdf:value').content,
	  #:url => subject.attribute('about').try(:content)
        }
	array
      end
    end

    def classifications
      @classifications ||= doc.xpath('//dcterms:subject[@rdf:resource]').inject(Array.new) do |array, classification|
	array << {
	  :url => classification.attributes["resource"].content
	}
        array
      end
    end

    def language
      @language  ||= doc.at('//dcterms:language[@rdf:datatype="http://purl.org/dc/terms/ISO639-2"]')
                        .try(:content)
		        .try(:downcase)
    end

    def publishers
      @publishers ||= doc.xpath('//dcterms:publisher/foaf:Agent').inject(Array.new) do |publishers, publisher|
	publishers << {
	  :full_name => publisher.at('./foaf:name').content,
	  :full_name_transcription => publisher.at('./dcndl:transcription').try(:content),
	  :agent_identifier => publisher.attributes["about"].try(:content)
	}
	publishers
      end
    end

    def extent
      if @extent.blank? then
        extent = doc.at('//dcterms:extent').try(:content)
        value = {:start_page => nil, :end_page => nil, :height => nil}
	if extent
	  extent = extent.split(';')
	  page = extent[0].try(:strip)
	  if page =~ /\d+p/
	    value[:start_page] = 1
	    value[:end_page] = page.to_i
	  end
	  height = extent[1].try(:strip)
	  if height =~ /\d+cm/
	    value[:height] = height.to_i
	  end
	end
	@extent = value
      else
	@extent
      end
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
