#-*- coding:utf-8 -*-

class NDLSearch::NDLSearch
  attr_accessor :feed

  API_PATH = "http://iss.ndl.go.jp/api/opensearch"

  ::RSS::Rss::Channel.install_text_element("openSearch:totalResults", "http://a9.com/-/spec/opensearchrss/1.0/", "?", "totalResults", :text, "openSearch:totalResults")
  ::RSS::BaseListener.install_get_text_element("http://a9.com/-/spec/opensearchrss/1.0/", "totalResults", "totalResults=")

  def initialize
    @feed = nil
  end

  def format_query(query)
    URI.escape(query.to_s.gsub('　',' '))
  end

  def search(query, options = {})
    options = {:dpid => 'iss-ndl-opac', :item => 'any', :idx => 1, :per_page => 10, :sort=>'df'}.merge(options)
    startrecord = options[:idx].to_i
    if startrecord == 0
      startrecord = 1
    end

    url = "#{API_PATH}?dpid=#{options[:dpid]}&#{options[:item]}=#{format_query(query)}&cnt=#{options[:per_page]}&idx=#{startrecord}&sort=#{options[:sort]}"

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

