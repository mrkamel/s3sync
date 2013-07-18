#!/usr/bin/ruby

require "rubygems"
require "bundler/setup"
require "facets"
require "optparse"
require "aws/s3"
require "yaml"

module Retry
  def self.task(num = 3, delay = 30) 
    num.times do |i| 
      begin
        return yield
      rescue => e
        raise e if i + 1 == num 

        sleep delay
      end 
    end 
  end 
end

module AWS 
  module S3
    class Bucket
      def self.all_objects(name, options = {}) 
        res = []

        marker = nil 

        loop do
          current = Retry.task { AWS::S3::Bucket.objects name, options.merge(:marker => marker) }

          return res if current.size.zero?

          res += current

          marker = current.last.key
        end
      end 
    end 
  end 
end

def s3sync(bucket, path, options = {}) 
  AWS::S3::DEFAULT_HOST.replace options[:endpoint] if options[:endpoint]

  AWS::S3::Base.establish_connection! :access_key_id => options[:access_key], :secret_access_key => options[:secret_key]

  AWS::S3::Bucket.all_objects(bucket, options.slice(:prefix)).each do |object|
    file = File.expand_path(object.key.gsub(/^\/+/, ""), path)

    FileUtils.mkdir_p File.dirname(file)

    if !File.exists?(file) || File.size(file) != object.size
      puts "Downloading #{object.key} -> #{file} [#{object.size} bytes]"

      if value = Retry.task { object.value }
        open(file, "wb") { |stream| stream.write value }
      end 
    else
      puts "Skipping #{file}"
    end 
  end 
end

options = {}

option_parser = OptionParser.new do |parser|
  parser.on "--config PATH" do |config|
    options[:config] = config
  end 

  parser.on "--bucket BUCKET" do |bucket|
    options[:bucket] = bucket
  end 

  parser.on "--prefix PREFIX" do |prefix|
    options[:prefix] = prefix
  end 

  parser.on "--path PATH" do |path|
    options[:path] = path
  end 
end

option_parser.parse!

raise "You did not specify a path to your config file" if options[:config].nil?

options = options.merge(YAML.load_file(options[:config]).symbolize_keys)

raise "You did not specify an access key" if options[:access_key].nil?
raise "You did not specify a secret key" if options[:secret_key].nil?
raise "You did not specify a bucket" if options[:bucket].nil?
raise "You did not specify a path" if options[:path].nil?

s3sync options[:bucket], options[:path], options.slice(:access_key, :secret_key, :prefix, :endpoint)

