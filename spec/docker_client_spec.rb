require_relative 'spec_helper'

module Cur
  describe DockerClient do
    # switch to STDOUT if needing to debug
    let(:log_path) { '/dev/null' }

    describe "#address" do
      it "should default to standard docker unix domain socket" do
        docker = DockerClient.new
        expect(docker.address).to eq("unix:///var/run/docker.sock")
      end

      it "should allow overriding of the protocol when the docker is constructed" do
        docker = DockerClient.new :protocol => 'http'
        expect(docker.address).to eq("http:///var/run/docker.sock")
      end

      it "should allow overriding of the location when the docker is constructed" do
        docker = DockerClient.new :location => '127.0.0.1'
        expect(docker.address).to eq("unix://127.0.0.1")
      end
    end

    describe "image operations" do
      let(:docker) { DockerClient.new log_path: log_path }

      before { docker.delete_image(image='busybox', force=true) rescue nil }

      it "should allow images to be pulled, listed, inspected and removed" do
        docker.pull_image(image='busybox')

        image_tags = docker.list_images.map(&:repo_tags).flatten
        expect(image_tags.include?("busybox:latest")).to be true

        busybox = docker.inspect_image(image='busybox')
        expect(busybox.id).to_not be_nil

        untagged = docker.delete_image(image='busybox', force=true)
                         .detect{|delete| delete.untagged}
                         .untagged
        expect(untagged).to eq("busybox:latest")
      end
    end

    describe "#ping" do
      let(:docker) { DockerClient.new log_path: log_path }

      it "should return true if it can connect to the docker daemon" do
        expect(docker.ping).to be true
      end

      it "should return false if it cannot connect to the docker daemon" do
        expect(DockerClient.new(:protocol => 'http').ping).to be false
      end
    end

    describe "container operations" do
      let(:docker) { DockerClient.new log_path: log_path }
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
        docker.pull_image(image='busybox')
        docker.list_containers.select{|c| c.Labels && c.Labels.curtest}.each do |container|
          docker.delete_container(id=container.id, force=true) rescue nil
        end
      end

      it "should allow containers to be created, listed, inspected and deleted" do
        container = docker.create_container('curtest', container_def)
        expect(container.id).to_not be_empty

        container_meta = docker.list_containers.detect{|c| c.labels.curtest}
        expect(container_meta).to_not be_nil

        container = docker.inspect_container(id=container.id)
        expect(container).to_not be_nil

        docker.delete_container(id=container.id, force=true)
        expect{docker.inspect_container(id=container.id)}.to raise_error(DockerClient::APIError)
      end

      it "should allow for containers to be started, attached to and waited upon" do
        container = docker.create_container('curtest', container_def)
        expect(docker.start_container(id=container.id)).to be true
        sleep(0.1)
        expect(docker.attach_container(id=container.id).stream.strip).to eq("curtest")
        expect(docker.wait_container(id=container.id).status_code).to eq(0)
        expect(docker.container_logs(id=container.id).stream).to_not be_empty
        docker.stop_container(container.id)
        docker.delete_container(container.id)
      end

      describe "long-running containers" do
        let!(:container) do
          docker.create_container('curtest', container_def).tap do |container|
            docker.start_container(id=container.id)
          end
        end
        after(:each) do
          docker.stop_container(container.id)
          docker.delete_container(container.id)
        end

        it "should allow for containers to be stopped" do
          expect(docker.stop_container(container.id)).to be true
          container_details = docker.inspect_container(container.id)
          expect(container_details.state.running).to be false
        end

        it "should allow for containers to be killed" do
          expect(docker.kill_container(container.id, signal='SIGKILL')).to be true
          container_details = docker.inspect_container(container.id)
          expect(container_details.state.running).to be false
        end
      end
    end

    describe "for various runtime scenarios" do
      let(:docker) { DockerClient.new }
      before do
        docker.delete_image(image='busybox', force=true) rescue nil
        File.delete('curtest') if File.exists?('curtest')
      end

      it "should be able to pull an image, create a container from it and start the container with the current working directory mounted in the container" do
        details = {
          Image: 'busybox',
          HostConfig: {
            Binds: ["#{File.expand_path('.')}:/cur"]
          },
          Cmd: ['/bin/touch', '/cur/curtest']
        }

        docker.pull_image(image='busybox')
        container = docker.create_container('curtest', details)
        docker.start_container(id=container.id)
        docker.stop_container(id=container.id)
        docker.delete_container(id=container.id)
        docker.delete_image(image='busybox', force=true)

        expect(File.exists?('curtest')).to be true
        File.delete('curtest')
      end

      it "should be able to link to another container and communicate via exposed ports" do
        server_details = {
          Image: 'busybox',
          Cmd: ['/bin/nc', '-l', '-p', '8080', '-e', '/bin/hostname']
        }
        client_details = {
          Image: 'busybox',
          Cmd: ['/bin/nc', 'server', '8080'],
          HostConfig: {
            Links: ["curtest.server:server"]
          }
        }

        # bring up containers
        docker.pull_image(image='busybox')
        server = docker.create_container('curtest.server', server_details)
        client = docker.create_container('curtest.client', client_details)
        docker.start_container(id=server.id)
        docker.start_container(id=client.id)

        # bring down containers
        docker.stop_container(id=client.id)
        client_details = docker.inspect_container(id=client.id)
        docker.delete_container(id=client.id)
        docker.stop_container(id=server.id)
        docker.delete_container(id=server.id)

        # assertions
        expect(client_details.state.status).to eq('exited')
        expect(client_details.state.exit_code).to eq(0)
      end

      it "should be able to be observed for connectability outside of the container" do
        daemon_details = {
          Image: 'busybox',
          Cmd: ['/bin/nc', '-l', '-p', '8080'],
          ExposedPorts: {
            "8080/tcp" => {}
          }
        }
        observer_details = {
          Image: 'busybox',
          HostConfig: {
            Links: ['curtest.daemon:daemon']
          },
          Cmd: ["/bin/sh", "-c", "/bin/echo info | /bin/nc daemon 8080"]
        }

        # bring up containers
        docker.pull_image(image='busybox')
        daemon = docker.create_container('curtest.daemon', daemon_details)
        observer = docker.create_container('curtest.observer', observer_details)
        begin
          docker.start_container(id=daemon.id)
          sleep(1)
          docker.start_container(id=observer.id)

          # collect info on observer
          observer_details = nil
          counter = 0
          loop do
            sleep(0.1)
            counter += 1
            observer_details = docker.inspect_container(id=observer.id)
            raise 'timeout exceeded' if counter >= 100
            break if observer_details.state.status == "exited"
          end

          # Assertions
          output = docker.attach_container(id=observer.id).stream.strip
          failure_msg = "Non-zero exit status (#{observer_details.state.exit_code}) - #{output}"
          expect(observer_details.state.exit_code).to eq(0), failure_msg
        ensure
          # bring down containers
          [daemon.id, observer.id].each do |id|
            docker.stop_container(id=id) rescue nil
            docker.delete_container(id=id) rescue nil
          end
        end
      end
    end
  end
end
