printf '%s\n' 'services:' '  web:' '    image: node:22-alpine' '  db:' '    image: postgres:17' 'networks:' '  backend:' > compose.yaml
