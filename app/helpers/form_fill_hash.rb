require "thread"

class FillHash
  attr_accessor :timeout

  cattr_accessor :instance

  def self.new
    if instance
      instance
    else
      self.instance = super
    end
  end

  def initialize
    @fh = {}
    @ts = {}
    @timeout = Padrino.env == :test ? 4 : CAPTCHA_TIMEOUT

    garbage_collect
  end

  def [] index
    @fh[index]
  end

  def []= index, handler
    @ts[index] = Time.now
    @fh[index] = handler
  end

  def remove index
    @fh[index].finish_workflow
    @fh.delete index
    @ts.delete index
  end

  def include? index
    @fh.include? index
  end

  def delete index
    @fh.delete index
  end

  private

  def garbage_collect
    Thread.new do
      loop do
        sleep 0.5
        @fh.keys.each do |index|
          if Time.now - @ts[index] > @timeout
            remove index
          end
        end
      end
    end
  end
end
