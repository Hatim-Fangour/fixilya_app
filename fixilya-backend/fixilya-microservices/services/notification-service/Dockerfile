FROM node:20-alpine
# Install shared dependencies
WORKDIR /app/shared
COPY shared/package*.json ./
RUN npm ci
COPY shared/ .
# Install and set up the service
WORKDIR /app/services/notification-service
COPY services/notification-service/package*.json ./
RUN npm ci --omit=dev
COPY services/notification-service/ .
CMD ["node", "src/app.js"]
