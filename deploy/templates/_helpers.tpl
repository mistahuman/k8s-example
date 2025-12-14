{{- define "k8s-example.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "k8s-example.fullname" -}}
{{- $name := include "k8s-example.name" . -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "k8s-example.labels" -}}
app.kubernetes.io/name: {{ include "k8s-example.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{- define "k8s-example.selectorLabels" -}}
app.kubernetes.io/name: {{ include "k8s-example.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
