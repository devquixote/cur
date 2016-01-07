require 'spec_helper'

module Cur
  describe WaitForService do
    let(:docker) { DockerClient.new }
    let(:container) do
      Container.new(docker) do |container|
        container.name = 'cur.service'
        container.type = :service
        container.image = 'busybox'
        #container.command = ["/bin/sh", "-c", "/bin/sleep 2 && /bin/nc -l -p 8080"]
        container.command = ["/bin/sh", "-c", "/bin/sleep 1; /bin/nc -l -p 8080"]
        container.exposed_ports = [ExposedPort.new("8080", "tcp")]
        container.term_signal = 'SIGKILL'
      end
    end

    around(:each) do |example|
      begin
        container.create!
        container.start!
        example.run
      ensure
        observer = docker.list_containers.detect{|c| c.names.include?("/cur.service.observer")}
        docker.delete_container(observer.id, true) rescue nil
        container.stop! rescue nil
        container.destroy! rescue nil
      end
    end

    it "should continue if the service becomes ready before the timeout" do
      WaitForService.new(container, wait_timeout: 5).call
      details = container.inspect
      expect(details.state.status).to eq("exited")
    end

    it "should raise error if the service does not become ready before the timeout" do
      expect{WaitForService.new(container, wait_timeout: 1).call}.to raise_error("cur.service not ready within 1 seconds")
    end
  end
end
