mkdir -p "$LAB_HOME/shop/templates"
[ -f "$LAB_HOME/shop/Chart.yaml" ] || printf 'apiVersion: v2\nname: shop\ntype: application\nversion: 0.1.0\nappVersion: "1.27.0"\n' > "$LAB_HOME/shop/Chart.yaml"
