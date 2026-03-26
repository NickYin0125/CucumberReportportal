# frozen_string_literal: true

Given("ReportPortal HTTP is stubbed") do
  @calls = []
  @start_item_counter = 0

  ENV["RP_ENDPOINT"] = "https://rp.example.com"
  ENV["RP_PROJECT"] = "demo"
  ENV["RP_API_KEY"] = "token"
  ENV["RP_LAUNCH"] = "BDD smoke"
  ENV["RP_CLIENT_JOIN"] = "false"
  ENV["RP_BATCH_SIZE_LOGS"] = "2"
  ENV["RP_FLUSH_INTERVAL"] = "0.1"
  ENV["RP_HTTP_RETRY_ATTEMPTS"] = "1"

  stub_request(:post, "https://rp.example.com/api/v1/demo/launch").to_return do |request|
    @calls << [:start_launch, JSON.parse(request.body)]
    { status: 200, body: '{"id":"launch-1"}' }
  end

  stub_request(:post, %r{\Ahttps://rp\.example\.com/api/v1/demo/item(?:/.*)?\z}).to_return do |request|
    @start_item_counter += 1
    @calls << [:start_item, JSON.parse(request.body)]
    { status: 200, body: { id: "item-#{@start_item_counter}" }.to_json }
  end

  stub_request(:post, "https://rp.example.com/api/v1/demo/log").to_return do |request|
    @calls << [:log_batch, request.body]
    { status: 200, body: '{"responses":[{"message":"ok"}]}' }
  end

  stub_request(:put, %r{\Ahttps://rp\.example\.com/api/v1/demo/item/.*\z}).to_return do |request|
    @calls << [:finish_item, JSON.parse(request.body)]
    { status: 200, body: '{"message":"ok"}' }
  end

  stub_request(:put, "https://rp.example.com/api/v1/demo/launch/launch-1/finish").to_return do |request|
    @calls << [:finish_launch, JSON.parse(request.body)]
    { status: 200, body: '{"message":"ok"}' }
  end
end

When("I replay the NDJSON fixture through the formatter") do
  fake_config = Struct.new(:handlers) do
    def on_event(name, &block)
      handlers[name] = block
    end

    def include(_mod); end
  end.new({})

  formatter = ReportportalCucumber::Cucumber::Formatter.new(fake_config)
  fixture = File.expand_path("../../spec/fixtures/events.ndjson", __dir__)
  File.readlines(fixture, chomp: true).each do |line|
    formatter.ingest_event(JSON.parse(line))
  end
end

Then("the ReportPortal call sequence is correct") do
  expect(@calls.map(&:first)).to eq([
    :start_launch,
    :start_item,
    :start_item,
    :start_item,
    :log_batch,
    :finish_item,
    :finish_item,
    :finish_item,
    :finish_launch
  ])
  expect(@calls.find { |name, _| name == :log_batch }.last).to include("shot.png")
end
