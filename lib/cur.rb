require "cur/version"
require "cur/container_definition"
require "cur/payloads"
require "cur/inflections"
require "cur/docker_client"
require "cur/container_validator"
require "cur/create_container_dto_builder"
require "cur/wait_for_service"
require "cur/container"

module Cur
  Link = Struct.new(:container_name, :host_name) do
    define_method(:to_s) { "#{container_name}:#{host_name}" }
  end

  ExposedPort = Struct.new(:port, :protocol) do
    define_method(:to_s) { "#{port}/#{protocol}" }
  end

  Volume = Struct.new(:host_path, :container_path) do
    define_method(:to_s) { "#{host_path}:#{container_path}" }
  end
end
