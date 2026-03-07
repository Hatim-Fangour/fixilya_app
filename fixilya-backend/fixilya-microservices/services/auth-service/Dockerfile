FROM node:20-alpine
WORKDIR /app/services/auth-service
COPY shared /app/shared
COPY services/auth-service/package*.json ./
RUN npm ci --omit=dev
COPY services/auth-service/ .
CMD ["node", "src/app.js"]
