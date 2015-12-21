module Cur
  class ContainerDefinition
    attr_accessor :parent

    def initialize
      @env = {}
      @links = {}
      @expose = {}
      @volumes = {}
      @parent = nil
    end

    def valid?
      !(name.nil? || image.nil?)
    end

    def validate!
      raise "Container must have a name" unless name
      raise "Container must have an image" unless image
    end

    def name(value=nil)
      if value.nil?
        return @name unless @parent && @parent.name
        full_name = "#{@parent.name}.#{@name}"
        return nil if full_name.gsub(/\./, "").empty?
        full_name
      else
        @name = value
      end
    end

    def command(value=nil)
      get_or_set!(:@command, value)
    end

    def image(value=nil)
      get_or_set!(:@image, value)
    end

    def env(arg)
      merge_or_get! :@env, arg
    end

    def links(arg)
      merge_or_get! :@links, arg
    end

    def expose(arg)
      if arg.kind_of? Hash
        @expose.clear
        arg.keys.each do |key|
          @expose[key.to_s] = arg[key].to_s
        end
        @expose
      else
        @expose[arg.to_s]
      end
    end

    def volumes(arg)
      merge_or_get! :@volumes, arg
    end

    def workdir(value=nil)
      get_or_set!(:@workdir, value)
    end

    def detach(value=nil)
      get_or_set!(:@detach, value)
    end

    def rm(value=nil)
      get_or_set!(:@rm, value)
    end

    protected

    def get_or_set!(name, value=nil)
      if value.nil?
        result = instance_variable_get(name)
        return result unless result.nil?
        return @parent.get_or_set!(name, nil) if @parent
      else
        instance_variable_set(name, value)
      end
    end

    def merge_or_get!(hash_field, arg)
      hash = instance_variable_get(hash_field)
      if arg.kind_of? Hash
        arg.keys.each do |key|
          hash[key.to_s] = arg[key].to_s
        end
        hash
      else
        result = hash[arg.to_s]
        return result unless result.nil?
        return @parent.merge_or_get!(hash_field, arg) if @parent
      end
    end
  end
end
