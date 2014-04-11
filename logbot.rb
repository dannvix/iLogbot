require "json"
require "socket"
require "cinch"
require "redis"
require "redis-namespace"

# Redis connection
redis_conn = Redis.new(:thread_safe => true)
redis = Redis::Namespace.new(:iLogbot, redis_conn)

# initialize
nick = (ENV['LOGBOT_NICK'] || "testbot_")
server = (ENV['LOGBOT_SERVER'] || "irc.freenode.net")
channels = (ENV['LOGBOT_CHANNELS'] || '#test56').split /[\s,]+/
channels.each do |chan|
  redis.sadd("irclog:channels", "#{chan}")
end

# plugins
class SendMesgFromUser
  include Cinch::Plugin

  listen_to :post_message, :method => :send_mesg
  def send_mesg (m, channel, mesg)
    Channel(channel).send(mesg)
  end
end

# IRC message handlers
bot = Cinch::Bot.new do
  configure do |conf|
    conf.server = server
    conf.nick = nick
    conf.channels = channels
    conf.verbose = false
    conf.plugins.plugins = [SendMesgFromUser]
  end

  on :message do |mesg|
    date = mesg.time.strftime("%Y-%m-%d")
    if mesg.channel.nil?
      # private message
      redis_key = "server:#{server}:privchat:#{mesg.user.nick}:#{date}"
    else
      # channel message
      redis_key = "server:#{server}:channel:#{mesg.channel}:#{date}"
    end

    redis.rpush(key, {
      :time => mesg.time.strftime("%s.%L"),
      :nick => mesg.user.nick,
      :mesg => mesg.message
    }.to_json)
  end
end

# TCP Server
def MesgServer (ircbot)
  server = TCPServer.new("127.0.0.1", 16667)
  loop do
    Thread.start(server.accept) do |client|
      loop do
        buffer = client.gets.chomp
        if buffer.include?("exit")
          client.close
          break
        end
        next unless buffer.include?("||")
        chnl, mesg = buffer.split("||")
        ircbot.handlers.dispatch(:post_message, nil, chnl, mesg)
        client.close
      end
    end
  end
end

# start
Thread.start { MesgServer(bot) }
bot.start
