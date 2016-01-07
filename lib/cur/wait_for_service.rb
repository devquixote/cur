module Cur
  class WaitForService
    extend Forwardable

    def_delegators :@container, :name, :docker, :exposed_ports
    attr_reader :wait_timeout

    def initialize(container, opts)
      @container = container
      @wait_timeout = opts[:wait_timeout] || 30
      @command = opts[:command] || ["/bin/sh", "-c", "/bin/echo info | /bin/nc #{name} %s"]
      @observers = {}
      unless exposed_tcp_ports.empty?
        exposed_tcp_ports.each do |exposed_port|
          @observers[exposed_port] = observer(exposed_port)
        end
      end
    end

    def call
      launch_observers!
      check_observers
      destroy_observers!
    end

    def launch_observers!
      @observers.each do |ep, observer|
        puts "Waiting for #{name} port #{ep.port} to begin accepting connections"
        observer.create!
        observer.start!
      end
    end

    def check_observers
      start = Time.now
      loop do
        elapsed = Time.now - start
        raise "#{name} not ready within #{wait_timeout} seconds" if elapsed > wait_timeout
        observer_states = @observers.map{|_, observer| observer.inspect}
                                    .map{|details| details.state}
        pp observer_states
        break if observer_states.reject(&services_observed_ready).empty?
        sleep(0.1)
      end
    end

    def services_observed_ready
      lambda {|state| state.status == 'exited' && state.exit_code == 0}
    end

    def destroy_observers!
      @observers.each do |ep, observer|
        puts "Destroying observer.name"
        observer.destroy!
      end
    end

    def observer(exposed_port)
      @observer ||= Container.new(docker) do |container|
        container.name = "#{name}.observer"
        container.type = :task
        container.image = 'busybox'
        container.command = ["/bin/sh", "-c", "/bin/echo info | /bin/nc #{name} #{exposed_port.port}"]
        container.links = [Link.new(name, name)]
        container.term_signal = 'SIGKILL'
      end
    end

    def exposed_tcp_ports
      exposed_ports.select{|ep| ep.protocol.to_s == 'tcp'}
    end
  end
end
