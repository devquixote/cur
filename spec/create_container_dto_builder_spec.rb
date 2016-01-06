require_relative 'spec_helper'

module Cur
  describe CreateContainerDTOBuilder do
    let(:container) do
      OpenStruct.new name: 'test',
                     type: :task,
                     image: 'busybox',
                     command: '/bin/sh',
                     working_dir: '/usr/local/src',
                     links: [Link.new('container', 'hostname')],
                     env: {a: 1, b: 2},
                     exposed_ports: [ExposedPort.new(80, :tcp), ExposedPort.new(443, :udp)],
                     volumes: [Volume.new(".", "/usr/local/src/proj")]
    end
    let(:builder) { CreateContainerDTOBuilder.new container }
    let(:payload) { builder.build }
    let(:host_config) { payload['HostConfig'] }

    describe "#build creates a DTO that" do
      it "should contain the Image"  do
        expect(payload['Image']).to eq('busybox')
      end

      it "should contain the Command" do
        expect(payload['Cmd']).to eq('/bin/sh')
      end

      it "should contain the WorkingDir" do
        expect(payload['WorkingDir']).to eq('/usr/local/src')
      end

      it "should contain the Env" do
        expect(payload['Env']).to eq(["a=1","b=2"])
      end

      it "should contain the ExposedPorts" do
        expect(payload['ExposedPorts']).to eq(["80/tcp","443/udp"])
      end

      it "should contain Links in the HostConfig" do
        expect(host_config['Links']).to eq(['container:hostname'])
      end

      it "should contain the volume bindings in Binds in the HostConfig" do
        expect(host_config['Binds']).to eq(['.:/usr/local/src/proj'])
      end

      it "should not blow up when attributes are missing" do
        container = OpenStruct.new
        payload = CreateContainerDTOBuilder.new(container).build
        expect(payload).to eq({})
      end
    end
  end
end
