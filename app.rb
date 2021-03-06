require 'sinatra'
require 'faye'
require 'faye/websocket'
require 'json'

Faye::WebSocket.load_adapter('thin')

races = {}

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env, {:ping => 10, :retry => 100})
    ping = nil

    ws.on :open do |event|
      puts "websocket connection open"
      ping = Thread.new do
        loop do
          sleep 20
          ws.ping
        end
      end
    end

    ws.on :message do |event|
      message = JSON.parse(event.data)
      return unless message.class == Hash
      return unless race_id = message['race_id']
      return unless type = message['type']
      if type == 'join'
        unless races[race_id]
        then races[race_id] = [ws]
        else races[race_id] << ws unless races[race_id].index(ws)
        end
      elsif type == 'post'
        user_name = message['user_name']
        comment = message['comment']
        json = JSON.generate({"user_name" => user_name, "comment" => comment})
        races[race_id].each { |sock| sock.send(json) }
      end
    end

    ws.on :close do |event|
      puts "websocket connection closed"
      races.each do |space|
        space.delete(ws) if space.index(ws)
      end
      ws = nil
      Thread::kill(ping)
    end

    ws.rack_response
  else
    if env["REQUEST_PATH"] == "/"
      [200, {}, File.read('./index.html')]
    else
      [404, {}, '']
    end
  end
end
