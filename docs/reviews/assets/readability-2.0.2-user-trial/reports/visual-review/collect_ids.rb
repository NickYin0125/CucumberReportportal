require 'net/http'
require 'json'
require 'digest'

ROOT = File.dirname(__FILE__)
BASE = 'http://rp-2607.localhost:18080/api/v1/superadmin_personal'
TOKEN = ENV.fetch('RP_API_KEY')
LAUNCHES = [3847, 3848, 3849, 3850, 3851, 3852].freeze

def get(path, query = {})
  uri = URI(BASE + path)
  uri.query = URI.encode_www_form(query) unless query.empty?
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{TOKEN}"
  response = Net::HTTP.start(uri.host, uri.port, open_timeout: 10, read_timeout: 30) { |http| http.request(request) }
  abort "Read-only request failed: HTTP #{response.code}" unless response.code == '200'
  JSON.parse(response.body)
end

def pages(path, query)
  rows = []
  page = 1
  loop do
    result = get(path, query.merge('page.page' => page, 'page.size' => 200))
    rows.concat(result.fetch('content'))
    break if page >= result.fetch('page').fetch('totalPages')
    page += 1
  end
  rows
end

result = {}
LAUNCHES.each do |launch|
  items = pages('/item', 'filter.eq.launchId' => launch)
  result[launch] = items.map do |item|
    logs = pages('/log', 'filter.eq.item' => item.fetch('id'))
    safe_logs = logs.map do |log|
      message = log.fetch('message', '')
      # Retain IDs and recognized categories, never raw evidence or credentials.
      categories = {
        'http' => /(?:GET|POST|PUT|DELETE|PATCH) \/api\//,
        'assertion' => /Assertion (?:failed|passed)/i,
        'contract' => /contract/i,
        'empty_string' => /empty string/,
        'omitted' => /evidence omitted/,
        'docstring' => /Doc string/,
        'table' => /Data table/i,
        'screenshot' => /screenshot|\.png|image\/png/i,
        'diagnostic' => /diagnostic|non-fatal/i,
        'failure' => /Failure|RuntimeError|TimeoutError/,
        'delta' => /missing in actual|extra in actual|changed:/i
      }.filter_map { |label, pattern| label if message.match?(pattern) }
      log.slice('id', 'time', 'level', 'itemId').merge(
        'categories' => categories,
        'message_sha256' => Digest::SHA256.hexdigest(message),
        'has_attachment' => !log['binaryContent'].nil?,
        'attachment_id' => log.dig('binaryContent', 'id')
      )
    end
    item.slice('id', 'parent', 'path', 'type', 'status', 'hasStats').merge('logs' => safe_logs)
  end
  File.write(File.join(ROOT, 'record-ids.json'), JSON.pretty_generate(result))
  puts "Launch #{launch}: #{items.length} items, #{result[launch].sum { |i| i['logs'].length }} item-scoped logs indexed"
end
