FROM node:18-alpine

WORKDIR /app

# Copy package files first for layer caching
COPY package.json ./

RUN npm install --omit=dev

# Copy source
COPY src/ ./src/

EXPOSE 3007

CMD ["node", "src/app.js"]
