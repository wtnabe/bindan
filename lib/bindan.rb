# frozen_string_literal: true

require "ostruct"
require_relative "bindan/version"
require_relative "bindan/error"
require_relative "bindan/providers"

module Bindan
  #
  # @param [Hash[Symbol, Provider]] providers
  # @param [Proc] block
  # @return [OpenStruct]
  #
  def configure(providers: {env: Bindan::Provider::Envvar.new}, &block)
    if block.is_a? Proc
      container = OpenStruct.new
      block.call(container, Struct.new(*providers.keys).new(*providers.values)) # steep:ignore
      if instance_variables.include?(:@_config)
        instance_variable_set :@_config, container.freeze
      end
      container
    else
      warn "no block given for `configure'"
    end
  end
  module_function :configure

  #
  # @param [Class] klass
  # @return [self]
  #
  def self.extended(klass)
    klass.instance_eval do
      @_config = nil

      #
      # @return [OpenStruct]
      #
      def self.config
        @_config
      end
    end
    public :configure
  end
end
