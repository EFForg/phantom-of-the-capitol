require 'fiber'

class FillHandler
  def initialize c
    @c = c
  end

  def fill fields={}
    @fiber = Fiber.new do |answer|
      @c.fill_out_form fields do |c|
        answer = Fiber.yield c
      end
    end
  end
end
