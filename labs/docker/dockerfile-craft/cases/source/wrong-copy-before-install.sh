printf '%s\n' 'FROM node:22-alpine' 'WORKDIR /app' 'COPY . .' 'RUN npm ci' > app/Dockerfile
