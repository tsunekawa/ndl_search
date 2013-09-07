#-*- coding:utf-8 -*-

require 'rest-client'
require 'uri'
require 'nokogiri'
require 'facets/kernel'
require 'rss'

module NDLSearch
  VERSION  = File.open(File.join(File.dirname(__FILE__), %w{ .. VERSION })).read
end

require_relative './ndl_search/ndl_search.rb'
require_relative './ndl_search/search_result.rb'
require_relative './ndl_search/rdf_item.rb'
