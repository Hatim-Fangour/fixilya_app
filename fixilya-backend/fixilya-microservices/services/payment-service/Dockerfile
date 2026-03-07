FROM node:20-alpine
WORKDIR /app/services/payment-service
COPY shared /app/shared
COPY services/payment-service/package*.json ./
RUN npm ci --omit=dev
COPY services/payment-service/ .
CMD ["node", "src/app.js"]
