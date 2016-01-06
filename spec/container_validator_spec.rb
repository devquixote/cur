require 'spec_helper'

module Cur
  describe ContainerValidator do
    let(:container) do
      OpenStruct.new name: 'test', type: :service, image: 'busybox'
    end
    let(:validator) { ContainerValidator.new container }

    describe "#validate!" do
      it "should raise error if no name specified" do
        container.name = nil
        expect{validator.validate!}.to raise_error("No name specified")
      end

      it "should raise error if name is empty" do
        container.name = ""
        expect{validator.validate!}.to raise_error("No name specified")
      end

      it "should raise error if no type specified" do
        container.type = nil
        expect{validator.validate!}.to raise_error("No container type specified")
      end

      it "should raise error if invalid type specified" do
        container.type = :foo
        expect{validator.validate!}.to raise_error("Invalid container type: foo")
      end

      it "should raise error if no image specified" do
        container.image = nil
        expect{validator.validate!}.to raise_error("No image specified")
      end

      it "should raise error if empty image specified" do
        container.image = ""
        expect{validator.validate!}.to raise_error("No image specified")
      end
    end
  end
end
