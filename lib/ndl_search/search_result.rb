#-*- coding:utf-8 -*-
class NDLSearch::SearchResult
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

module NDLSearch::Item
  def detail
    ::NDLSearch::RdfItem.new(open("#{self.link}.rdf").read)
  end
end
