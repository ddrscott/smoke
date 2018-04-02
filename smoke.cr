require "http/server"
NUM_COLORS = 24
ANSI_MAP = Array.new(NUM_COLORS) { |i| "\e[48;5;#{232 + i}m " }

class Scene
  property num_dots : Int32

  def initialize(@io : IO, @cols : Int32, @rows : Int32)
    @num_dots = @cols * @rows + @cols
    @dots = Array(Int32).new(@num_dots) { 0 }
    @buffer = Array(Int32).new(@num_dots) { 0 }
  end

  def run
    loop do
      reset_bottom
      blend
      draw
      sleep 0.03
    end
  end

  def reset_bottom
    @cols.times { |x|
      c = rand(NUM_COLORS)
      @dots[@num_dots - x - 1] = c
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

def main
  server = HTTP::Server.new("0.0.0.0", 3000) do |ctx|
    puts ctx.request.query_params.inspect
    ctx.response.content_type = "text/plain"
    Scene.new(io: ctx.response, cols: 80, rows: 25).run
  end

  puts "Listening on http://0.0.0.0:3000"
  server.listen
end

main
