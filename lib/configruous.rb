require "configruous/version"
require "singleton"
require "yaml"
require "aws-sdk-ssm"
require "inifile"
require "ostruct"

module Configruous
  module Helpers
    class << self
      def deep_merge h1, h2
        if h1.respond_to? :merge
          h1.merge(h2) { |key, h1_elem, h2_elem| deep_merge(h1_elem, h2_elem) }
        else
          h1 + h2
        end
      end
    end
  end

  class SSMClient
    include Singleton

    attr_reader :client

    def initialize
      # For no apparent reason, the AWS SDK *for ruby*
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
    attr_accessor :environment

    def initialize filename=nil, options={}
      raise "Do not initialize base Loader class directly" if self.class == BaseLoader
      @filename = filename
      @extension = File.extname(filename)
      @environment = options[:environment] || 'prod'
      @data = Array.new
      load_data @raw_data
    end

    def ssmclient_iterator prefix, &block
      request_path = '/' + prefix + '/' + @environment + '/' + @filename + '/'
      existing = Array.new
      ssm_client = SSMClient.instance.client
      ssm_client.get_parameters_by_path(path: request_path, recursive: true).each do |response|
        existing += response.to_h[:parameters] unless response.parameters.nil?
      end
      to_params(prefix).each do |key, value|
        begin
          existing_param = existing.select{|record| record[:name] == key} 
          unless existing_param.empty?
            if existing_param.first[:value].to_s != value.to_s
              block.call(:changed, key, existing_param.first[:value], value)
            else
              block.call(:unchanged, key, existing_param.first[:value], value)
            end
            existing.delete_if{|record| record[:name] == key}
          else
            block.call(:missing, key, nil, value)
          end
        end
      end
      existing.each do |not_in_ssm|
        block.call(:ssm_only, not_in_ssm[:name], not_in_ssm[:value], nil)
      end
    end

    def diff prefix="config/testing"
      response_hash = Hash.new 
      ssmclient_iterator prefix do |state, key, existing, new|
        case state
        when :changed
          response_hash[:update] = Hash.new unless response_hash.has_key? :update
          response_hash[:update][key] = [existing, new]
        when :unchanged
          response_hash[:unchanged] = Hash.new unless response_hash.has_key? :unchanged
          response_hash[:unchanged][key] = new
        when :missing
          response_hash[:add] = Hash.new unless response_hash.has_key? :add
          response_hash[:add][key] = new
        when :ssm_only
          response_hash[:ssm_only] = Hash.new unless response_hash.has_key? :ssm_only
          response_hash[:ssm_only][key] = existing
        end
      end
      response_hash
    end

    def store! prefix="config/testing"
      ssm_client = SSMClient.instance.client
      ssmclient_iterator prefix do |state, key, existing, new|
        case state
        when :changed
          ssm_client.put_parameter({
            name: key,
            value: new.to_s,
            type: "String",
            overwrite: true
          })
        when :missing
          ssm_client.put_parameter({
            name: key,
            value: new.to_s,
            type: "String"
          })
        when :ssm_only
          ssm_client.delete_parameter({
            name: key
          })
        end
      end
    end

    def diff_print prefix="config/testing"
      diff.each do |k, v|
        case k
        when :update
          puts "Updates"
          v.each do |arr|
            puts " ~ #{arr[0]}: #{arr[1].join(' => ')}"
          end
        when :add
          puts "Additions"
          v.each do |arr|
            puts " + #{arr[0]}: #{arr[1]}"
          end
        #when :unchanged
        #  puts "Unchanged"
        #  v.each do |arr|
        #    puts "   #{arr[0]}: #{arr[1]}"
        #  end
        when :ssm_only
          puts "Deleted"
          v.each do |arr|
            puts " - #{arr[0]}: #{arr[1]}"
          end
        end
      end
    end

    def diff_print_restore prefix="config/testing"
      prefix_offset = prefix.split('/').length
      diff.each do |k, v|
        case k
        when :update
          puts "Updates"
          v.each do |arr|
            puts " ~ #{arr[0].split('/')[(prefix_offset+3)..-1].join('.')}: #{arr[1].reverse.join(' => ')}"
          end
        when :add
          puts "Removals"
          v.each do |arr|
            puts " - #{arr[0].split('/')[(prefix_offset+3)..-1].join('.')}: #{arr[1]}"
          end
        #when :unchanged
        #  puts "Unchanged"
        #  v.each do |arr|
        #    puts "   #{arr[0]}: #{arr[1]}"
        #  end
        when :ssm_only
          puts "Added"
          v.each do |arr|
            puts " + #{arr[0].split('/')[(prefix_offset+3)..-1].join('.')}: #{arr[1]}"
          end
        end
      end
    end

    def to_params prefix="config/testing"
      ret = Hash.new
      @data.each do |config|
        ret["/#{prefix}/#{config.environment}/#{config.filename}/#{config.key}"] = config.value
      end
      ret
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
    def initialize filename, options={}
      @raw_data = YAML.load_file(filename)
      super
    end
  end

  class PropertyLoader < BaseLoader
    def initialize filename, options={}
      @raw_data = IniFile.load(filename)['global']
      super
    end
  end

  class FileFactory
    class << self
      def load(filename, options={})
        case File.extname(filename)
        when /\.ya?ml|\.config/
          YAMLLoader.new(filename, options)
        when /\.properties/
          PropertyLoader.new(filename, options)
        else
          raise ArgumentError.new("#{filename} is not a supported file type")
        end
      end
    end
  end

  class RestoreFileFromSSM
    def initialize environment, filename, prefix='/config/testing'
      @environment = environment
      @filename = filename
      @prefix = prefix
    end

    def to_params
      request_path = @prefix + '/' + @environment + '/' + @filename + '/'
      resp = Array.new
      SSMClient.instance.client.get_parameters_by_path(path: request_path, recursive: true).each do |response|
        resp += response.to_h[:parameters]
      end
      resp
    end

    def to_filetype
      case File.extname(@filename)
      when /\.ya?ml|\.config/
        to_yaml.to_yaml
      when /\.properties/
        to_properties.join("\n")
      else
        raise ArgumentError.new("#{@filename} is not a supported file type")
      end
    end

    def save!
      File.open(@filename, 'w') {|file| file.write(to_filetype)}
    end

    def to_properties
      prefix_offset = @prefix.split('/').length
      res = Array.new
      to_params.each do |parameter|
        filename = parameter[:name].split('/')[prefix_offset+1]
        raise RuntimeError.new("#{@filename} != #{filename}") if @filename != filename
        environment = parameter[:name].split('/')[prefix_offset]
        raise RuntimeError.new("#{@environment} != #{environment}") if @environment != environment
        arr = parameter[:name].split('/')[(prefix_offset+2)..-1]
        raise ArgumentError.new "I don't know what to do with #{arr.inspect} in a properties file" if arr.size > 1
        res << "#{arr.first} = #{parameter[:value]}"
      end
      res
    end

    def to_yaml
      res = Hash.new
      prefix_offset = @prefix.split('/').length
      to_params.each do |parameter|
        filename = parameter[:name].split('/')[prefix_offset+1]
        raise RuntimeError.new("#{@filename} != #{filename}") if @filename != filename
        environment = parameter[:name].split('/')[prefix_offset]
        raise RuntimeError.new("#{@environment} != #{environment}") if @environment != environment
        arr = parameter[:name].split('/')[(prefix_offset+2)..-1]
        arr << parameter[:value]
        hsh = arr.reverse.inject do |mem, var|
          if var =~ /^[-+]?[0-9]([0-9]*)?$/
            [ mem ]
          else
            { var => mem }
          end
        end
        res = Helpers.deep_merge(res, hsh)
      end
      res
    end
  end
end


