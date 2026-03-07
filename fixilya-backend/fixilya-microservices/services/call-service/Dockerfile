FROM node:20-alpine
WORKDIR /app/services/call-service
COPY shared /app/shared
COPY services/call-service/package*.json ./
RUN npm ci --omit=dev
COPY services/call-service/ .
CMD ["node", "src/app.js"]
