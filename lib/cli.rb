#!/usr/bin/env ruby

require 'date'
require 'optparse'

require_relative 'access-token-expired.rb'
require_relative 'config-file.rb'
require_relative 'health-planet.rb'
require_relative 'health-planet-to-fitbit-syncer.rb'
require_relative 'fitbit.rb'

module HealthPlanetToFitBit

class Cli
  class Option
    attr_reader :mode
    attr_reader :config_filename
    attr_reader :from_date, :to_date # Date
    
    def initialize
      @mode = ''
      @config_filename = '.hpfbconf'
      @to_date = Date.today()
      @from_date = @to_date - 30
    end

    def parse(args)
      opt = OptionParser.new

      opt.on('--mode MODE') {|v| @mode = v}
      opt.on('--file FILENAME') {|v| @config_filename = v}
      opt.on('--to DATE') {|v| @to_date = Date.parse(v)}
      opt.on('--from DATE') {|v| @from_date = Date.parse(v)}

      opt.parse!(args)
      return self
    end
  end

  def main(args)
    opt = Option.new.parse(args)
    if opt.mode == 'setup'
      setupHealthPlanet(opt)
      setupFitBit(opt)
    elsif opt.mode == 'setup-health-planet'
      setupHealthPlanet(opt)
    elsif opt.mode == 'setup-fit-bit'
      setupFitBit(opt)
    elsif opt.mode == 'copy'
      copyHealthPlanetToFitBit(opt)
    else
      throw "unexpected mode: #{opt.mode}"
    end
  end

  def setupHealthPlanet(opt)
    config = ConfigFile.loadOrEmpty(opt.config_filename)
    hp = HealthPlanet.new(config)
    hp.setup()
    config.save()
  end

  def setupFitBit(opt)
    config = ConfigFile.loadOrEmpty(opt.config_filename)
    fb = FitBit.new(config)
    fb.setup()
    config.save()
  end

  def copyHealthPlanetToFitBit(opt)
    config = ConfigFile.loadOrEmpty(opt.config_filename)
    syncer = HealthPlanetToFitBitSyncer.new(config)
    syncer.sync(opt.from_date, opt.to_date)
  end

end

end # module

HealthPlanetToFitBit::Cli.new.main(ARGV)
