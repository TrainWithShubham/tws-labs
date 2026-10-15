printf '%s\n' 'FROM node:22-alpine' 'RUN echo build' 'FROM node:22-alpine' 'COPY --from=0 /app .' > Dockerfile
