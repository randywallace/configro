require "configruous/version"
require "singleton"
require "yaml"
require "aws-sdk-ssm"
require "inifile"
require "ostruct"
#require 'hashdiff'

module Configruous
  class SSMClient
    include Singleton

    attr_reader :client

    def initialize
      # For not apparent reason, the AWS SDK *for ruby*
      # does not support these environment variables
      if ENV['AWS_CONFIG_FILE'] && ENV['AWS_PROFILE']
        @client = Aws::SSM::Client.new(
          credentials: Aws::SharedCredentials.new(
            profile_name: ENV['AWS_PROFILE'],
            path: ENV['AWS_CONFIG_FILE']
          )
        )
      elsif ENV['AWS_CONFIG_FILE']
        @client = Aws::SSM::Client.new(
          credentials: Aws::SharedCredentials.new(
            profile_name: 'default',
            path: ENV['AWS_CONFIG_FILE']
          )
        )
      else
        @client = Aws::SSM::Client.new
      end
    end
  end

  class BaseLoader 

    attr_accessor :data
    attr_accessor :raw_data

    def initialize filename=nil
      raise "Do not initialize base Loader class directly" if self.class == BaseLoader
      @filename = filename
      @extension = File.extname(filename)
      @environment ||= 'prod'
      @data = Array.new
      load_data @raw_data
    end

    def store!
      ssm_client = SSMClient.instance.client
      @data.each do |config|
        param_name = "/config/testing/#{config.environment}/#{config.filename}/#{config.key}"
        begin
          existing_param = SSMClient.instance.client.get_parameter(name: param_name).parameter
          if existing_param.value.to_s != config.value.to_s
            #puts "Updating #{param_name} by setting #{existing_param.value.to_s} to #{config.value.to_s}"
            ssm_client.put_parameter({
              name: param_name,
              value: config.value.to_s,
              type: "String",
              overwrite: true
            }).inspect
          end
        rescue Aws::SSM::Errors::ParameterNotFound
          #puts "Parameter not found; Setting #{param_name} to #{config.value.to_s}"
          ssm_client.put_parameter({
            name: param_name,
            value: config.value.to_s,
            type: "String",
          })
        end
      end
    end

    def list_found_keys
      @data.each do |config|
        puts "Storing /config/testing/#{config.environment}/#{config.filename}/#{config.key}: #{config.value}"
      end
    end

    def load_data dta
      dta.each do |k, v|
        case v.class.to_s
        when "NilClass"
          next
        when "Hash"
          v.each do |l, w|
            key = k + '/' + l.to_s
            load_data({ key => w })
          end
        when "Array"
          v.each_with_index do |value, index|
            key = k + '/' + index.to_s
            load_data({key => value})
          end
        else
          if k =~ /^[A-Za-z0-9\._\-\/]+$/
            @data << OpenStruct.new(
              filename: File.basename(@filename),
              environment: @environment,
              key: k,
              value: v
            )
          else
            raise RuntimeError, "#{k} contains invalid characters.  Valid Characters are: A-Za-z0-9.-_/"
          end
        end
      end
    end
  end

  class YAMLLoader < BaseLoader
    def initialize filename
      @raw_data = YAML.load_file(filename)
      super
    end
  end

  class PropertyLoader < BaseLoader
    def initialize filename
      @raw_data = IniFile.load(filename)['global']
      super
    end
  end
end

