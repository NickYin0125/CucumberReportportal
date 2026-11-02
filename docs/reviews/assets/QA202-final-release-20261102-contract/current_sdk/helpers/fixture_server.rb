# frozen_string_literal: true

require "socket"
require "timeout"
require "json"
require "uri"

module CurrentSDK
  # Loopback-only, serial, bounded test fixture, not a production HTTP server.
  class FixtureServer
    MAX_HEADERS = 16 * 1024
    MAX_BODY = 8 * 1024
    PAGE = <<~HTML.freeze
      <!doctype html><html lang="en"><meta charset="utf-8">
      <title>Practice Studio | SDK fixture</title>
      <style>body{background:#f4eee3;color:#173d37;font:20px Georgia;padding:8vh 12vw}
      main{max-width:700px}h1{font-size:52px}input,button{font:inherit;padding:12px}
      button{background:#173d37;color:white;border:0}output{display:block;margin-top:24px}</style>
      <main><p>LOCAL AUTOMATION LAB</p><h1>Practice Studio</h1>
      <p>Practice a word, then save your session.</p>
      <form><label for="word">Practice word</label><input id="word" required maxlength="80">
      <button>Save practice</button></form><output role="status">Ready to practice</output></main>
      <script>document.querySelector('form').addEventListener('submit',event=>{
      event.preventDefault();document.querySelector('output').textContent=
      'Saved: '+document.querySelector('input').value;});</script></html>
    HTML

    attr_reader :url

    def start
      @server = TCPServer.new("127.0.0.1", 0)
      @url = "http://127.0.0.1:#{@server.addr[1]}"
      @thread = Thread.new do
        loop do
          socket = @server.accept
          begin
            Timeout.timeout(2) { serve(socket) }
          rescue Timeout::Error, IOError, SystemCallError
            # Slow/disconnected clients do not keep the fixture alive indefinitely.
          ensure
            socket.close
          end
        end
      rescue IOError, Errno::EBADF
        nil
      end
      self
    end

    def stop
      @server&.close
      @thread&.join(3) || raise("Fixture did not stop within 3 seconds")
    end

    private

    def serve(socket)
      headers = +""
      until headers.end_with?("\r\n\r\n")
        headers << socket.readpartial(1)
        return respond(socket, 413, error: "headers_too_large") if headers.bytesize > MAX_HEADERS
      end
      first, *lines = headers.split("\r\n")
      method, target, protocol = first.split(" ")
      return respond(socket, 400, error: "bad_request") unless protocol == "HTTP/1.1"

      fields = lines.to_h { |line| line.split(":", 2).map(&:strip) }
      fields = fields.transform_keys(&:downcase)
      return respond(socket, 400, error: "unsupported_transfer_encoding") if fields["transfer-encoding"]

      length = Integer(fields.fetch("content-length", "0"), 10)
      return respond(socket, 400, error: "bad_length") if length.negative?
      return respond(socket, 413, error: "body_too_large") if length > MAX_BODY

      body = socket.read(length)
      return respond(socket, 400, error: "short_body") unless body && body.bytesize == length

      route(socket, method, URI.parse(target), body)
    rescue JSON::ParserError, URI::InvalidURIError, ArgumentError
      respond(socket, 400, error: "invalid_json_or_request")
    end

    def route(socket, method, uri, body)
      if method == "GET" && uri.path == "/"
        return respond(socket, 200, PAGE, type: "text/html; charset=utf-8")
      end
      return respond(socket, 200, healthy: true) if method == "GET" && uri.path == "/health"
      return respond(socket, 404, error: "not_found") unless uri.path == "/api/practice"

      if method == "GET"
        word = URI.decode_www_form(uri.query.to_s).to_h.fetch("word", "persevere")
        return respond(socket, 200, word: word, length: word.length, kind: "practice")
      end
      return respond(socket, 405, error: "method_not_allowed") unless method == "POST"

      data = JSON.parse(body)
      word = data.is_a?(Hash) ? data["word"] : nil
      return respond(socket, 400, error: "word_required") unless word.is_a?(String) && !word.strip.empty? && word.length <= 80

      respond(socket, 201, word: word, saved: true)
    end

    def respond(socket, status, payload = nil, type: "application/json", **values)
      content = payload || JSON.generate(values)
      reason = {200 => "OK", 201 => "Created", 400 => "Bad Request", 404 => "Not Found",
                405 => "Method Not Allowed", 413 => "Payload Too Large"}.fetch(status)
      socket.write("HTTP/1.1 #{status} #{reason}\r\nContent-Type: #{type}\r\n" \
                   "Content-Length: #{content.bytesize}\r\nConnection: close\r\n\r\n#{content}")
    end
  end
end
