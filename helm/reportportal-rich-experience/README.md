# ReportPortal Rich Experience Helm Chart

Requires a Kubernetes cluster, such as kind or Docker Desktop Kubernetes, and Helm v3.
Install with `helm install reportportal ./reportportal-rich-experience-1.1.0.tgz -n reportportal --create-namespace`.
This chart deploys ReportPortal with a public MinIO `automation-videos` bucket and same-origin Ingress routing so Ruby Cucumber reports can render MP4 evidence through native HTML5 video playback.
