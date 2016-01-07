require 'forwardable'

module Cur
  class CreateContainerDTOBuilder
    extend Forwardable
    include Inflections

    @attrs = [:image, :cmd, :working_dir, :env, :exposed_ports]
    @host_config_attrs = [:links, :binds]

    class << self
      attr_reader :attrs, :host_config_attrs
    end

    def_delegators :@container, :image, :command, :working_dir, :volumes
    attr_reader :container

    def initialize(container)
      @container = container
    end

    alias_method :cmd, :command

    def build
      result = {
        'HostConfig' => {}
      }

      load_attrs_into result
      load_host_config_attrs_into result['HostConfig']
      result.delete('HostConfig') if result['HostConfig'].empty?
      result
    end

    def links
      return nil unless container.links
      container.links.map(&:to_s)
    end

    def binds
      return nil unless container.volumes
      container.volumes.map(&:to_s)
    end

    def env
      return nil unless container.env
      container.env.map { |tuple| "#{tuple.first}=#{tuple.last}" }
    end

    def exposed_ports
      return nil unless container.exposed_ports
      {}.tap do |hash|
        container.exposed_ports.map(&:to_s).each do |port|
          hash[port] = {}
        end
      end
    end

    private

    def load_attrs_into(hash)
      self.class.attrs.each do |attr|
        hash[camelize(attr)] = send(attr) if send(attr)
      end
    end

    def load_host_config_attrs_into(hash)
      self.class.host_config_attrs.each do |attr|
        hash[camelize(attr)] = send(attr) if send(attr)
      end
    end
  end
end
