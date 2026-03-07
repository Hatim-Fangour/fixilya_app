/**
 * Validate required environment variables at startup.
 * Call with the list of required var names for each service.
 *
 * Usage:
 *   require('../../shared/config/validateEnv')(['FIREBASE_PROJECT_ID', 'PORT']);
 */
module.exports = function validateEnv(requiredVars) {
  const missing = requiredVars.filter(
    (key) => !process.env[key] || process.env[key].trim() === ''
  );

  if (missing.length > 0) {
    console.error(
      `\nMISSING ENVIRONMENT VARIABLES:\n  ${missing.join('\n  ')}\n`
    );
    console.error(
      'Copy .env.example to .env and fill in the required values.\n'
    );
    process.exit(1);
  }
};
