// Re-export the shared Winston logger.
const path = require('path');
module.exports = require(path.join(__dirname, '../../../../shared/utils/logger'));
