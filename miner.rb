require "socket"

class Server
  attr_reader :ip
  attr_reader :port

  def initialize(ip, port)
    @ip = ip
    @port = port
  end

  def connect
    TCPSocket.new(@ip, @port)
  end
end

def ping(server)
  begin
    socket = server.connect
    socket.write "ping"
    resp = socket.recv 1024
    puts "Pinged #{server} - recvd response:\n#{resp}"
    return true
  rescue Exception => e
    puts "ping and fail w/ #{e}"
    return false
  end
end

START_PORT = 8000
port = START_PORT
known_servers = []
server = nil
loop do
  server = Server.new("localhost", port)
  exists = ping server
  if exists
    port += 1
    known_servers.push(server)
    puts "Known nodes: #{known_servers}"
  else
    break
  end
end

tcp_server = TCPServer.new(server.ip, server.port)
puts "Server started on #{port}"

def connect(client, data)
  puts "New client: #{client}"

  request = client.readpartial 2048
  puts "Request:"
  puts request
  if request == "ping"
    puts "Ping"
    response = "hi"
  elsif request.start_with?("GET")
    puts "GET Request"
    response = http_html_response(200, "<h1>Status</h1>#{escape_html(data[:known_servers].to_s)}")
  end
  puts "Response:"
  puts response
  client.write response

  STDOUT.flush
  client.close
end

def http_html_response(code, body)
  "HTTP/1.1 #{code}\r\n" +
  "Content-type: text/html\r\n" +
  "\r\n#{body}"
end

def escape_html(text)
  result = ""
  text.split('').each do |c|
    if c == "<"
      c = '&lt'
    elsif c == ">"
      c = '&gt'
    end
    result += c
  end
  result
end

loop do
  STDOUT.flush
  client = tcp_server.accept
  Thread.new do
    connect(client, {
      known_servers: known_servers
    })
  end
end
