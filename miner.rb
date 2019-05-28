require "securerandom"
require "socket"

START_PORT = 8000
WORDS = [
  "steak", "ethics", "location", "school", "presence", "virus", "unlike",
  "desert", "publicity", "computer", "register", "profit", "plot", "conference",
  "large", "peak", "performance", "country", "kick", "firm", "damn", "enemy",
  "appendix", "exotic", "dedicate", "rubbish", "licence", "incredible",
  "construct", "common", "influence", "elect", "ladder", "modernize", "squash",
  "compliance", "patent", "valley", "load", "toast", "road", "lump", "thigh",
  "steward", "grind", "able", "impress", "network", "experienced", "hero",
  "finger", "island", "precision", "tropical", "fitness", "environmental",
  "society", "approve", "illusion", "persist", "bacon", "intention", "jump",
  "bridge",
]

$known_servers = []
$known_blocks = {}

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

  def serve
    TCPServer.new(@ip, @port)
  end

  def pretty_s
    "#{@ip}:#{@port}"
  end
end

class Block
  attr_reader :id
  attr_reader :time
  attr_reader :message
  attr_reader :author

  def initialize(message, author, id=SecureRandom.uuid, time=Time.new)
    @message = message
    @author = author
    @id = id
    @time = time
  end

  def pretty_s
    "#{@id.split("-")[0]}@#{@author}: #{@message}"
  end

  def to_wire
    us = (@time.to_f * 1000000).to_i
    "#{@id}|#{us}|#{author}|#{@message}"
  end

  def self.from_wire(str)
    parts = str.split("|")
    id = parts[0]
    time = parts[1].to_f / 1000000
    author = parts[2]
    msg = parts[3]
    Block.new(msg, author, id, time)
  end
end

def ping(server)
  begin
    socket = server.connect
    socket.write "OMEGA PING"
    resp = socket.recv 1024
    puts "Pinged #{server} - recvd response:\n#{resp}"
    socket.close
    return true
  rescue Exception => e
    puts "ping and fail w/ #{e}"
    return false
  end
end

def random_sentence
  msg = ""
  num = 2 + rand(6)
  num.times do |i|
    if i != 0
      msg += " "
    end
    msg += WORDS.sample
  end
  msg
end

def connect(client)
  puts "New client: #{client}"

  request = client.readpartial 2048
  puts "Request:"
  puts request
  if request.start_with?("OMEGA")
    lines = request.split("\r\n")
    cmd = lines[0].split(" ")[1]
    if cmd == "PING"
      puts "Ping"
      response = "hi"
    elsif cmd == "PULL"
      puts "Pull"
      blocks = $known_blocks.values.sample(5)
      response = blocks.map { |b| b.to_wire }.join("\r\n")
    end
  elsif request.start_with?("GET")
    puts "GET Request"
    body = ""
    body += "<h2>Known Servers</h2><ul>"
    $known_servers.each { |server| body += "<li>#{escape_html(server.pretty_s)}</li>" }
    body += "</ul>"
    body += "<h2>Known Blocks</h2><ul>"
    for _, block in $known_blocks do
      body += "<li>#{escape_html(block.pretty_s)}</li>"
    end
    body += "</ul>"
    response = http_html_response(200, "<h1>Status</h1>#{body}")
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
  "\r\n" +
  "#{body}"
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

def parse_args(args)
  i = 0
  result = {}
  while i < args.length
    arg = args[i]
    if arg == "-p" || arg == "--port"
      result[:port] = args[i + 1].to_i
      i += 1
    elsif arg == "-k" || arg == "--known"
      $known_servers.push(Server.new(args[i + 1], args[i + 2].to_i))
      i += 2
    elsif arg == "-m" || arg == "--mine-delay"
      result[:mine_delay] = args[i + 1].to_i
      i += 1
    else
      puts "Unknown command line argument: #{arg}"
      exit 1
    end
    i += 1
  end
  result
end

def find_port
  port = START_PORT
  loop do
    server = Server.new("localhost", port)
    exists = ping server
    if exists
      port += 1
      $known_servers.push(server)
    else
      break
    end
  end
  port
end

def server_thread(server)
  Thread.new do
    tcp_server = server.serve
    puts "Server started on port #{server.port}"
    loop do
      STDOUT.flush
      client = tcp_server.accept
      Thread.new do
        connect(client)
      end
    end
  end
end

def miner_thread(server, mine_delay)
  if mine_delay == 0 then return end
  Thread.new do
    loop do
      block = Block.new(random_sentence(), server.pretty_s)
      $known_blocks[block.id] = block
      puts "Mined block: #{block.pretty_s}"
      STDOUT.flush
      sleep mine_delay
    end
  end
end

def pull_thread
  Thread.new do
    loop do
      begin
        server = $known_servers.sample
        puts "[PULL] Pulling from #{server}..."
        socket = server.connect
        socket.write "OMEGA PULL"
        response = socket.recv 4096
        puts "[PULL] recvd response:\n#{response}"
        socket.close

        lines = response.split("\r\n")
        lines.each do |line|
          block = Block.from_wire(line)
          if not $known_blocks.has_key?(block.id)
            $known_blocks[block.id] = block
          end
        end
      rescue Exception => e
        puts "[PULL] failed w/:\n#{e}"
      end
      STDOUT.flush
      sleep 10
    end
  end
end

def main
  options = parse_args(ARGV)
  port = options[:port] || find_port()
  mine_delay = options[:mine_delay] || 5
  server = Server.new("localhost", port)

  threads = [
    server_thread(server),
    miner_thread(server, mine_delay),
    pull_thread(),
  ]
  for t in threads
    t.join
  end
end

main
