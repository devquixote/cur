require "cur/version"
require "cur/container_definition"
require "cur/payloads"
require "cur/inflections"
require "cur/docker_client"
require "cur/container_validator"
require "cur/create_container_dto_builder"
require "cur/container"

module Cur
  Link = Struct.new(:container_name, :host_name)
  ExposedPort = Struct.new(:port, :protocol)
  Volume = Struct.new(:host_path, :container_path)
end
