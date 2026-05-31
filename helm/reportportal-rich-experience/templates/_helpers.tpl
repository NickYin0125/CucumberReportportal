{{/*
Common names and labels.
*/}}
{{- define "reportportal-rich-experience.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "reportportal-rich-experience.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "reportportal-rich-experience.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "reportportal-rich-experience.labels" -}}
helm.sh/chart: {{ include "reportportal-rich-experience.chart" . }}
app.kubernetes.io/name: {{ include "reportportal-rich-experience.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "reportportal-rich-experience.videoBucketSecretName" -}}
{{- if .Values.videoBucket.auth.existingSecret -}}
{{- .Values.videoBucket.auth.existingSecret -}}
{{- else -}}
{{- printf "%s-video-bucket" (include "reportportal-rich-experience.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "reportportal-rich-experience.videoBucketAccessKey" -}}
{{- default .Values.reportportal.storage.accesskey .Values.videoBucket.auth.accessKey -}}
{{- end -}}

{{- define "reportportal-rich-experience.videoBucketSecretKey" -}}
{{- default .Values.reportportal.storage.secretkey .Values.videoBucket.auth.secretKey -}}
{{- end -}}

{{- define "reportportal-rich-experience.minioHost" -}}
{{- default (printf "%s-minio.%s.svc.cluster.local" .Release.Name .Release.Namespace) .Values.videoBucket.endpoint.host -}}
{{- end -}}

{{- define "reportportal-rich-experience.minioServiceName" -}}
{{- default (printf "%s-minio" .Release.Name) .Values.videoBucket.ingress.serviceName -}}
{{- end -}}

{{- define "reportportal-rich-experience.videoBucketHosts" -}}
{{- $hosts := .Values.videoBucket.ingress.hosts | default .Values.reportportal.ingress.hosts -}}
{{- if $hosts -}}
{{- toYaml $hosts -}}
{{- end -}}
{{- end -}}
