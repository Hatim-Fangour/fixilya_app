FROM node:20-alpine
WORKDIR /app/services/user-service
COPY shared /app/shared
COPY services/user-service/package*.json ./
RUN npm ci --omit=dev
COPY services/user-service/ .
CMD ["node", "src/app.js"]
