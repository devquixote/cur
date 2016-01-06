require_relative 'spec_helper'

module Cur
  describe Inflections do
    include Inflections

    describe "#underscore" do
      it "should convert camel-cased terms to underscored terms" do
        words = ["OneCoolThing", "oneCoolThing", :OneCoolThing, :oneCoolThing]
        words.each do |word|
          expect(underscore(word)).to eq("one_cool_thing")
        end
      end
    end

    describe "#camelize" do
      it "should convert underscored terms to camel-cased terms" do
        words = ["one_cool_thing", "_one_Cool_thing_", :one_cool_thing]
        words.each do |word|
          expect(camelize(word)).to eq("OneCoolThing")
        end
      end
    end
  end
end
