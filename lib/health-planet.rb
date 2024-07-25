# coding: utf-8

require 'date'
require 'time'
require 'json'
require 'net/http'
require 'uri'

require_relative('access-token-expired.rb')
require_relative('body-log.rb')
require_relative('config-file.rb')
require_relative('token-refresher.rb')

module HealthPlanetToFitBit

class HealthPlanet < TokenRefresher
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def setup()
    puts 'HealthPlanet の API を使用します。'
    puts 'https://www.healthplanet.jp/apis_account.do'
    puts '上記 URL から、 Client Application 向けの client_id, client_sercret を作成し、取得してください。'
    puts 'HealthPlanet の Client ID を入力してください'
    print '> '
    @config.data['healthplanet-client-id'] = gets().chomp
    puts 'HealthPlanet の Client secret を入力してください'
    print '> '
    @config.data['healthplanet-client-secret'] = gets().chomp

    puts '次に、以下の URL を開いてください。'
    url = sprintf("https://www.healthplanet.jp/oauth/auth?client_id=%s&redirect_uri=https://www.healthplanet.jp/success.html&scope=innerscan,pedometer&response_type=code", @config.data['healthplanet-client-id'])
    puts url
    puts 'HealthPlanet のアカウントにログイン後、アクセスを許可し、コードを取得し、↓に入力してください。'
    print '> '
    code = gets().chomp
    setupTokenFromCode(code)
  end

  def setupTokenFromCode(code)
    url = sprintf("https://www.healthplanet.jp/oauth/token.?client_id=%s&client_secret=%s&redirect_uri=https://www.healthplanet.jp/success.html&code=%s&grant_type=authorization_code",
                  @config.data['healthplanet-client-id'],
                  @config.data['healthplanet-client-secret'],
                  code)
    res = Net::HTTP.post_form(URI(url), {})
    throw sprintf("Unexpected response code: %s", res.code) unless (res.code == "200")
    obj = JSON.parse(res.body)
    throw sprintf("Unexpected response: %s", res.body) unless (
        obj.is_a?(Hash) && obj.has_key?('access_token') && obj.has_key?('refresh_token'))
    @config.data['healthplanet-access-token'] = obj['access_token']
    @config.data['healthplanet-refresh-token'] = obj['refresh_token']
  end

  WINDOW_MAX_DAYS = 90
  WEIGHT_TAG = '6021'
  FAT_RATE_TAG = '6022'
  # both inclusive
  def getBodyLogs(from_date, to_date)
    window_to_date = to_date
    time_str_to_body_log = {}
    while (from_date <= window_to_date)
      window_from_date = [from_date, window_to_date - WINDOW_MAX_DAYS + 1].max
      url = sprintf('https://www.healthplanet.jp/status/innerscan.json?access_token=%s&date=0&tag=%s&from=%s&to=%s',
                    @config.data['healthplanet-access-token'],
                    [WEIGHT_TAG, FAT_RATE_TAG].join(","),
                    window_from_date.strftime("%Y%m%d000000"),
                    window_to_date.strftime("%Y%m%d235959"))
      res = Net::HTTP.post_form(URI(url), {})
      raise AccessTokenExpired.new if (res.code == '401')
      throw sprintf("Unexpected response code: %s", res.code) unless (res.code == "200")
      obj = JSON.parse(res.body)
      throw sprintf("Unexpected response: %s", res.body) unless (
          obj.is_a?(Hash) && obj.has_key?('data') && obj['data'].is_a?(Array))
      obj['data'].each{|data|
        time_str = data['date']
        tm = Time.strptime(time_str, "%Y%m%d%H%M")
        time_str_to_body_log[time_str] = BodyLog.new(tm) unless time_str_to_body_log.has_key?(time_str)
        if (data['tag'] == WEIGHT_TAG)
          time_str_to_body_log[time_str].weight = data['keydata']
        elsif (data['tag'] == FAT_RATE_TAG)
          time_str_to_body_log[time_str].fat_rate = data['keydata']
        end
      }
      window_to_date = window_from_date - 1
    end
    return time_str_to_body_log.values
  end

  def refreshToken()
    url = sprintf('https://www.healthplanet.jp/oauth/token.?client_id=%s&client_secret=%s&redirect_uri=https://www.healthplanet.jp/success.html&refresh_token=%s&grant_type=refresh_token',
                  @config.data['healthplanet-client-id'],
                  @config.data['healthplanet-client-secret'],
                  @config.data['healthplanet-refresh-token'])
    res = Net::HTTP.post_form(URI(url), {})
    throw sprintf("Unexpected response code: %s", res.code) unless (res.code == "200")
    obj = JSON.parse(res.body)
    throw sprintf("Unexpected response: %s", res.body) unless (
        obj.is_a?(Hash) && obj.has_key?('access_token') && obj.has_key?('refresh_token'))
    @config.data['healthplanet-access-token'] = obj['access_token']
    @config.data['healthplanet-refresh-token'] = obj['refresh_token']
  end
end

end # module
