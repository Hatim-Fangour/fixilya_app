/**
 * Shared CORS configuration for all microservices.
 *
 * Set ALLOWED_ORIGINS as a comma-separated list in .env:
 *   ALLOWED_ORIGINS=https://fixilya.ma,https://admin.fixilya.ma
 *
 * In development (NODE_ENV !== 'production'), all origins are allowed.
 */
const corsOptions = () => {
  const isProduction = process.env.NODE_ENV === 'production';

  if (!isProduction) {
    return {
      origin: true, // reflect request origin (allow all in dev)
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
      credentials: true,
    };
  }

  const raw = process.env.ALLOWED_ORIGINS || '';
  const allowedOrigins = raw.split(',').map(s => s.trim()).filter(Boolean);

  if (allowedOrigins.length === 0) {
    console.warn(
      'WARNING: ALLOWED_ORIGINS is empty in production. CORS will reject all cross-origin requests.'
    );
  }

  return {
    origin: (origin, callback) => {
      // Allow server-to-server requests (no origin header)
      if (!origin) return callback(null, true);
      if (allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(new Error(`Origin ${origin} not allowed by CORS`));
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  };
};

module.exports = corsOptions;
