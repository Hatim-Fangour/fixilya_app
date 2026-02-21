const cloudinary = require('../config/cloudinary');
const logger = require('../utils/logger');

class CloudinaryService {
  async uploadImage(file, folder = 'fixilya') {
    try {
      const result = await cloudinary.uploader.upload(file, {
        folder: folder,
        resource_type: 'auto',
        transformation: [
          { width: 800, height: 800, crop: 'limit' },
          { quality: 'auto:good' },
          { fetch_format: 'auto' },
        ],
      });

      return {
        success: true,
        url: result.secure_url,
        publicId: result.public_id,
      };
    } catch (error) {
      logger.error('Cloudinary upload error:', error);
      throw error;
    }
  }

  async deleteImage(publicId) {
    try {
      const result = await cloudinary.uploader.destroy(publicId);
      return {
        success: result.result === 'ok',
        message: result.result,
      };
    } catch (error) {
      logger.error('Cloudinary delete error:', error);
      throw error;
    }
  }

  async deleteMultipleImages(publicIds) {
    try {
      const result = await cloudinary.api.delete_resources(publicIds);
      return {
        success: true,
        deleted: result.deleted,
      };
    } catch (error) {
      logger.error('Cloudinary batch delete error:', error);
      throw error;
    }
  }
}

module.exports = new CloudinaryService();