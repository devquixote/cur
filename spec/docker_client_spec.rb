require_relative 'spec_helper'

module Cur
  describe DockerClient do
    # switch to STDOUT if needing to debug
    let(:log_path) { '/dev/null' }

    describe "#address" do
      it "should default to standard docker unix domain socket" do
        client = DockerClient.new
        expect(client.address).to eq("unix:///var/run/docker.sock")
      end

      it "should allow overriding of the protocol when the client is constructed" do
        client = DockerClient.new :protocol => 'http'
        expect(client.address).to eq("http:///var/run/docker.sock")
      end

      it "should allow overriding of the location when the client is constructed" do
        client = DockerClient.new :location => '127.0.0.1'
        expect(client.address).to eq("unix://127.0.0.1")
      end
    end

    describe "image operations" do
      let(:client) { DockerClient.new log_path: log_path }

      before { client.delete_image(image='busybox', force=true) rescue nil }

      it "should allow images to be pulled, listed, inspected and removed" do
        client.pull_image(image='busybox')

        image_tags = client.list_images.map(&:RepoTags).flatten
        expect(image_tags.include?("busybox:latest")).to be true

        busybox = client.inspect_image(image='busybox')
        expect(busybox.Id).to_not be_nil

        untagged = client.delete_image(image='busybox', force=true)
                         .detect{|delete| delete.Untagged}
                         .Untagged
        expect(untagged).to eq("busybox:latest")
      end
    end

    describe "#ping" do
      let(:client) { DockerClient.new log_path: log_path }

      it "should return true if it can connect to the docker daemon" do
        expect(client.ping).to be true
      end

      it "should return false if it cannot connect to the docker daemon" do
        expect(DockerClient.new(:protocol => 'http').ping).to be false
      end
    end

    describe "container operations" do
      let(:client) { DockerClient.new log_path: log_path }
      let(:container_def) do
        {
          Image: 'busybox',
          Hostname: 'curtest',
          Cmd: ['/bin/hostname'],
          Tty: true,
          AttachStdin: true,
          AttachStderr: true,
          Labels: {
            curtest: "true"
          },
        }
      end

      before do
        client.pull_image(image='busybox')
        client.list_containers.select{|c| c.Labels && c.Labels.curtest}.each do |container|
          client.delete_container(id=container.id, force=true) rescue nil
        end
      end

      it "should allow containers to be created, listed, inspected and deleted" do
        container = client.create_container(container_def)
        expect(container.Id).to_not be_empty

        container_meta = client.list_containers.detect{|c| c.Labels.curtest}
        expect(container_meta).to_not be_nil

        container = client.inspect_container(id=container.Id)
        expect(container).to_not be_nil

        client.delete_container(id=container.Id, force=true)
        expect{client.inspect_container(id=container.Id)}.to raise_error(DockerClient::APIError)
      end

      it "should allow for containers to be started, attached to and waited upon" do
        container = client.create_container(container_def)
        expect(client.start_container(id=container.Id)).to be true
        sleep(0.1)
        expect(client.attach_container(id=container.Id).Stream.strip).to eq("curtest")
        expect(client.wait_container(id=container.Id).StatusCode).to eq(0)
        expect(client.container_logs(id=container.Id).Stream).to_not be_empty
      end

      describe "long-running containers" do
        let!(:container) do
          client.create_container(container_def).tap do |container|
            client.start_container(id=container.Id)
          end
        end

        it "should allow for containers to be stopped" do
          expect(client.stop_container(container.Id)).to be true
          container_details = client.inspect_container(container.Id)
          expect(container_details.State.Running).to be false
        end

        it "should allow for containers to be killed" do
          expect(client.kill_container(container.Id, signal='SIGKILL')).to be true
          container_details = client.inspect_container(container.Id)
          expect(container_details.State.Running).to be false
        end
      end
    end
  end
end
