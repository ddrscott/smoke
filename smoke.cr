require "http/server"

def main
  server = HTTP::Server.new("0.0.0.0", 3000) do |ctx|
    puts ctx.request.query_params.inspect
    ctx.response.content_type = "text/plain"
    3.times do |i|
      ctx.response.print "Hello world! #{i}\n"
      ctx.response.flush
      sleep(1)
    end
  end

  puts "Listening on http://0.0.0.0:3000"
  server.listen
end

main
