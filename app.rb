# encoding: utf-8
Encoding.default_internal = "utf-8"
Encoding.default_external = "utf-8"

require "json"
require "time"
require "date"
require "sinatra/base"
require "sinatra/async"
require "redis"
require "redis-namespace"
require "eventmachine"

redis_conn = Redis.new(:thread_safe => true)
$redis = Redis::Namespace.new(:iLogbot, redis_conn)

module Logbot
  class App < Sinatra::Base
    configure do
      set :protection, :except => :frame_options
    end

    get "/" do
      @channels = $redis.smembers("channels")
      @privchats = $redis.smembers("privchats")
      erb :index
    end

    get "/channel/:channel/?:date?" do |channel, date|
      date = "today" if date.nil?
      case date
        when "today"
          @date = Time.now.strftime("%F")
        when "yesterday"
          @date = (Time.now - 86400).strftime("%F")
        else
          # date in "%Y-%m-%d" format (e.g. 2013-01-01)
          @date = date
      end

      @channel = channel
      @mesgs = $redis.lrange("channel:##{channel}:date:#{@date}", 0, -1)
      @mesgs = @mesgs.map do |mesg|
        mesg = JSON.parse(mesg)
        if mesg["mesg"] =~ /^\u0001ACTION (.*)\u0001$/
          mesg["mesg"].gsub!(/^\u0001ACTION (.*)\u0001$/, "\\1")
          mesg["action"] = true
        else
          mesg["action"] = nil
        end
        mesg
      end
      erb :channel
    end

    post "/channel/:channel" do |channel|
      $redis.publish("mesgqueue", {
          :target => "##{channel}",
          :mesg => "#{params[:mesg]}",
          :action => false
        }.to_json)
      nil
    end

    get "/privchat/:channel/?:date?" do |channel, date|
      date = "today" if date.nil?
      case date
        when "today"
          @date = Time.now.strftime("%F")
        when "yesterday"
          @date = (Time.now - 86400).strftime("%F")
        else
          # date in "%Y-%m-%d" format (e.g. 2013-01-01)
          @date = date
      end

      @channel = channel
      @mesgs = $redis.lrange("privchat:#{channel}:date:#{@date}", 0, -1)
      @mesgs = @mesgs.map do |mesg|
        mesg = JSON.parse(mesg)
        if mesg["mesg"] =~ /^\u0001ACTION (.*)\u0001$/
          mesg["mesg"].gsub!(/^\u0001ACTION (.*)\u0001$/, "\\1")
          mesg["action"] = true
        else
          mesg["action"] = nil
        end
        mesg
      end
      erb :privchat
    end

    post "/privchat/:channel" do |channel|
      $redis.publish("mesgqueue", {
          :target => "#{channel}",
          :mesg => "#{params[:mesg]}",
          :action => false
        }.to_json)
      nil
    end
  end
end


module Comet
  class App < Sinatra::Base
    register Sinatra::Async

    get %r{/poll/channel/(.*)/([\d\.]+)} do |channel, time|
      date = Time.at(time.to_f).strftime("%Y-%m-%d")
      mesgs = $redis.lrange("channel:##{channel}:date:#{date}", -10, -1).map { |mesg| ::JSON.parse(mesg) }
      if (not mesgs.empty?) && mesgs[-1]["time"] > time
        return mesgs.select { |mesg| mesg["time"] > time }.to_json
      end

      EventMachine.run do
        n, timer = 0, EventMachine::PeriodicTimer.new(0.5) do
          mesgs = $redis.lrange("channel:##{channel}:date:#{date}", -10, -1).map { |msg| ::JSON.parse(msg) }
          if (not mesgs.empty?) && mesgs[-1]["time"] > time || n > 120
            timer.cancel
            return mesgs.select { |mesg| mesg["time"] > time }.to_json
          end
          n += 1
        end
      end
    end

    get %r{/poll/privchat/(.*)/([\d\.]+)} do |channel, time|
      date = Time.at(time.to_f).strftime("%Y-%m-%d")
      mesgs = $redis.lrange("privchat:#{channel}:date:#{date}", -10, -1).map { |mesg| ::JSON.parse(mesg) }
      if (not mesgs.empty?) && mesgs[-1]["time"] > time
        return mesgs.select { |mesg| mesg["time"] > time }.to_json
      end

      EventMachine.run do
        n, timer = 0, EventMachine::PeriodicTimer.new(0.5) do
          mesgs = $redis.lrange("privchat:#{channel}:date:#{date}", -10, -1).map { |msg| ::JSON.parse(msg) }
          if (not mesgs.empty?) && mesgs[-1]["time"] > time || n > 120
            timer.cancel
            return mesgs.select { |mesg| mesg["time"] > time }.to_json
          end
          n += 1
        end
      end
    end
  end
end
