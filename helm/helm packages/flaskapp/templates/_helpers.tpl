{{/*
Expand the name of the chart.
*/}}
{{- define "flaskapp.name" -}}
{{- if and .Values (hasKey .Values "nameOverride") .Values.nameOverride }}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- else if .Chart }}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
app
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flaskapp.fullname" -}}
{{- if and .Values (hasKey .Values "fullnameOverride") .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := "" }}
{{- if and .Values (hasKey .Values "nameOverride") .Values.nameOverride }}
  {{- $name = .Values.nameOverride }}
{{- else if .Chart }}
  {{- $name = .Chart.Name }}
{{- else }}
  {{- $name = "app" }}
{{- end }}
{{- if and .Release (hasKey .Release "Name") }}
  {{- if contains $name .Release.Name }}
    {{- .Release.Name | trunc 63 | trimSuffix "-" }}
  {{- else }}
    {{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
  {{- end }}
{{- else }}
  {{- $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flaskapp.chart" -}}
{{- if and .Chart .Chart.Name .Chart.Version }}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- else }}
flaskapp-0.1.0
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flaskapp.labels" -}}
helm.sh/chart: {{ include "flaskapp.chart" . }}
{{ include "flaskapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service | default "Helm" }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flaskapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flaskapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | default "release-name" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flaskapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flaskapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
