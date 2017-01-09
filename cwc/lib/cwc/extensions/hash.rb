class Hash
  unless instance_methods.include?(:dig)
    def dig(key, *args)
      obj = self[key]
      if args.empty?
        obj
      elsif !obj.nil?
        obj.dig(*args)
      end
    end
  end

  def dig!(key, *keys)
    if keys.empty?
      fetch(key)
    else
      fetch(key).dig!(*keys)
    end
  end
end
