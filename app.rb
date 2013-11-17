require 'sinatra'
require 'faye'
require 'faye/websocket'
require 'json'

Faye::WebSocket.load_adapter('thin')

races = {}

App = lambda do |env|
  if Faye::WebSocket.websocket?(env)
    ws = Faye::WebSocket.new(env)
    #ws = Faye::WebSocket.new(env, :ping => 5, :retry => 100)

    ws.on :open do |event|
      puts "websocket connection open"
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
      elsif type == 'comment'
        races[race_id].each do |sock|
          sock.send(message['comment'])
        end
      end
    end

    ws.on :close do |event|
      puts "websocket connection closed"
      races.each do |space|
        space.delete(ws) if space.index(ws)
      end
      ws = nil
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
