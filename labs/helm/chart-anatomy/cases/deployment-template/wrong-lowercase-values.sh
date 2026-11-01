mkdir -p shop/templates
printf '%s\n' 'apiVersion: apps/v1' 'kind: Deployment' 'metadata:' '  name: {{ .Release.Name }}' 'spec:' '  replicas: {{ .values.replicaCount }}' '  template:' '    spec:' '      containers:' '        - name: web' '          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default "latest" }}"' > shop/templates/deployment.yaml
