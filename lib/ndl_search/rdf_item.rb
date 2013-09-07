#-*- coding:utf-8 -*-

class NDLSearch::RdfItem
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

  def identifiers
    @identifiers ||= doc.xpath("//dcterms:identifier").inject(Hash.new) do |hsh, id|
      hsh[id.attributes["datatype"].value.split("/").last] = id.content.to_s
      hsh
    end
  end

  def isbn
    @isbn ||= identifiers["ISBN"]
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
