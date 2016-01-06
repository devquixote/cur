require 'forwardable'
require 'ostruct'

module Cur
  # High level concept of a container that can be created, started, stopped,
  # killed, removed and inspected.  May have dependencies to other containers
  class Container
    extend Forwardable

    @validator = ContainerValidator
    class << self
      attr_accessor :validator
    end

    attr_accessor :definition
    attr_reader :state
    def_delegators :@definition, :name, :type, :image

    def initialize(&block)
      raise "Must provide block to initialize container" unless block
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
      raise 'not implemented'
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
      raise 'not implemented'
    end

    def inspect
      raise 'not implemented'
    end

    private 
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
