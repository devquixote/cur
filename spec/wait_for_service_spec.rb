require 'spec_helper'

module Cur
  describe WaitForService do
    let(:docker) { DockerClient.new }
    let(:container) do
      Container.new(docker) do |container|
        container.name = 'cur.service'
        container.type = :service
        container.image = 'alpine'
        #container.command = ["/bin/sh", "-c", "sleep 5; nc -w 3 -v -l -p 8080 -e hostname"]
        container.command = ["/bin/sh", "-c", "sleep 0.1; nc -w 3 -v -l -p 8080 -e hostname"]
        container.exposed_ports = [ExposedPort.new("8080", "tcp")]
        container.term_signal = 'SIGKILL'
      end
    end
    let(:details) { container.inspect }

    around(:each) do |example|
      begin
        container.create!
        container.start!
        pp container.inspect
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
      expect(details.state.status).to eq("exited")
    end

    it "should raise error if the service does not become ready before the timeout" do
      expect{WaitForService.new(container, wait_timeout: 0.1).call}.to raise_error(ServicesNotReadyError)
    end
  end
end
