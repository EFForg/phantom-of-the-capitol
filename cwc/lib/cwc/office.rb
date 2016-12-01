module Cwc
  class Office
    attr_reader :code

    def initialize(code)
      @code = code
    end

    def house?
      code[0, 1] == "H"
    end

    def senate?
      code[0, 1] == "S"
    end

    def house_district
      code[-2..-1].to_i
    end

    def senate_class
      code[-1..-1].to_i + 1
    end

    def state
      code[1..2]
    end
  end
end
