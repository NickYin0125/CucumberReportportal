# frozen_string_literal: true

require "json"
require "cgi"
require "open3"
require "socket"
require "uri"

EVIDENCE = File.expand_path(ENV.fetch("M3C_LIVE_EVIDENCE"))
SANDBOX = File.join(EVIDENCE, "sandbox")
PORT = Integer(ENV.fetch("M3C_LIVE_REFERENCE_PORT", "8883"))
REPO_META = File.join(EVIDENCE, "fixture-repo.json")
RUN_META = File.join(EVIDENCE, "run-summary.json")

# @param socket [TCPSocket]
# @param status [String]
# @param content_type [String]
# @param body [String]
# @return [void]
def response(socket, status, content_type, body, head: false)
  socket.write("HTTP/1.1 #{status}\r\nContent-Type: #{content_type}\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n")
  socket.write(body) unless head || socket.closed?
end

# @param title [String]
# @param body [String]
# @return [String]
def page(title, body)
  "<!doctype html><meta charset=\"utf-8\"><title>#{title}</title><style>body{font:16px system-ui;max-width:900px;margin:3rem auto;padding:0 1rem;color:#24323b}pre{white-space:pre-wrap;background:#f4f6f7;padding:1rem}mark{background:#ffe08a}</style><h1>#{title}</h1>#{body}"
end

# @param socket [TCPSocket]
# @return [void]
def handle(socket)
  request = socket.gets("\r\n")
  return unless request

  method, target, = request.split(" ", 3)
  headers = {}
  while (line = socket.gets("\r\n")) && line != "\r\n"
    key, value = line.split(":", 2)
    headers[key.downcase] = value.to_s.strip if key
  end
  uri = URI.parse(target)
  puts "#{method} #{uri.path}" if %w[GET HEAD].include?(method)
  return response(socket, "405 Method Not Allowed", "text/plain", "", head: method == "HEAD") unless %w[GET HEAD].include?(method)

  status, type, body = case uri.path
                       when "/health"
                         ["200 OK", "application/json", JSON.generate(status: "ready", scope: "synthetic fixture references only")]
                       when %r{\A/source/([0-9a-f]{40})/(.+)\z}
                         commit, encoded_path = Regexp.last_match.captures
                         meta = JSON.parse(File.read(REPO_META))
                         path = encoded_path.split("/").map { |part| URI::DEFAULT_PARSER.unescape(part) }.join("/")
                         allowed = meta.fetch("files")
                         actual_head, head_status = Open3.capture2("git", "-C", SANDBOX, "rev-parse", "HEAD")
                         if !head_status.success? || commit != meta.fetch("commit") || actual_head.strip != commit || !allowed.include?(path)
                           ["404 Not Found", "text/plain", "Not found"]
                         else
                           line = Integer(URI.decode_www_form(uri.query.to_s).to_h.fetch("line", "1")) rescue 1
                           text, _stderr, show_status = Open3.capture3("git", "-C", SANDBOX, "show", "#{commit}:#{path}")
                           raise "Synthetic source snapshot unavailable" unless show_status.success?

                           rendered = text.lines.each_with_index.map do |content, index|
                             safe = CGI.escapeHTML(content)
                             index + 1 == line ? "<mark>#{index + 1}: #{safe}</mark>" : "#{index + 1}: #{safe}"
                           end.join
                           ["200 OK", "text/html; charset=utf-8", page("Immutable synthetic source at #{commit[0, 12]}", "<p>Fixture snapshot only. Highlighted line #{line}.</p><pre>#{rendered}</pre>")]
                         end
                       when %r{\A/runs/([A-Za-z0-9._-]+)\z}
                         id = Regexp.last_match(1)
                         run_path = File.join(EVIDENCE, "runs", "#{id}.json")
                         if File.file?(run_path) || File.file?(RUN_META)
                           run_path = RUN_META unless File.file?(run_path)
                           run = JSON.parse(File.read(run_path))
                           if id == run.fetch("acceptance_run_id")
                             ["200 OK", "application/json", JSON.pretty_generate(run.merge("classification" => "LOCAL CI-STYLE DEMO; not an external CI provider"))]
                           else
                             ["404 Not Found", "text/plain", "Unknown run"]
                           end
                         else
                           ["404 Not Found", "text/plain", "Run record not ready"]
                         end
                       when %r{\A/cases/(.+)\z}
                         case_id = URI::DEFAULT_PARSER.unescape(Regexp.last_match(1))
                         if case_id.match?(/\ACASE-UI\/[0-9]+\z/)
                           ["200 OK", "text/html; charset=utf-8", page("Synthetic TMS reference", "<p>Case <strong>#{case_id}</strong></p><p>This is a fixture reference, not an external test-management integration.</p>")]
                         else
                           ["404 Not Found", "text/plain", "Unknown synthetic case"]
                         end
                       else
                         ["404 Not Found", "text/plain", "Not found"]
                       end
  response(socket, status, type, body, head: method == "HEAD")
ensure
  socket&.close
end

daemon_mode = ARGV.delete("--daemon")
if daemon_mode
  Process.daemon(true, false)
  $stdout.reopen(File.join(EVIDENCE, "reference-server.log"), "a")
  $stderr.reopen($stdout)
end
$stdout.sync = true

server = TCPServer.new("127.0.0.1", PORT)
File.write(File.join(EVIDENCE, "reference-server-ready.json"), JSON.pretty_generate(host: "127.0.0.1", port: PORT, pid: Process.pid, lifecycle: daemon_mode ? "detached daemon" : "foreground", status: "ready", scope: "fixture source, this run record, synthetic cases only") + "\n")
loop do
  Thread.new(server.accept) { |socket| handle(socket) }
end
