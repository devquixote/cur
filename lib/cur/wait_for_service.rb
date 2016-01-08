module Cur
  ServiceObservation = Struct.new(:service, :exposed_port, :status, :exit_code, :output) do
    def to_s
      "#{service} not listening on #{exposed_port} (nc exit #{exit_code}): #{output}"
    end
  end

  class ServicesNotReadyError < StandardError
    attr_reader :observations

    def initialize(observations)
      super(observations.map(&:to_s).join("\n"))
      @observations = observations
    end
  end

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
      @logger = Logger.new(opts[:log_path] || STDOUT)
      @logger.level = opts[:log_level] || Logger::INFO
    end

    def call
      launch_observers!
      observe_services_for_readiness
      destroy_observers!
    end

    private

    def launch_observers!
      @observers.each do |ep, observer|
        @logger.info "Waiting for #{name} port #{ep.port} to begin accepting connections"
        observer.create!
        observer.start!
      end
    end

    def observe_services_for_readiness
      start = Time.now
      loop do
        observations = @observers.map(&to_service_observations)
        services_not_ready = observations.reject(&services_observed_ready)
        break if services_not_ready.empty?
        if elapsed_since(start) > wait_timeout
          @logger.warn "Some services not ready after #{wait_timeout} seconds"
          raise ServicesNotReadyError, services_not_ready
        end
        sleep(0.1)
      end
    end

    def elapsed_since(start)
      Time.now - start
    end

    def to_service_observations
      lambda do |kv|
        exposed_port = kv.first
        observer = kv.last
        state = observer.inspect.state
        output = observer.attach.stream
        ServiceObservation.new name, exposed_port.to_s, state.status,
                               state.exit_code, output
      end
    end

    def services_observed_ready
      lambda {|observation| observation.status == 'exited' && observation.exit_code == 0}
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
        container.image = 'alpine'
        container.command = ["/usr/bin/nc", "-vv", name, exposed_port.port.to_s, "-e", "/bin/hostname"]
        container.links = [Link.new(name, name)]
        container.term_signal = 'SIGKILL'
      end
    end

    def exposed_tcp_ports
      exposed_ports.select{|ep| ep.protocol.to_s == 'tcp'}
    end
  end
end
