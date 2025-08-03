module Bindan
  module Provider
    class Envvar
      #
      # @param [Hash] env
      # @param [Hash] options
      #
      def initialize(env = ENV.to_h, options = {})
        @_env = env
        @_options = options
      end

      #
      # @raise KeyError
      # @param [String] key
      # @return [String]
      #
      def [](key)
        if @_options[:raise_error]
          @_env.fetch(key)
        else
          @_env[key]
        end
      end
    end
  end
end
