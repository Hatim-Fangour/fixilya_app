const sgMail = require('@sendgrid/mail');

sgMail.setApiKey(process.env.SENDGRID_API_KEY);

const sendVerificationEmail = async (email, fullName, verificationLink) => {
  // ✅ Validate environment variables
  if (!process.env.SENDGRID_API_KEY) {
    console.error('❌ SENDGRID_API_KEY not set in .env');
    return { success: false, error: 'SendGrid API key not configured' };
  }

  if (!process.env.SENDGRID_FROM_EMAIL) {
    console.error('❌ SENDGRID_FROM_EMAIL not set in .env');
    return { success: false, error: 'SendGrid from email not configured' };
  }

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📧 SENDING EMAIL VIA SENDGRID');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('To:', email);
  console.log('From:', process.env.SENDGRID_FROM_EMAIL);
  console.log('From Name:', process.env.SENDGRID_FROM_NAME);
  console.log('API Key:', process.env.SENDGRID_API_KEY?.substring(0, 15) + '...');

  const msg = {
    to: email,
    from: {
      email: process.env.SENDGRID_FROM_EMAIL,
      name: process.env.SENDGRID_FROM_NAME || 'Fixilya Team',
    },
    subject: '✅ Verify Your Fixilya Account',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
          .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
          .button { display: inline-block; background: #667eea; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; font-weight: bold; }
          .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>Welcome to Fixilya! 🎉</h1>
          </div>
          <div class="content">
            <h2>Hi ${fullName},</h2>
            <p>Thanks for signing up! We're excited to have you on board.</p>
            <p>To complete your registration, please verify your email address:</p>
            
            <div style="text-align: center;">
              <a href="${verificationLink}" class="button">Verify Email Address</a>
            </div>
            
            <p>Or copy this link: <br><small>${verificationLink}</small></p>
            
            <p><strong>This link expires in 24 hours.</strong></p>
            
            <p>Best regards,<br>The Fixilya Team</p>
          </div>
          <div class="footer">
            <p>&copy; 2026 Fixilya. All rights reserved.</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  try {
    const response = await sgMail.send(msg);
    console.log('✅ Email sent successfully');
    console.log('Status Code:', response[0].statusCode);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return { success: true };
  } catch (error) {
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.error('❌ SENDGRID ERROR DETAILS');
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.error('Error Code:', error.code);
    console.error('Error Message:', error.message);
    
    // ✅ CRITICAL: Log the actual error array
    if (error.response?.body?.errors) {
      console.error('Errors from SendGrid:');
      error.response.body.errors.forEach((err, index) => {
        console.error(`  ${index + 1}. Message:`, err.message);
        console.error(`     Field:`, err.field || 'N/A');
        console.error(`     Help:`, err.help || 'N/A');
      });
    }
    
    // ✅ Log full response body
    console.error('Full Response Body:', JSON.stringify(error.response?.body, null, 2));
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    return { success: false, error: error.message };
  }
};

module.exports = { sendVerificationEmail };