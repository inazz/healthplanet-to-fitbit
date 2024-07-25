# coding: utf-8

require 'base64'
require 'digest'
require 'json'
require 'net/http'
require 'securerandom'
require 'uri'

require_relative('config-file.rb')
require_relative('token-refresher.rb')

module HealthPlanetToFitBit

class FitBit < TokenRefresher
  attr_reader :config

  def initialize(config)
    @config = config
  end

  def setup()
    puts 'FitBit の API を使用します。'
    puts 'https://dev.fitbit.com/apps'
    puts '上記 URL から、App を登録し、Clint ID と Client secret を取得してください。'
    puts 'FitBit の OAuth 2.0 Client ID を入力してください'
    print '> '
    @config.data['fitbit-client-id'] = gets().chomp
    puts 'FitBit の Client Secret を入力してください'
    print '> '
    @config.data['fitbit-client-secret'] = gets().chomp

    code_verifier = createCodeVerifier()
    code_challenge = calcCodeChallengeFromCodeVerifier(code_verifier)
    
    puts '次に、以下の URL を開いてください。'
    url = sprintf('https://www.fitbit.com/oauth2/authorize?client_id=%s&response_type=code&code_challenge=%s&code_challenge_method=S256&scope=weight', @config.data['fitbit-client-id'], code_challenge)
    puts url
    puts 'Fitbit のアカウントにログイン後、"?code=" が含まれる URL にリダイレクトされるので、その URL を入力してください。'
    print '> '
    redirect_url = gets().chomp
    throw "unexpected url: #{redirect_url}" unless (redirect_url =~/\?code=([^&#]+)/)
    code = $1
    setupTokenFromCodeAndCodeVerifier(code, code_verifier)
  end

  def createCodeVerifier()
    return SecureRandom.alphanumeric(128)
  end

  def calcCodeChallengeFromCodeVerifier(code_verifier)
    digest = Digest::SHA256.new
    digest.update(code_verifier)
    return Base64.urlsafe_encode64(digest.digest, padding: false)
  end
  
  def setupTokenFromCodeAndCodeVerifier(code, code_verifier)
    url = 'https://api.fitbit.com/oauth2/token'
    content = sprintf('client_id=%s&code=%s&code_verifier=%s&grant_type=authorization_code',
                      @config.data['fitbit-client-id'],
                      code,
                      code_verifier)
    header = getHeaderForAuth()
    res = Net::HTTP.post(URI(url), content, header=header)
    throw sprintf('Unexpected response code: %s', res.code) unless (res.code == "200")
    obj = JSON.parse(res.body)
    throw sprintf('Unexpected response: %s', res.body) unless (
        obj.is_a?(Hash) && obj.has_key?('access_token') && obj.has_key?('refresh_token'))
    @config.data['fitbit-access-token'] = obj['access_token']
    @config.data['fitbit-refresh-token'] = obj['refresh_token']
  end

  WINDOW_MAX_DAYS = 1095
  def getBodyLogs(from_date, to_date)
    window_to_date = to_date
    date_str_to_body_log = {}
    while (from_date <= window_to_date)
      window_from_date = [from_date, window_to_date - WINDOW_MAX_DAYS + 1].max
      ['weight', 'fat'].each{|resource|
        ts = fetchBodyTimeSeries(resource, window_from_date, window_to_date)
        ts.each{|data|
          date_str = data['dateTime']
          date = Time.strptime(date_str, '%Y-%m-%d')
          date_str_to_body_log[date_str] = BodyLog.new(date) unless date_str_to_body_log.has_key?(date_str)
          if (resource == 'weight')
            date_str_to_body_log[date_str].weight = data['value']
          elsif (resource == 'fat')
            date_str_to_body_log[date_str].fat_rate = data['value']
          end
        }
      }
      window_to_date = window_from_date - 1
    end
    return date_str_to_body_log.values
  end

  def fetchBodyTimeSeries(resource, from_date, to_date)
    url = sprintf('https://api.fitbit.com/1/user/-/body/%s/date/%s/%s.json',
                  resource,
                  from_date.strftime('%Y-%m-%d'),
                  to_date.strftime('%Y-%m-%d'))
    header = getHeaderForData()
    res = Net::HTTP.get_response(URI(url), header=header)
    raise AccessTokenExpired.new if (res.code == '401')
    throw sprintf("Unexpected response code: %d", res.code) unless (res.code == "200")
    obj = JSON.parse(res.body)

    res_key = sprintf('body-%s', resource)
    throw sprintf("Unexpected response: %s", res.body) unless (
        obj.is_a?(Hash) && obj.has_key?(res_key) && obj[res_key].is_a?(Array))
    return obj[res_key]
  end

  def createBodyWeightLog(time, value)
    createBodyLog(time, 'weight', value)
  end

  def createBodyFatLog(time, value)
    createBodyLog(time, 'fat', value)
  end

  def createBodyLog(time, resource, value)
    url = sprintf('https://api.fitbit.com/1/user/-/body/log/%s.json',
                  resource)
    content = sprintf('%s=%s&date=%s&time=%s',
                      resource,
                      value,
                      time.strftime('%Y-%m-%d'),
                      time.strftime('%H:%M:%S'))
    header = getHeaderForData()
    res = Net::HTTP.post(URI(url), content, header=header)
    raise AccessTokenExpired.new if (res.code == '401')
    throw sprintf('Unexpected response code: %s', res.code) unless (res.code == '201')
    puts res.body
  end

  def getHeaderForAuth()
    return {
      'accept': 'application/json',
      'authorization' => sprintf('Basic %s', Base64.strict_encode64(sprintf('%s:%s', @config.data['fitbit-client-id'], @config.data['fitbit-client-secret'])))
    }
  end

  def getHeaderForData()
    return {
      'accept': 'application/json',
      'authorization': sprintf('Bearer %s', @config.data['fitbit-access-token'],
      'Accept-Language': 'ja_JP'), # use kg for weight.
    }
  end
  def refreshToken()
    url = 'https://api.fitbit.com/oauth2/token'
    content = sprintf('grant_type=refresh_token&refresh_token=%s&client_id=%s',
                      @config.data['fitbit-refresh-token'],
                      @config.data['fitbit-client-id'])
    header = getHeaderForAuth()
    res = Net::HTTP.post(URI(url), content, header=header)
    throw sprintf('Unexpected response code: %s', res.code) unless (res.code == '200')
    obj = JSON.parse(res.body)
    throw sprintf('Unexpected response: %s', res.body) unless (
        obj.is_a?(Hash) && obj.has_key?('access_token') && obj.has_key?('refresh_token'))
    @config.data['fitbit-access-token'] = obj['access_token']
    @config.data['fitbit-refresh-token'] = obj['refresh_token']
  end
end

end # module
