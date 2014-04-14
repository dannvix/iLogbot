require "json"
require "cinch"
require "redis"
require "redis-namespace"

# Redis connection
redis_conn = Redis.new(:thread_safe => true)
$redis = Redis::Namespace.new(:iLogbot, :redis => redis_conn)

# initialize
$nick = (ENV["LOGBOT_NICK"] || "testbot_")
$server = (ENV["LOGBOT_SERVER"] || "irc.freenode.net")
$channels = (ENV["LOGBOT_CHANNELS"] || "#test56").split /[\s,]+/
$channels.each do |channel|
  $redis.sadd("channels", "#{channel}")
end

# Cinch plugins
class PluginWatchRedisQueue
  include Cinch::Plugin

  # send message to channel/nickname
  listen_to :on_message, :method => :send_message
  def send_message (m, channel, mesg)
    Channel(channel).send(mesg)

    # need to manually push to log
    date = Time.now.strftime("%Y-%m-%d")
    time = Time.now.strftime("%s.%L")
    if channel =~ /#/
      # channel message
      redis_key = "channel:#{channel}:date:#{date}"
    else
      # private message
      $redis.sadd("privchats", "#{channel}")
      redis_key = "privchat:#{channel}:date:#{date}"
    end
    $redis.rpush(redis_key, {
      :time => "#{time}",
      :nick => "#{$nick}",
      :mesg => "#{mesg}"
    }.to_json)
  end
end

# IRC message handlers
bot = Cinch::Bot.new do
  configure do |conf|
    conf.server = $server
    conf.nick = $nick
    conf.channels = $channels
    conf.verbose = false
    conf.plugins.plugins = [PluginWatchRedisQueue]
  end

  on :message do |mesg|
    date = mesg.time.strftime("%Y-%m-%d")
    if mesg.channel.nil?
      # private message
      $redis.sadd("privchats", "#{mesg.user.nick}")
      redis_key = "privchat:#{mesg.user.nick}:date:#{date}"
    else
      # channel message
      redis_key = "channel:#{mesg.channel}:date:#{date}"
    end

    $redis.rpush(redis_key, {
      :time => "#{mesg.time.strftime("%s.%L")}",
      :nick => "#{mesg.user.nick}",
      :mesg => "#{mesg.message}"
    }.to_json)
  end
end

def WatchRedisQueue (ircbot)
  redis_sub_conn = Redis.new(:thread_safe => true)
  redis_sub = Redis::Namespace.new(:iLogbot, :redis => redis_sub_conn)
  begin
    redis_sub.subscribe("mesgqueue") do |on|
      on.subscribe do |channel, subscriptions|
        puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
      end
      on.message do |channel, message|
        item = JSON.parse(message)
        puts "<#{channel}> #{message} (#{item.inspect})"
        # send message via IRC bot
        ircbot.handlers.dispatch(:on_message, nil, item["target"], item["mesg"])
      end
    end
  rescue Redis::BaseConnectionError => error
    puts "Redis error: #{error}, retrying in 1s"
    sleep 1; retry
  end
end

# start
Thread.start { WatchRedisQueue(bot) }
bot.start
