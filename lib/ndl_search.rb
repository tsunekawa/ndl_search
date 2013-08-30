#-*- coding:utf-8 -*-

require "rexml/document"
require 'rest-client'
require 'uri'
require 'nokogiri'

module NDLSearch
  VERSION  = File.open(File.join(File.dirname(__FILE__), %w{ .. VERSION })).read
  API_PATH = "http://iss.ndl.go.jp/api/opensearch"

  class NDLSearch
    attr_accessor :feed

    def initialize
      @feed = nil
    end

    def search(query)
      source = RestClient.get(construct_query(query))
      ::NDLSearch::SearchResult.new(::Nokogiri::XML.parse(source))
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
    attr_accessor :resource

    def initialize(xml)
      @resource = xml
    end

    def item
      items.first
    end

    def items
      @items ||= @resource.xpath('/rss/channel/item').map{|item| ::NDLSearch::Item.new(item) }
    end
  end

  class Item
    attr_accessor :resource

    def initialize(xml)
      xml = ::Nokogiri::XML.parse(xml) if xml.instance_of? String
      @resource = xml
    end

    def title
      @title ||= @resource.at('title').text
    end

    def permalink
      @guid ||=  @resource.at('guid').text
    end

    def ndc
      ndc = @resource.xpath('dc:subject[@xsi:type="dcndl:NDC9"]').text
      ndc = @resource.xpath('dc:subject[@xsi:type="dcndl:NDC"]').text if ndc=="" or ndc.nil?
      if ndc=="" or ndc.nil? then
        item = @resource.xpath('//dcterms:subject/@rdf:resource').text.try(:find) {|e| e=~ /ndc9/ }
        ndc  = item.nil? ? nil: item.scan(/ndc9\/(.*)/).first.try(:first)
      end

      @ndc ||= ndc
    end
  end
end
