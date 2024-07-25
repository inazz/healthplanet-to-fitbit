

module HealthPlanetToFitBit


class HealthPlanetToFitBitSyncer

  def initialize(config)
    @config = config
    @health_planet = HealthPlanet.new(config)
    @fit_bit = FitBit.new(config)
  end

  def sync(from_date, to_date)
    hp_body_logs = []
    withTokenRefresher(@health_planet) {
      hp_body_logs = @health_planet.getBodyLogs(from_date, to_date)
    }

    fb_body_logs = []
    withTokenRefresher(@fit_bit) {
      fb_body_logs = @fit_bit.getBodyLogs(from_date, to_date)
    }
    body_log_updates = calcEntryToCopyIntoFitBit(hp_body_logs, fb_body_logs)
    insertIntoFitBit(body_log_updates)
  end

  def calcEntryToCopyIntoFitBit(hp_body_logs, fb_body_logs)
    date_to_fb_body_log = Hash[*(fb_body_logs.map{|log| [timeToDate(log.time), log]}.flatten(1))]

    ans = []
    hp_body_logs.group_by{|log| timeToDate(log.time)}.values.map{|logs| logs.max_by{|log| log.time}}.each{|hp_body_log|
      fb_body_log = date_to_fb_body_log.fetch(timeToDate(hp_body_log.time))
      if (fb_body_log == nil)
        ans.append(hp_body_log.clone())
      else
        update_weight = (hp_body_log != nil && !isAlmostSameDecimal(fb_body_log.weight, hp_body_log.weight))
        update_fat_rate = (hp_body_log != nil && !isAlmostSameDecimal(fb_body_log.fat_rate, hp_body_log.fat_rate))
        if update_weight || update_fat_rate
          body_log = hp_body_log.clone()
          body_log.weight = nil unless update_weight
          body_log.fat_rate = nil unless update_fat_rate
          ans.append(body_log)
          puts "---"
          puts fb_body_log
          puts hp_body_log
          
        end
      end
    }
    return ans
  end

  def insertIntoFitBit(body_logs)
    body_logs.each{|body_log|
      if (body_log.weight != nil)
        withTokenRefresher(@fit_bit) {
          @fit_bit.createBodyWeightLog(body_log.time, body_log.weight)
        }
      end
      if (body_log.fat_rate != nil)
        withTokenRefresher(@fit_bit) {
          @fit_bit.createBodyFatLog(body_log.time, body_log.fat_rate) 
        }
      end
    }
  end
  
  def timeToDate(time)
    return Date.new(time.year, time.month, time.day)
  end

  
  
  # HealthPlanet: '80.10' vs FitBit: '80.1'
  # HealthPlanet: '29.80' vs FitBit: '29.798999786376953'
  def isAlmostSameDecimal(a, b)
    return ((a.to_f - b.to_f).abs < 0.005)
  end

  def withTokenRefresher(refresher)
    begin
      yield
    rescue AccessTokenExpired
      refresher.refreshToken()
      @config.save()
      yield
    end
  end

end

end # module
