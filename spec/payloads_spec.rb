require_relative 'spec_helper'

module Cur
  describe Payloads do
    let (:dependent) { Object.new.extend Payloads }

    let(:json) do
      <<-JSON
        {
          "scalar": "scalar",
          "array": [1, 2, 3],
          "nested": {
            "nested_scalar": "nested_scalar",
            "nested_array": [10, 11, 12]
          }
        }
      JSON
    end

    let(:multi_json) do
      <<-JSON
        {"status": "Pulling..."}
        {"status": "Pulling..."}{"status": "Pulling..."}
      JSON
    end

    let(:json_array) { "[1, 2, 3]" }

    let (:doc) do
      {
        scalar: "scalar",
        array: [1, 2, 3],
        nested: {
          nested_scalar: "nested_scalar",
          nested_array: [10, 11, 12]
        }
      }
    end

    let (:dto) do
      OpenStruct.new.tap do |dto|
        dto.scalar = "scalar"
        dto.array = [1, 2, 3]
        dto.nested = OpenStruct.new({
          nested_scalar: "nested_scalar",
          nested_array: [10, 11, 12]
        })
      end
    end

    describe "#json_to_dto" do
      it "should convert json to a DTO object" do
        expect(dependent.json_to_dto(json)).to eq(dto)
      end

      it "should handle json arrays at top level" do
        expect(dependent.json_to_dto(json_array)).to eq([1, 2, 3])
      end
    end

    describe "#multi_json_to_dto" do
      it "should convert multi json objects to an array of DTO objects" do
        dtos = dependent.multi_json_to_dto(multi_json)
        expect(dtos.size).to eq(3)
        dtos.each do |dto|
          expect(dto.status).to eq("Pulling...")
        end
      end
    end

    describe "#dto_to_json" do
      it "should convert DTO object to json" do
        expect(JSON.parse(dependent.dto_to_json(dto))).to eq(JSON.parse(json))
      end
    end

    describe "#doc_to_dto" do
      it "should convert hash document to DTO object" do
        expect(dependent.doc_to_dto(doc)).to eq(dto)
      end
    end

    describe "#dto_to_doc" do
      it "should convert DTO object to hash doc" do
        expect(dependent.dto_to_doc(dto)).to eq(doc)
      end
    end
  end
end
