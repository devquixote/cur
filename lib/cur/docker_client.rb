require 'json'
require 'logger'
require 'net_http_unix'
require 'pp'
require_relative 'payloads'

module Cur
  # Client for interfacing with the docker API.  API v1.20 is used by default
  #
  # See https://docs.docker.com/engine/reference/api/docker_remote_api_v1.20/
  class DockerClient
    include Payloads

    Endpoint = Struct.new(:method, :path, :valid_responses)

    API = {
      :create_image => Endpoint.new(:Post, "/images/create", ["200"]),
      :list_images => Endpoint.new(:Get, "/images/json", ["200"]),
      :inspect_image => Endpoint.new(:Get, "/images/%s/json", ["200"]),
      :delete_image => Endpoint.new(:Delete, "/images/%s", ["200"]),
      :create_container => Endpoint.new(:Post, "/containers/create", ["201"]),
      :list_containers => Endpoint.new(:Get, "/containers/json", ["200"]),
      :inspect_container => Endpoint.new(:Get, "/containers/%s/json", ["200"]),
      :start_container => Endpoint.new(:Post, "/containers/%s/start", ["204"]),
      :attach_container => Endpoint.new(:Post, "/containers/%s/attach", ["200"]),
      :wait_container => Endpoint.new(:Post, "/containers/%s/wait", ["200"]),
      :stop_container => Endpoint.new(:Post, "/containers/%s/stop", ["204", "304"]),
      :container_logs => Endpoint.new(:Get, "/containers/%s/logs", ["200"]),
      :kill_container => Endpoint.new(:Post, "/containers/%s/kill", ["204"]),
      :delete_container => Endpoint.new(:Delete, "/containers/%s", ["204"])
    }

    class APIError < StandardError
      attr_reader :code

      def initialize(code, message)
        super("#{code}: #{message}")
        @code = code
      end
    end

    attr_reader :api_version, :protocol, :location, :port, :logger

    def initialize(opts={})
      @api_version = opts[:api_version] || 'v1.20'
      @protocol = opts[:protocol] || 'unix'
      @location = opts[:location] || '/var/run/docker.sock'
      @port = opts[:port]
      @logger = Logger.new(opts[:log_path] || STDOUT)
      @logger.level = opts[:log_level] || Logger::INFO
    end

    def ping
      request_and_response(:list_containers)
      true
    rescue => e
      false
    end

    def pull_image(image=None, tag='latest')
      params = {fromImage: image, tag: tag}
      multi_json_to_dto(request_and_response(:create_image, params: params))
    end

    def list_images(all=true)
      json_to_dto(request_and_response(:list_images, params: {all: all}))
    end

    def inspect_image(image=None)
      json_to_dto(request_and_response(:inspect_image, id: image))
    end

    def delete_image(image=None, force=false)
      json_to_dto(request_and_response(:delete_image, id: image, params: {force: force}))
    end

    def create_container(name, details)
      json_to_dto(request_and_response(:create_container, payload: details, params: {name: name}))
    end

    def delete_container(id=nil, force=false)
      request_and_response(:delete_container, id: id, params: {force: force})
      true
    end

    def list_containers(all=true)
      json_to_dto(request_and_response(:list_containers, params: {all: all}))
    end

    def inspect_container(id=nil)
      json_to_dto(request_and_response(:inspect_container, id: id))
    end

    def start_container(id=nil)
      request_and_response(:start_container, id: id)
      true
    end

    def attach_container(id=nil, logs=true, stream=false, stdin=false, stdout=true, stderr=true)
      params = {
        logs: logs,
        stream: stream,
        stdin: stdin,
        stdout: stdout,
        stderr: stderr
      }
      OpenStruct.new stream: stripped(request_and_response(:attach_container, id: id, params: params))
    end

    def container_logs(id=nil, follow=false, stdout=true, stderr=true, since=0, timestamps=true, tail='all')
      params = {
        follow: follow,
        stdout: stdout,
        stderr: stderr,
        since: since,
        timestamps: timestamps,
        tail: tail
      }
      OpenStruct.new stream: stripped(request_and_response(:container_logs, id: id, params: params))
    end

    def wait_container(id=nil)
      json_to_dto(request_and_response(:wait_container, id: id))
    end

    def stop_container(id=nil, t=5)
      request_and_response(:stop_container, id: id, params: {t: t})
      true
    end

    def kill_container(id=nil, signal='SIGINT')
      request_and_response(:kill_container, id: id, params: {signal: signal})
      true
    end

    def address
      @address ||= "#{@protocol}://#{@location}"
    end

    private

    def request_and_response(endpoint_key, details={})
      payload = details.delete(:payload)
      endpoint = DockerClient::API[endpoint_key]
      request = build(endpoint, details)
      logger.debug("#{request.method} #{request.path}")
      if payload
        logger.debug("#{JSON.pretty_generate(payload)}")
        request.body = JSON.dump(payload)
      end
      response = http_client.request(request)
      unless endpoint.valid_responses.include? response.code
        raise APIError.new(response.code, response.body)
      end
      response.body
    end

    def stripped(str)
      (str || "").gsub(/[\r\n]/, "")
    end

    def build(endpoint, details={})
      url = url(endpoint, details)
      klass = Net::HTTP.const_get(endpoint.method)
      klass.new(url, initheader = default_headers)
    end

    def default_headers
      {'Content-Type' => 'application/json'}
    end

    def url(endpoint, details={})
      result = "/#{api_version}#{endpoint.path}" % details[:id]
      if details[:params]
        result += "?#{URI.encode_www_form(details[:params])}"
      end
      result
    end

    def http_client
      @http_client ||= NetX::HTTPUnix.new(address, port)
    end
  end
end
