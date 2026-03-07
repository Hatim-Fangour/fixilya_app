FROM node:20-alpine
WORKDIR /app/services/notification-service
COPY shared /app/shared
COPY services/notification-service/package*.json ./
RUN npm ci --omit=dev
COPY services/notification-service/ .
CMD ["node", "src/app.js"]
