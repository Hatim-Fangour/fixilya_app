FROM node:20-alpine
# Install shared dependencies
WORKDIR /app/shared
COPY shared/package*.json ./
RUN npm ci
COPY shared/ .
# Install and set up the service
WORKDIR /app/services/call-service
COPY services/call-service/package*.json ./
RUN npm install --omit=dev
COPY services/call-service/ .
CMD ["node", "src/app.js"]
