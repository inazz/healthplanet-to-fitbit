

module HealthPlanetToFitBit


class BodyLog
  attr_accessor :time # Time
  attr_accessor :weight, :fat_rate # String

  def initialize(time, weight = nil, fat_rate = nil)
    @time = time
    @weight = weight
    @fat_rate = fat_rate
  end

  def clone()
    return BodyLog.new(@time, @weight, @fat_rate)
  end

  def to_s
    return {time: @time.to_s, weight: @weight, fat_rate: @fat_rate}.to_s
  end
end

end # module
