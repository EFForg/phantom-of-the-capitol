require "thread"

class CaptchaCache
  attr_accessor :timeout
  cattr_accessor :instance

  def self.current
    if instance
      instance
    else
      self.instance = self.new
    end
  end

  def initialize
    @captchas = {}
    @time_set = {}
    @timeout = Padrino.env == :test ? 4 : CAPTCHA_TIMEOUT

    garbage_collect
  end

  def [] index
    @captchas[index]
  end

  def []= index, handler
    @time_set[index] = Time.now
    @captchas[index] = handler
  end

  def remove index
    @captchas[index].finish_workflow
    @captchas.delete index
    @time_set.delete index
  end

  def include? index
    @captchas.include? index
  end

  def delete index
    @captchas.delete index
  end

  private

  def garbage_collect
    Thread.new do
      loop do
        sleep 0.5
        @captchas.keys.each do |index|
          if Time.now - @time_set[index] > @timeout
            remove index
          end
        end
      end
    end
  end
end
