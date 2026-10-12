# frozen_string_literal: true

require "json"
require "open3"
require "yaml"

RSpec.describe "ReportPortal 26.0.5 chart contract" do
  root = File.expand_path("../..", __dir__)
  chart_dir = File.join(root, "helm/reportportal-rich-experience")
  chart = YAML.safe_load_file(File.join(chart_dir, "Chart.yaml"))
  lock = YAML.safe_load_file(File.join(chart_dir, "Chart.lock"), permitted_classes: [Time])

  def render_chart(directory, profile)
    output, error, status = Open3.capture3("helm", "template", "reportportal-latest", directory,
                                          "--namespace", "reportportal-latest", "-f", File.join(directory, profile))
    raise "Chart rendering failed: #{error}" unless status.success?

    YAML.load_stream(output).compact
  end

  it "pins the server version independently of the Ruby SDK and locks its upstream dependency" do
    expect(chart.fetch("version")).to eq("1.2.0-rc.2")
    expect(chart.fetch("appVersion")).to eq("26.0.5")
    expect(chart.fetch("dependencies")).to eq([
      { "name" => "reportportal", "version" => "26.8.12", "repository" => "https://k8s.reportportal.io/" }
    ])
    expect(lock.fetch("dependencies")).to eq(chart.fetch("dependencies"))
  end

  it "renders the official component versions, including the new database and broker" do
    documents = render_chart(chart_dir, "values-local-latest.yaml")
    images = documents.flat_map do |entry|
      spec = entry.dig("spec", "template", "spec") || {}
      Array(spec["containers"]).map { |container| container.fetch("image") }
    end
    expect(images).to include("reportportal/service-api:5.15.4", "reportportal/service-ui:5.15.5",
                              "reportportal/service-authorization:5.15.1", "reportportal/service-index:5.15.1",
                              "reportportal/service-jobs:5.15.2", "reportportal/service-auto-analyzer:5.15.5",
                              "reportportal/migrations:5.15.4", "docker.io/postgres:18.4",
                              "docker.io/rabbitmq:4.3.4-management", "opensearchproject/opensearch:3.8.0")
  end

  it "keeps the new ingress and database service isolated from the old namespace" do
    documents = render_chart(chart_dir, "values-local-latest.yaml")
    ingresses = documents.select { |entry| entry["kind"] == "Ingress" }
    expect(ingresses.length).to eq(2)
    expect(ingresses.flat_map { |entry| entry.dig("spec", "rules").map { |rule| rule["host"] } }.uniq)
      .to eq(["rp-latest.localhost"])
    services = documents.select { |entry| entry["kind"] == "Service" }.map { |entry| entry.dig("metadata", "name") }
    expect(services).to include("reportportal-latest-postgresql", "reportportal-latest-rabbitmq", "reportportal-latest-minio")
    volumes = documents.select { |entry| entry["kind"] == "StatefulSet" }
    expect(volumes.flat_map { |entry| Array(entry.dig("spec", "template", "spec", "volumes")) }
                  .filter_map { |volume| volume.dig("persistentVolumeClaim", "claimName") })
      .not_to include("data-reportportal-postgresql-0", "data-reportportal-rabbitmq-0", "reportportal-minio")
  end

  it "aligns upstream and subchart secret keys without emitting administrator credentials" do
    documents = render_chart(chart_dir, "values-local-latest.yaml")
    references = documents.flat_map do |entry|
      Array(entry.dig("spec", "template", "spec", "containers")).flat_map do |container|
        Array(container["env"]).filter_map { |env| env.dig("valueFrom", "secretKeyRef") }
      end
    end
    runtime_keys = references.select { |ref| ref["name"] == "rp-runtime-auth" }.map { |ref| ref["key"] }
    expect(runtime_keys).to include("postgresql-password", "rabbitmq-password", "access-key", "secret-key", "superadmin-password")
    minio = documents.find { |entry| entry["kind"] == "Deployment" && entry.dig("metadata", "name") == "reportportal-latest-minio" }
    expect(minio.dig("spec", "template", "spec", "volumes").find { |volume| volume["name"] == "minio-credentials" }
                .dig("secret", "secretName")).to eq("rp-runtime-auth")
    files = minio.dig("spec", "template", "spec", "containers", 0, "env")
                 .select { |env| %w[MINIO_ROOT_USER_FILE MINIO_ROOT_PASSWORD_FILE].include?(env["name"]) }
                 .map { |env| File.basename(env.fetch("value")) }
    expect(files).to contain_exactly("root-user", "root-password")
    expect(documents.select { |entry| entry["kind"] == "Secret" }.map { |entry| entry.dig("metadata", "name") })
      .not_to include("reportportal-uat-init-password", "reportportal-latest-video-bucket", "reportportal-latest-postgresql")
  end

  it "does not create a public video bucket or plaintext administrator secret in the production example" do
    documents = render_chart(chart_dir, "values-production.example.yaml")
    expect(documents.map { |entry| entry.dig("metadata", "name") }.grep(/video-bucket/)).to be_empty
    ingresses = documents.select { |entry| entry["kind"] == "Ingress" }
    expect(ingresses.length).to eq(1)
    expect(ingresses.first.dig("spec", "tls", 0, "secretName")).to eq("reportportal-tls")
    expect(documents.select { |entry| entry["kind"] == "Secret" }.map { |entry| entry.dig("metadata", "name") })
      .not_to include("reportportal-uat-init-password")
  end

  it "bootstraps the ReportPortal vhost without dropping the required RabbitMQ 4.3 compatibility setting" do
    documents = render_chart(chart_dir, "values-local-latest.yaml")
    config = documents.find { |entry| entry["kind"] == "ConfigMap" && entry.dig("metadata", "name") == "reportportal-latest-rabbitmq-config" }
    expect(config.fetch("data").fetch("rabbitmq.conf")).to include("default_vhost = analyzer", "deprecated_features.permit.queue_master_locator = true")
    values = YAML.safe_load_file(File.join(chart_dir, "values.yaml"))
    expect(values.dig("reportportal", "rabbitmq", "config", "extraConfiguration")).to include("default_vhost = analyzer")
  end
end
