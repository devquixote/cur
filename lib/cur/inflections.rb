module Cur
  module Inflections
    # Shamelessly copy and pasted to avoid bringing in all of active support
    def underscore(camel_cased_word)
      return camel_cased_word unless camel_cased_word =~ /[A-Z-]|::/
      word = camel_cased_word.to_s
      word = word.gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2'.freeze)
      word = word.gsub(/([a-z\d])([A-Z])/, '\1_\2'.freeze)
      word = word.tr("-".freeze, "_".freeze)
      word = word.downcase
    end

    def camelize(term)
      string = term.to_s
      string = string.sub(/^[a-z\d]/) { |match| match.capitalize }
      string = string.gsub(/(?:_|(\/))([a-zA-Z\d]*)/i) { "#{$1}#{$2.capitalize}" }
      string 
    end
  end
end
