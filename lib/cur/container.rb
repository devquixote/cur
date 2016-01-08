require 'forwardable'
require 'ostruct'
require 'set'

module Cur
  # High level concept of a container that can be created, started, stopped,
  # killed, removed and inspected.  May have dependencies to other containers
  class Container
    extend Forwardable

    @validator = ContainerValidator
    @create_dto_builder = CreateContainerDTOBuilder

    class << self
      attr_accessor :validator, :create_dto_builder
    end

    attr_accessor :definition
    attr_reader :state, :docker, :id
    def_delegators :@definition, :name, :type, :image, :command, :working_dir,
                                  :volumes, :links, :env, :exposed_ports, :term_signal,
                                  :wait_for_service

    def initialize(docker, &block)
      raise "Must provide docker client" unless docker.is_a? DockerClient
      raise "Must provide block to initialize container" unless block
      @docker = docker
      @definition = OpenStruct.new
      block.call(definition)
      normalize!
      validate!
      @definition.freeze
      @state = :defined
    end

    def service?
      type == :service
    end

    def task?
      type == :task
    end

    def active?
      @state == :started || @state == :ready || @state == :working
    end

    def create!
      raise "Container already created" if id
      @id = docker.create_container(name, create_dto).id
      @state = :created
      true
    end

    def start!
      raise "Container not created" unless id
      raise "Container already started" if active?
      docker.start_container(id)
      @state = :started
      block_until_ready if service? && wait_for_service
      @state = if service?
        :ready
      else
        :working
      end
      true
    end

    def stop!
      raise "Container not started" unless active?
      if term_signal
        # TODO this may need to be expanded on.  What if the
        # term_signal is caught and ignored by the command
        # running in the container?
        docker.kill_container(id, term_signal)
      else
        docker.stop_container(id)
      end
      @state = :stopped
      true
    end

    def destroy!
      raise "Container not created" unless id
      docker.delete_container(id, true)
      @id = nil
      @state = :destroyed
      true
    end

    def inspect
      raise "Container not created" unless id
      docker.inspect_container(id)
    end

    def output
      raise "Container not started" unless active?
      docker.attach_container(id)
    end

    def attach(opts={}, &block)
      raise "Container not started" unless active?

      interval = opts[:interval] || 0.1
      previous_stream = []

      Thread.new do
        loop do
          begin
            sleep interval
            stream = docker.attach_container(id).stream
            new_events = stream - previous_stream
            block.call(new_events) unless new_events.empty?
            previous_stream = stream
          rescue => e
            # should we warn?
          end
        end
      end
    end

    private 

    def block_until_ready
      # TODO implement me
    end

    def create_dto
      @create_dto ||= Container.create_dto_builder.new(self).build
    end

    def normalize!
      definition.type = type.to_s.to_sym
      definition.image = image.to_s
      definition.name = name.to_s
    end

    def validate!
      Container.validator.new(self).validate!
    end
  end
end
