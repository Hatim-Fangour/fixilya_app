const cloudinary = require('../config/cloudinary');

class ImageUploadService {
  /**
   * Upload base64 image to Cloudinary
   */
  async uploadBase64Image({
    base64Data,
    folder,
    publicId,
    isProfilePicture = false,
  }) {
    try {
      console.log('📤 Uploading to Cloudinary...');
      console.log(`   Folder: ${folder}`);
      console.log(`   Public ID: ${publicId || 'auto-generated'}`);
      console.log(`   Is Profile: ${isProfilePicture}`);

      const uploadOptions = {
        folder: folder,
        resource_type: 'image',
        ...(publicId && { public_id: publicId }),
      };

      // ✅ Add transformations for profile pictures
      if (isProfilePicture) {
        uploadOptions.transformation = [
          {
            width: 400,
            height: 400,
            crop: 'thumb',
            gravity: 'face',
            zoom: 0.7,
          },
          {
            quality: 'auto:good',
            fetch_format: 'auto',
          },
        ];
      } else {
        // Work images
        uploadOptions.transformation = [
          {
            width: 1200,
            height: 1200,
            crop: 'limit',
          },
          {
            quality: 'auto:good',
            fetch_format: 'auto',
          },
        ];
      }

      const result = await cloudinary.uploader.upload(
        base64Data,
        uploadOptions,
      );

      console.log('✅ Upload successful!');
      console.log(`   URL: ${result.secure_url}`);

      return {
        url: result.secure_url,
        publicId: result.public_id,
        width: result.width,
        height: result.height,
        format: result.format,
      };
    } catch (error) {
      console.error('❌ Cloudinary upload error:', error);
      throw new Error(`Failed to upload image: ${error.message}`);
    }
  }

  /**
   * Upload multiple base64 images
   */
  async uploadMultipleBase64Images({ base64Array, folder }) {
    try {
      console.log(`📤 Uploading ${base64Array.length} images...`);

      const uploadPromises = base64Array.map((base64Data, index) =>
        this.uploadBase64Image({
          base64Data,
          folder,
          publicId: `${Date.now()}_${index}`,
          isProfilePicture: false,
        }),
      );

      const results = await Promise.all(uploadPromises);

      console.log(`✅ ${results.length} images uploaded successfully`);

      return results.map((r) => r.url);
    } catch (error) {
      console.error('❌ Multiple upload error:', error);
      throw error;
    }
  }

  /**
   * Delete image from Cloudinary
   */
  async deleteImage(publicId) {
    try {
      console.log(`🗑️ Deleting image: ${publicId}`);

      const result = await cloudinary.uploader.destroy(publicId);

      console.log('✅ Image deleted');
      return result;
    } catch (error) {
      console.error('❌ Delete error:', error);
      throw error;
    }
  }

  /**
   * Get optimized URL with transformations
   */
  getOptimizedUrl(url, { width, height, isProfilePicture = false }) {
    try {
      const publicId = this.extractPublicIdFromUrl(url);

      if (isProfilePicture) {
        return cloudinary.url(publicId, {
          transformation: [
            {
              width: width || 400,
              height: height || 400,
              crop: 'thumb',
              gravity: 'face',
              zoom: 0.7,
            },
            {
              quality: 'auto:good',
              fetch_format: 'auto',
            },
          ],
        });
      } else {
        return cloudinary.url(publicId, {
          transformation: [
            {
              width: width || 1200,
              height: height || 1200,
              crop: 'limit',
            },
            {
              quality: 'auto:good',
              fetch_format: 'auto',
            },
          ],
        });
      }
    } catch (error) {
      console.error('Error creating optimized URL:', error);
      return url;
    }
  }

  /**
   * Extract public ID from Cloudinary URL
   */
  extractPublicIdFromUrl(url) {
    try {
      const parts = url.split('/');
      const uploadIndex = parts.indexOf('upload');
      if (uploadIndex === -1) return null;

      const pathParts = parts.slice(uploadIndex + 2); // Skip 'upload' and version
      const publicIdWithExt = pathParts.join('/');
      const publicId = publicIdWithExt.replace(/\.[^/.]+$/, ''); // Remove extension

      return publicId;
    } catch (error) {
      return null;
    }
  }
}

module.exports = new ImageUploadService();