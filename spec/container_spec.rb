require 'spec_helper'

module Cur
  describe Container do
    describe "instantiation" do
      it "should not be allowed to be created without a configuration block" do
        expect{Container.new}.to raise_error("Must provide block to initialize container")
      end

      it "should not be modifiable after construction and initialization" do
        container = Container.new do |c|
          c.name = 'test'
          c.type = :service
          c.image = :busybox
        end
        expect{container.definition.type = 1}.to raise_error("can't modify frozen OpenStruct")
      end

      it "should not be instantiable with an invalid definition" do
        expect{Container.new{}}.to raise_error("No name specified")
      end

      it "should start in a defined state" do
        container = Container.new do |c|
          c.name = 'test'
          c.type = :service
          c.image = :busybox
        end
        expect(container.state).to eq(:defined)
      end
    end

    describe "as a service" do
      let(:container) do
        Container.new do |c|
          c.name = 'test'
          c.type = :service
          c.image = :busybox
        end
      end

      specify("#service? should eq true") { expect(container.service?).to eq(true) }
      specify("#task? should eq false") { expect(container.task?).to eq(false) }
    end

    describe "as a task" do
      let(:container) do
        Container.new do |c|
          c.name = 'test'
          c.type = :task
          c.image = :busybox
        end
      end

      specify("#service? should eq false") { expect(container.service?).to eq(false) }
      specify("#task? should eq true") { expect(container.task?).to eq(true) }
    end
  end
end
