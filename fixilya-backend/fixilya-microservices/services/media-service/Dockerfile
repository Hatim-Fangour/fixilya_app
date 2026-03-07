FROM node:20-alpine
WORKDIR /app/services/media-service
COPY shared /app/shared
COPY services/media-service/package*.json ./
RUN npm ci --omit=dev
COPY services/media-service/ .
CMD ["node", "src/app.js"]
