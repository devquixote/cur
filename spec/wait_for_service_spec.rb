require 'spec_helper'

module Cur
  describe WaitForService do
    let(:docker) { DockerClient.new }
    let(:service) do
      Container.new(docker) do |service|
        service.name = 'cur.service'
        service.type = :service
        service.image = 'alpine'
        #service.command = ["/bin/sh", "-c", "sleep 5; nc -w 3 -v -l -p 8080 -e hostname"]
        #service.command = ["/bin/sh", "-c", "sleep 1; nc -v -l -p 8080 -e hostname"]
        #service.command = ["/bin/sh", "-c", "sleep 0.5; echo test"]
        #service.command = ["/bin/sh", "-c", "sleep 1; nc -v -l -p 8080 -e hostname"]
        service.command = ["/bin/sh", "-c", "sleep 1; nc -vv -l -p 8080 0.0.0.0 -e hostname"]
        service.exposed_ports = [ExposedPort.new("8080", "tcp")]
        service.term_signal = 'SIGKILL'
      end
    end
    let(:details) { service.inspect }

    around(:each) do |example|
      begin
        service.create!
        service.start!
        example.run
      ensure
        observer = docker.list_containers.detect{|c| c.names.include?("/cur.service.observer")}
        docker.delete_container(observer.id, true) rescue nil
        pp "SERVICE: #{service.attach}" rescue nil
        service.stop! rescue nil
        service.destroy! rescue nil
      end
    end

    it "should continue if the service becomes ready before the timeout" do
      WaitForService.new(service, wait_timeout: 2).call
      expect(details.state.status).to eq("exited")
    end

    it "should raise error if the service does not become ready before the timeout" do
      expect{WaitForService.new(service, wait_timeout: 0.1).call}.to raise_error(ServicesNotReadyError)
    end
  end
end
