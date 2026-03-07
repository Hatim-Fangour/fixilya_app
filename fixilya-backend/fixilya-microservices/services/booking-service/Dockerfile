FROM node:20-alpine
WORKDIR /app/services/booking-service
COPY shared /app/shared
COPY services/booking-service/package*.json ./
RUN npm ci --omit=dev
COPY services/booking-service/ .
CMD ["node", "src/app.js"]
