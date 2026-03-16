{{/*
Expand the name of the chart.
*/}}
{{- define "spilo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "spilo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "spilo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels - Включает в себя все возможные labels
*/}}
{{- define "spilo.labels" -}}
{{ include "spilo.headerLabels" . }}
{{ include "spilo.selectorLabels" . }}
{{- end }}

{{/*
Base labels - Заголовочные labels.
*/}}
{{- define "spilo.headerLabels" -}}
helm.sh/chart: {{ include "spilo.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels - базовые labels, используемые для секции selectors. Включая специфические для 
контейнеров spilo.
*/}}
{{- define "spilo.selectorLabels" -}}
{{ include "spilo.baseSelectorLabels" . }}
{{- with .Values.spilo.env.kubernetesLabels }}
{{ toYaml . }}
{{- end }}
{{ .Values.spilo.env.kubernetesScopeLabel }}: {{ include "spilo.fullname" . }}
{{- end }}

{{/*
Base Selector labels - базовые labels, используемые для секции selectors.
*/}}
{{- define "spilo.baseSelectorLabels" -}}
app.kubernetes.io/name: {{ include "spilo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "spilo.serviceAccountName" -}}
{{- default (include "spilo.fullname" .) .Values.serviceAccount.name }}
{{- end }}