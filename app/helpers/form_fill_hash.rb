class FillHash
  attr_accessor :timeout

  def initialize
    @fh = {}
    @timeout = Padrino.env == :test ? 4 : 120
  end

  def [] index
    @fh[index]
  end

  def []= index, handler
    @fh[index] = handler
    remove_after_timeout index
  end

  def remove_after_timeout index
    Thread.new do
      sleep @timeout
      @fh.delete index
    end
  end

  def include? index
    @fh.include? index
  end

  def delete index
    @fh.delete index
  end
end
