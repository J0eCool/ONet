require "socket"

def ping server, port
  begin
    socket = TCPSocket.new server, port
    socket.write "ping"
    resp = socket.recv 1024
    puts "Pinged #{server}:#{port} - recvd response:\n#{resp}"
    return true
  rescue Exception => e
    puts "ping and fail w/ #{e}"
    return false
  end
end

START_PORT = 8000
port = START_PORT
loop do
  exists = ping 'localhost', port
  if exists
    port += 1
  else
    break
  end
end

server = TCPServer.new("localhost", port)
puts "Server started on #{port}"

def connect(client)
  puts "New client: #{client}"

  request = client.readpartial 2048
  puts "Request:"
  puts request
  if request == "ping"
    puts "oh hey dere we gots a peeng"
    client.write "hi"
  end

  STDOUT.flush
  client.close
end

loop do
  STDOUT.flush
  client = server.accept
  Thread.new { connect client }
end
