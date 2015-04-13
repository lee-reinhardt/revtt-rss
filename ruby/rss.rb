#!/usr/bin/env ruby

require 'syslogger'
require 'http'
require 'nokogiri'
require 'json'
require 'pathname'
require 'open-uri'

class RevttRss

  def initialize
    @path     = File.expand_path('~') + "/.revtt-rss"
    @good     = nil
    @bad      = nil
    @history  = nil
    @logger   = Syslogger.new("revttrss", Syslog::LOG_PID, Syslog::LOG_LOCAL0)

    load_config
  end

  def run
    url = "https://revolutiontt.me/rss.php?feed=dl&cat=#{@config['categories']}&passkey=#{@config['passkey']}"

    req = HTTP.with(cookies).get(url)

    if req.status != 200
      raise "Bad status code '#{req.status}' from site"
    end

    load_shows
    process req.body
  end

  private

    def load_config
      @config = JSON.parse(File.read("#{@path}/config.json"))
    end

    def cookies
      { "Cookie" => "pass=#{@config['pass']}; uid=#{@config['uid']}" }
    end

    def load_shows
      begin
        @history = File.read("#{@path}/history.txt").split("\n")
        @good    = File.read("#{@path}/good.txt").split("\n")
        @bad     = File.read("#{@path}/bad.txt").split("\n")
      rescue
        raise "Failed to read one or more config files"
      end
    end

    def process body
      xml = Nokogiri::XML(body)

      raise "Failed to parse xml" if xml.errors.length > 0

      xml.xpath("//item").each do |item|
        title = item.xpath("title").text
        link  = item.xpath("link").text

        raise "Missing `title` or `link` in xml" if title.empty? or link.empty?

        if is_good title and ! is_bad title and ! in_history title
          @logger.info "downloading #{title}"

          download title, link
          add_to_history title
        end
      end

      if rand(1..25) == 7
        prune_history
      end
    end

    def is_good title
      @good.each do |show|
        return true if /#{show}/.match(title) != nil
      end

      false
    end

    def is_bad title
      @bad.each do |show|
        return true if /#{show}/.match(title) != nil
      end

      false
    end

    def in_history title
      @history.each do |show|
        return true if /#{show}/.match(title) != nil
      end

      false
    end

    def download title, link
      begin
        File.open("#{@config['save_dir']}/#{title}.torrent", "wb") do |saved_file|
          open(link, "rb") do |read_file|
            saved_file.write(read_file.read)
          end
        end
      rescue
        raise "Failed to download file '#{link}'"
      end
    end

    def add_to_history title
      begin
        open("#{@path}/history.txt", "a") do |f|
          f.puts(title)
        end
      rescue
        raise "Failed to add history entry"
      end
    end

    def prune_history
      begin
        history = File.readlines("#{@path}/history.txt")
      rescue
        raise "Failed to open history"
      end

      if history.length <= @config['max_history']
        @logger.info "pruning: not long enough to prune"
        return
      end

      @logger.info "pruning: trimming #{history.length} to #{@config['max_history']}"

      over_ct = history.length - @config["max_history"]

      # remove first over_ct lines from beginning of file
      history.tap { |i| i.shift(over_ct) }

      begin
        open("#{@path}/history.txt", "w+") do |f|
          f.write history.join()
        end
      rescue
        raise "Failed to prune history"
      end
    end
end

# main method
if __FILE__ == $0
  rss = RevttRss.new
  rss.run
end