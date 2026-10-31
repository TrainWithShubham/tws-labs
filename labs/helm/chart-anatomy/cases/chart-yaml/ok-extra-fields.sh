mkdir -p shop/templates
printf '%s\n' '# my chart' 'apiVersion: v2' 'name: shop' 'description: demo' 'type: application' 'version: 0.2.0-rc.1' 'appVersion: "1.27.0"' 'keywords:' '  - shop' > shop/Chart.yaml
