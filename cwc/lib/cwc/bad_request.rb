module Cwc
  class BadRequest < Exception
    attr_reader :original_exception, :errors

    def initialize(e)
      @original_exception = e
      @errors = Nokogiri::XML(e.response.body).xpath("//Error").map(&:content)
      if @errors.empty?
        @errors << e.response.body
      end
    end
  end
end
