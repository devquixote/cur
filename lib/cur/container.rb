require 'forwardable'
require 'ostruct'

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
                                  :volumes, :links, :env, :exposed_ports

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

    def create!
      raise "Container already created" if id
      @id = docker.create_container(name, create_dto).id
      @state = :created
      true
    end

    def start!
      raise 'not implemented'
    end

    def stop!
      raise 'not implemented'
    end

    def kill!
      raise 'not implemented'
    end

    def destroy!
      raise "Container not created" unless id
      docker.delete_container(id, true)
      @id = nil
      @state = :destroyed
      true
    end

    def inspect
      raise 'not implemented'
    end

    private 

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
