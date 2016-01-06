require 'delegate'

module Cur
  class ContainerValidator < SimpleDelegator
    def validate!
      raise "No name specified" unless provided_with? :name
      raise "No container type specified" unless provided_with? :type
      raise "Invalid container type: #{type}" unless type_is_valid?
      raise "No image specified" unless provided_with? :image
    end

    private

    def type_is_valid?
      type.to_s.to_sym == :service || type.to_s.to_sym == :task
    end

    def provided_with?(attr)
      return false if send(attr).nil?
      return false if send(attr).kind_of?(String) && send(attr).empty?
      true
    end
  end
end
