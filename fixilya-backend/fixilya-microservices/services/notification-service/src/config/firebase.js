// Re-export shared Firebase Admin SDK configuration.
// All services use the same Firebase project; centralising init in shared/
// prevents duplicate app registration across requires.
const path = require('path');
module.exports = require(path.join(__dirname, '../../../../shared/config/firebase'));
