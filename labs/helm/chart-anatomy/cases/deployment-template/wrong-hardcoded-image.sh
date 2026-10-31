mkdir -p shop/templates
printf '%s\n' 'apiVersion: apps/v1' 'kind: Deployment' 'metadata:' '  name: {{ .Release.Name }}' 'spec:' '  replicas: {{ .Values.replicaCount }}' '  template:' '    spec:' '      containers:' '        - name: web' '          image: nginx:1.27.0 # {{ .Values.image.repository }}:{{ .Values.image.tag | quote }}' > shop/templates/deployment.yaml
