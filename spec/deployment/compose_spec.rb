# frozen_string_literal: true

require "json"
require "open3"
require "yaml"

RSpec.describe "ReportPortal 26.0.7 Compose contract" do
  root = File.expand_path("../..", __dir__)
  compose = YAML.safe_load_file(File.join(root, "docker-compose.yml"), aliases: true)
  services = compose.fetch("services")

  it "pins every released core image and matching infrastructure without local build contexts" do
    expected = {
      "api" => "reportportal/service-api:5.15.6", "migrations" => "reportportal/migrations:5.15.6",
      "ui" => "reportportal/service-ui:5.15.6", "uat" => "reportportal/service-authorization:5.15.2",
      "index" => "reportportal/service-index:5.15.2", "jobs" => "reportportal/service-jobs:5.15.3",
      "analyzer" => "reportportal/service-auto-analyzer:5.15.6", "postgres" => "postgres:18.6",
      "rabbitmq" => "rabbitmq:4.4.0-management", "opensearch" => "opensearchproject/opensearch:3.9.0"
    }
    expect(services.transform_values { |service| service.fetch("image") }).to include(expected)
    expect(services.values).to all(satisfy { |service| !service.key?("build") && !service.key?("container_name") })
    expect(services.values.map { |service| service.fetch("image") }).not_to include(a_string_ending_with(":latest"))
  end

  it "requires credentials, waits for migrations, and creates the analyzer vhost" do
    %w[api uat jobs].each do |name|
      expect(services.dig(name, "depends_on", "migrations", "condition")).to eq("service_completed_successfully")
      expect(services.dig(name, "environment", "RP_DB_PASS")).to include("POSTGRES_PASSWORD:?")
    end
    expect(services.dig("uat", "environment", "RP_INITIAL_ADMIN_PASSWORD")).to include("RP_INITIAL_ADMIN_PASSWORD:?")
    expect(services.dig("rabbitmq", "environment", "RABBITMQ_DEFAULT_VHOST")).to eq("analyzer")
    expect(File.read(File.join(root, "deploy/compose/rabbitmq.conf")))
      .to include("deprecated_features.permit.queue_master_locator = true")
    expect(services.dig("postgres", "volumes")).to include("postgres:/var/lib/postgresql")
  end

  it "initializes only the rootless analyzer volume before starting its worker" do
    initializer = services.fetch("analyzer-storage-init")
    expect(initializer.fetch("command").join(" ")).to include("chown 65532:65532 /data")
    expect(initializer.fetch("volumes").map { |volume| volume.fetch("source") }).to eq(["analyzer-storage"])
    expect(services.dig("analyzer", "depends_on", "analyzer-storage-init", "condition")).to eq("service_completed_successfully")
  end

  it "publishes only a loopback gateway and isolates persistent data by project" do
    expect(compose.fetch("name")).to eq("reportportal-2607")
    expect(services.fetch("gateway").fetch("ports")).to eq(["127.0.0.1:${RP_COMPOSE_PORT:-28080}:8080"])
    expect(services.reject { |name, _| name == "gateway" }.values).to all(satisfy { |service| !service.key?("ports") })
    expect(services.fetch("gateway").fetch("volumes").join).not_to include("docker.sock")
    expect(compose.fetch("volumes").values).to all(be_nil)
  end

  it "preserves the bucket path, read-only policy, revocation and 30-day retention" do
    route = YAML.safe_load_file(File.join(root, "deploy/compose/traefik.yaml"))
    video = route.dig("http", "routers", "videos")
    expect(video.fetch("rule")).to eq("PathPrefix(`/automation-videos`)")
    expect(video).not_to have_key("middlewares")
    policy = JSON.parse(File.read(File.join(root, "deploy/compose/read-only.json")))
    expect(policy.fetch("Statement").flat_map { |statement| statement.fetch("Action") }).to eq(["s3:GetObject"])
    expect(JSON.parse(File.read(File.join(root, "deploy/compose/private.json"))).fetch("Statement")).to eq([])
    lifecycle = JSON.parse(File.read(File.join(root, "deploy/compose/lifecycle.json")))
    expect(lifecycle.dig("Rules", 0, "Expiration", "Days")).to eq(30)
    expect(services.dig("video-bucket-init", "volumes").join)
      .to include("helm/reportportal-rich-experience/files/reconcile-video-bucket.sh")
    expect(services.dig("gateway", "depends_on", "video-bucket-init", "condition"))
      .to eq("service_completed_successfully")
  end

  it "resolves a real Compose configuration without requiring a daemon or revealing credentials" do
    skip "Docker Compose CLI unavailable" unless system("docker", "compose", "version", out: File::NULL, err: File::NULL)
    environment = %w[POSTGRES_PASSWORD RABBITMQ_PASSWORD MINIO_PASSWORD RP_INITIAL_ADMIN_PASSWORD]
                  .to_h { |key| [key, "synthetic-contract-value"] }
    output, error, status = Open3.capture3(environment, "docker", "compose", "-f", File.join(root, "docker-compose.yml"),
                                          "config", "--format", "json")
    expect(status).to be_success, "Compose configuration failed: #{error}"
    expect(JSON.parse(output).fetch("services").keys).to include("api", "analyzer", "video-bucket-init")
  end
end
