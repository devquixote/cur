require 'json'
require 'ostruct'
require 'stringio'

module Cur
  module Payloads
    def json_to_dto(json)
      doc_to_dto(JSON.parse(json))
    end

    def multi_json_to_dto(json)
      # dirty deeds, done dirt cheap
      StringIO.new(json).readlines.map(&:strip)
                                  .map(&split_objs)
                                  .flatten
                                  .map(&massage_lines)
                                  .compact
                                  .map(&to_dtos)
    end

    def dto_to_json(dto)
      JSON.dump(dto_to_doc(dto))
    end

    def doc_to_dto(doc)
      if doc.kind_of? Array
        doc.map{|e| doc_to_dto(e)}
      elsif doc.kind_of? Hash
        dto = OpenStruct.new(doc)
        doc.each do |k, v|
          dto.send("#{k}=", doc_to_dto(v)) if v.kind_of? Hash
        end
        dto
      else
        doc
      end
    end

    def dto_to_doc(dto)
      doc = Hash.new
      attrs = (dto.methods - OpenStruct.instance_methods).reject{|m| m.to_s.match /\=/}
      attrs.each do |attr|
        doc[attr] = dto.send(attr)
        doc[attr] = dto_to_doc(doc[attr]) if doc[attr].kind_of? OpenStruct
      end
      doc
    end

    private 

    def to_dtos
      lambda {|line| json_to_dto(line)}
    end

    def split_objs
      lambda {|line| line.split("}{")}
    end

    def massage_lines
      lambda do |line|
        line = "{#{line}" unless line.match /^{/
        line = "#{line}}" unless line.match /}[\n]?$/
      end
    end
  end
end
