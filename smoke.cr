require "http/server"
require "option_parser"

FRAME_SLEEP = 1.0/15 # 15 fps
NUM_COLORS = 24
ANSI_MAP = Array.new(NUM_COLORS) { |i| "\e[48;5;#{232 + i}m " }

class Scene
  property num_dots : Int32

  def initialize(@io : IO, @cols : Int32, @rows : Int32, @fps : Int32)
    @num_dots = @cols * @rows + @cols
    @dots = Array(Int32).new(@num_dots) { 0 }
    @buffer = Array(Int32).new(@num_dots) { 0 }
  end

  def run
    loop do
      reset_bottom
      blend
      draw
      sleep 1.0/@fps
    end
  end

  # Fill bottom with brightest or darkest color
  def reset_bottom
    @cols.times { |x|
      @dots[@num_dots - x - 1] = rand(2) * NUM_COLORS
    }
  end

  def value_at(idx, offset)
    pos = idx + offset
    (pos >= 0 && pos < @num_dots) ? @dots[pos] : @dots[idx]
  end

  def blend
    @num_dots.times do |i|
      above = value_at(i, @cols)
      below = value_at(i, -@cols)
      right = value_at(i, 1)
      left = value_at(i, -1)

      @buffer[i - @cols] = (above + below + left + right + @dots[i]) / 5 
    end
    # swap buffers
    @buffer, @dots = @dots, @buffer
  end

  def draw
    chars = [] of String
    @rows.times do |y|
      @cols.times do |x|
        dot = @dots[y * @cols + x]
        chars << (ANSI_MAP[dot] || ANSI_MAP.last)
      end
      chars << "\n" unless y == @rows - 1
    end
    @io.print "\e[2J\e[0;0H#{chars.join}\e[#{@rows};#{@cols}H\e[0m"
    @io.flush
  end
end

def run_http_server(host, port, default_cols : Int32, default_rows : Int32)
  server = HTTP::Server.new(host, port) do |ctx|
    if ctx.request.headers.fetch("Accept", "") =~ /html/
      # Redirect to source code if it's a browser request.
      ctx.response.status_code = 302
      ctx.response.headers["Location"] = "https://github.com/ddrscott/smoke"
    else
      # parse cols and rows
      cols = ctx.request.query_params.fetch("cols", default_cols).to_i
      rows = ctx.request.query_params.fetch("rows", default_rows).to_i

      # Due to bandwidth, we cap at 15 FPS
      Scene.new(io: ctx.response, cols: cols, rows: rows, fps: 15).run
    end
  end

  puts "Listening on http://#{host}:#{port}"
  server.listen
end

server = false
host = "0.0.0.0"
port = 3000
cols = 60
rows = 15
fps = 15

OptionParser.parse! do |parser|
  parser.banner = "Usage: smoke [arguments]"
  parser.on("-h HOST", "--host=HOST", "server bind address") do |val|
    host = val
    server = true
  end
  parser.on("-p PORT", "--port=PORT", "server bind port") do |val|
    port = val.to_i
    server = true
  end
  parser.on("-c COLS", "--cols=COLS", "number of columns") { |val| cols = val.to_i }
  parser.on("-r ROWS", "--rows=NAME", "number of rows") { |val| rows = val.to_i }
  parser.on("--fps=FPS", "frame per second for stdout. Server mode capped at 15") { |val| fps = val.to_i }
  parser.on("--help", "Show this help") do
    puts parser
    exit(0)
  end
end

# Handle Ctrl+C and kill signal.
# Needed for hosting this process in a docker as the entry point command.
# Thanks: https://github.com/bcardiff/miniserver/blob/master/src/miniserver.cr
Signal::INT.trap { puts "Caught Ctrl+C..."; exit }
Signal::TERM.trap { puts "Caught kill..."; exit }

if server
  run_http_server(host, port, default_cols: cols, default_rows: rows)
else
  Scene.new(io: STDOUT, cols: cols, rows: rows, fps: fps).run
end
