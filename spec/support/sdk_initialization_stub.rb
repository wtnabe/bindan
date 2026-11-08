class SdkInitializationStub
  attr_reader :options

  def new(**options)
    @options = options
    nil
  end
end
