require 'spec_helper'

module Cur
  describe Container do
    let(:docker) { DockerClient.new }
    let(:container) do
      Container.new(docker) do |container|
        container.name = 'cur.test'
        container.type = :task
        container.image = 'busybox'
        container.command = ['/bin/echo', 'test']
      end
    end

    describe "instantiation" do
      it "should not be allowed to be created without a configuration block" do
        expect{Container.new(docker)}.to raise_error("Must provide block to initialize container")
      end

      it "should not be modifiable after construction and initialization" do
        container = Container.new(docker) do |c|
          c.name = 'test'
          c.type = :service
          c.image = :busybox
        end
        expect{container.definition.type = 1}.to raise_error("can't modify frozen OpenStruct")
      end

      it "should not be instantiable with an invalid definition" do
        expect{Container.new(docker){}}.to raise_error("No name specified")
      end

      it "should start in a defined state" do
        container = Container.new(docker) do |c|
          c.name = 'test'
          c.type = :service
          c.image = :busybox
        end
        expect(container.state).to eq(:defined)
      end

      it "must be created with a docker client" do
        expect{Container.new(nil)}.to raise_error("Must provide docker client")
      end
    end

    describe "as a service" do
      let(:container) do
        Container.new(docker) do |c|
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
        Container.new(docker) do |c|
          c.name = 'test'
          c.type = :task
          c.image = :busybox
        end
      end

      specify("#service? should eq false") { expect(container.service?).to eq(false) }
      specify("#task? should eq true") { expect(container.task?).to eq(true) }
    end

    describe "#create!" do
      around(:each) do |example|
        begin
          container.create!
          example.run
        ensure
          container.destroy! rescue nil
        end
      end

      it "should capture the container's id" do
        expect(container.id).to_not be_nil
      end

      it "should create the docker container" do
        details = docker.inspect_container(container.id)
        expect(details.state.status).to eq("created")
      end

      it "should set the container's state to created" do
        expect(container.state).to eq(:created)
      end

      it "should raise exception if called multiple times" do
        expect{container.create!}.to raise_error("Container already created")
      end
    end

    describe "#destroy!" do
      before do
        container.create!
        @id = container.id
        container.destroy!
      end

      it "should destroy the container" do
        expect{docker.inspect_container(@id)}.to raise_error(Cur::DockerClient::APIError)
      end

      it "should remove the container id" do
        expect(container.id).to be_nil
      end

      it "should set the container's state to destroyed" do
        expect(container.state).to eq(:destroyed)
      end

      it "should raise error if container not created" do
        expect{container.destroy!}.to raise_error("Container not created")
      end
    end
  end
end
