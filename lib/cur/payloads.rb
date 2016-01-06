require 'json'
require 'ostruct'
require 'stringio'
require_relative 'inflections'

module Cur
  module Payloads
    include Inflections

    def json_to_dto(json)
      doc_to_dto(JSON.parse(json))
    end

    def multi_json_to_dto(json)
      # dirty deeds, done dirt cheap
      lines = StringIO.new(json).readlines.map(&:strip)
      lines = lines.map(&split_objs)
      lines = lines.flatten
      lines = lines.map(&massage_lines)
      lines = lines.compact
      lines = lines.map(&to_dtos)
    end

    def dto_to_json(dto)
      JSON.dump(dto_to_doc(dto))
    end

    def doc_to_dto(doc)
      if doc.kind_of? Array
        doc.map{|e| doc_to_dto(e)}
      elsif doc.kind_of? Hash
        underscored_doc = doc.keys.inject({}) do |new, key|
          new[underscore(key)] = doc[key]; new
        end
        dto = OpenStruct.new(underscored_doc)
        doc.each do |k, v|
          dto.send("#{underscore(k)}=", doc_to_dto(v)) if v.kind_of? Hash
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
        c_attr = camelize(attr).to_sym
        doc[c_attr] = dto.send(attr)
        doc[c_attr] = dto_to_doc(doc[c_attr]) if doc[c_attr].kind_of? OpenStruct
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
        line
      end
    end
  end
end
