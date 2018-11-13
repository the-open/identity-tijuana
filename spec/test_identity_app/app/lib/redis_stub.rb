class RedisStub
  @date = '1970-01-01 00:00:00'

  def with
    yield self
  end
  def reset
    instance_variables.each do |variable|
      variable = nil
    end
  end
  def get(key)
    eval('@'+key)
  end
  def set(key, value=Time.now)
    instance_variable_set("@" + key, value.to_s)
  end
end
