
require 'fileutils'
require 'pathname'
require 'tmpdir'
require 'yaml'

module HealthPlanetToFitBit

class ConfigFile
  attr_reader :filename

  attr_reader :data
  KEYS = ['healthplanet-client-id', 'healthplanet-client-secret',
          'healthplanet-access-token', 'healthplanet-refresh-token',
          'fitbit-client-id', 'fitbit-client-secret',
          'fitbit-code-verifier',
          'fitbit-access-token', 'fitbit-refresh-token',
         ]
  def initialize(filename)
    @filename = filename
    @data = {}
    KEYS.each{|key|
      @data[key] = ''
    }
  end
  

  def verify()
    throw "content is not hash data." unless @data.is_a?(Hash)
    KEYS.each {|key|
      throw key + " is missing." unless @data.has_key?(key)
    }
  end

  def save()
    saveAs(@filename)
  end

  def saveAs(filename)
    Dir.mktmpdir() {|dir|
      tmpfile = Pathname(dir).join('tmpfile').to_s
      FileUtils.touch(tmpfile)
      FileUtils.chmod(0600, tmpfile)
      IO.write(tmpfile, YAML.dump(@data))
      FileUtils.mv(tmpfile, filename)
    }
  end

  def load()
    loadFrom(@filename)
  end

  def loadFrom(filename)
    @data = YAML.load(IO.read(filename))
    verify()
  end
  
  def self.loadOrEmpty(filename)
    begin
      config = ConfigFile.new(filename)
      config.load()
      return config
    rescue => e
      puts e
    end
    return ConfigFile.new(filename)
  end
end

end # module
