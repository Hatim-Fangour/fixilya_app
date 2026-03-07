const express = require('express');
const router = express.Router();
const path = require('path');
const { authenticate } = require(path.join(__dirname, '../../../../shared/middleware/auth'));
const controller = require('../controllers/media.controller');

// All media endpoints require authentication
router.use(authenticate);

// Upload a single image
router.post('/upload', controller.uploadImage);

// Delete a single image by Cloudinary public_id
router.delete('/:publicId', controller.deleteImage);

// Batch-delete multiple images
router.delete('/', controller.deleteMultiple);

module.exports = router;
