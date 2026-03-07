const cloudinaryService = require('../services/cloudinaryService');
const logger = require('../utils/logger');

// Allowed MIME types for image uploads
const ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
];

// Max file size: 10 MB (base64 strings are ~33% larger than binary)
const MAX_BASE64_LENGTH = 10 * 1024 * 1024 * 1.34;

// Validates a Cloudinary public_id format
const PUBLIC_ID_PATTERN = /^[A-Za-z0-9_\-/]+$/;

// POST /api/media/upload
exports.uploadImage = async (req, res) => {
  try {
    if (!req.body.file && !req.file) {
      return res.status(400).json({ success: false, message: 'No file provided' });
    }

    const fileInput = req.body.file || req.file?.path;
    const folder = req.body.folder || req.query.folder || 'fixilya';

    // Validate base64 data-URI format and MIME type
    if (typeof fileInput === 'string' && fileInput.startsWith('data:')) {
      const mimeMatch = fileInput.match(/^data:([^;]+);base64,/);
      if (!mimeMatch) {
        return res.status(400).json({ success: false, message: 'Invalid data-URI format' });
      }

      const mimeType = mimeMatch[1];
      if (!ALLOWED_MIME_TYPES.includes(mimeType)) {
        return res.status(400).json({
          success: false,
          message: `File type '${mimeType}' not allowed. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}`,
        });
      }

      if (fileInput.length > MAX_BASE64_LENGTH) {
        return res.status(400).json({
          success: false,
          message: 'File too large. Maximum size is 10 MB.',
        });
      }
    }

    // Validate multer file MIME type
    if (req.file && !ALLOWED_MIME_TYPES.includes(req.file.mimetype)) {
      return res.status(400).json({
        success: false,
        message: `File type '${req.file.mimetype}' not allowed. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}`,
      });
    }

    const result = await cloudinaryService.uploadImage(fileInput, folder);

    return res.status(201).json({
      success: true,
      data: {
        url: result.url,
        publicId: result.publicId,
      },
    });
  } catch (err) {
    logger.error('[Media] upload error:', err);
    return res.status(500).json({ success: false, message: 'Upload failed' });
  }
};

// DELETE /api/media/:publicId
exports.deleteImage = async (req, res) => {
  try {
    const publicId = decodeURIComponent(req.params.publicId);

    if (!publicId) {
      return res.status(400).json({ success: false, message: 'publicId is required' });
    }

    if (!PUBLIC_ID_PATTERN.test(publicId)) {
      return res.status(400).json({ success: false, message: 'Invalid publicId format' });
    }

    const result = await cloudinaryService.deleteImage(publicId);

    return res.json({ success: result.success, message: result.message });
  } catch (err) {
    logger.error('[Media] delete error:', err);
    return res.status(500).json({ success: false, message: 'Delete failed' });
  }
};

// DELETE /api/media/batch
exports.deleteMultiple = async (req, res) => {
  try {
    const { publicIds } = req.body;

    if (!Array.isArray(publicIds) || publicIds.length === 0) {
      return res.status(400).json({ success: false, message: 'publicIds array is required' });
    }

    if (publicIds.length > 100) {
      return res.status(400).json({ success: false, message: 'Maximum 100 items per batch' });
    }

    const invalid = publicIds.find((id) => !PUBLIC_ID_PATTERN.test(id));
    if (invalid) {
      return res.status(400).json({ success: false, message: `Invalid publicId: ${invalid}` });
    }

    const result = await cloudinaryService.deleteMultipleImages(publicIds);

    return res.json({ success: result.success, deleted: result.deleted });
  } catch (err) {
    logger.error('[Media] batch delete error:', err);
    return res.status(500).json({ success: false, message: 'Batch delete failed' });
  }
};
