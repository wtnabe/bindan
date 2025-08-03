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
      container
    else
      warn "no block given for `configure'"
    end
  end
  module_function :configure
end
