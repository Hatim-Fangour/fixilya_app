const redis = require('redis');
const logger = require('../utils/logger');

console.log('🔍 Initializing Redis connection...');

const client = redis.createClient({
  socket: {
    host: process.env.REDIS_HOST || 'localhost',
    port: parseInt(process.env.REDIS_PORT || '6379'),
  },
  password: process.env.REDIS_PASSWORD || undefined,
});

client.on('connect', () => {
  console.log('✅ Connected to Redis');
  logger.info('Connected to Redis');
});

client.on('ready', () => {
  console.log('✅ Redis is ready');
  logger.info('Redis is ready');
});

client.on('error', (err) => {
  console.error('❌ Redis error:', err.message);
  logger.error('Redis error:', err.message);
});

client.on('end', () => {
  console.log('⚠️ Redis connection closed');
  logger.warn('Redis connection closed');
});

(async () => {
  try {
    await client.connect();
    console.log('🔌 Redis connection established');
  } catch (error) {
    console.error('❌ Failed to connect to Redis:', error.message);
    logger.error('Failed to connect to Redis:', error);
  }
})();

module.exports = client;