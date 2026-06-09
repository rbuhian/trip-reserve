import '../config/app_config.dart';
import '../models/booking.dart';

/// Email template generator for Trip Reserve booking notifications
class EmailTemplates {
  EmailTemplates._();

  static const _navyColor = AppConfig.brandNavyColor;
  static const _amberColor = AppConfig.brandAmberColor;

  /// Generate booking confirmation email HTML
  static String bookingConfirmation({
    required String customerName,
    required Booking booking,
  }) {
    final formattedDate = _formatDate(booking.scheduledDate);
    final formattedAmount = _formatCurrency(booking.totalAmount);

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Booking Confirmation</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background-color: $_navyColor; padding: 30px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Trip Reserve</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 30px;">
              <h2 style="color: $_navyColor; margin: 0 0 20px 0; font-size: 24px;">Booking Confirmed!</h2>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Hi $customerName,
              </p>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Your booking has been received and is pending driver assignment. We'll notify you once a driver accepts your trip.
              </p>

              <!-- Reference Number -->
              <div style="background-color: #f8f9fa; border-radius: 8px; padding: 15px; margin-bottom: 20px; text-align: center;">
                <p style="color: #666666; font-size: 14px; margin: 0 0 5px 0;">Reference Number</p>
                <p style="color: $_navyColor; font-size: 24px; font-weight: bold; margin: 0;">${booking.referenceNumber}</p>
              </div>

              <!-- Trip Details -->
              <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; margin-bottom: 20px;">
                <h3 style="color: $_navyColor; margin: 0 0 15px 0; font-size: 18px;">Trip Details</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Date</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$formattedDate</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Pickup Time</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${booking.pickupTime}</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Vehicle Type</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${booking.category.displayName}</td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 12px 0 8px 0;">
                      <div style="background-color: #e8f5e9; border-radius: 4px; padding: 10px;">
                        <p style="color: #2e7d32; font-size: 12px; margin: 0 0 5px 0; font-weight: bold;">PICKUP</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.pickupAddress}</p>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 8px 0;">
                      <div style="background-color: #ffebee; border-radius: 4px; padding: 10px;">
                        <p style="color: #c62828; font-size: 12px; margin: 0 0 5px 0; font-weight: bold;">DROP-OFF</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.dropoffAddress}</p>
                      </div>
                    </td>
                  </tr>
                </table>
              </div>

              <!-- Pricing -->
              <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px;">
                <h3 style="color: $_navyColor; margin: 0 0 15px 0; font-size: 18px;">Fare Summary</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Base Fare</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${_formatCurrency(booking.baseFare)}</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Distance (${booking.distanceText})</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${_formatCurrency(booking.distanceFee)}</td>
                  </tr>
                  ${booking.addonsFee > 0 ? '''
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Add-ons</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${_formatCurrency(booking.addonsFee)}</td>
                  </tr>
                  ''' : ''}
                  <tr>
                    <td colspan="2" style="padding-top: 12px; border-top: 1px solid #e0e0e0;"></td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: $_navyColor; font-size: 18px; font-weight: bold;">Total</td>
                    <td style="padding: 8px 0; color: $_navyColor; font-size: 18px; font-weight: bold; text-align: right;">$formattedAmount</td>
                  </tr>
                </table>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e0e0e0;">
              <p style="color: #666666; font-size: 14px; margin: 0 0 10px 0;">
                Questions? Contact us at support@tripreserve.ph
              </p>
              <p style="color: #999999; font-size: 12px; margin: 0;">
                &copy; ${DateTime.now().year} Trip Reserve. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  /// Generate driver assigned notification email HTML
  static String driverAssigned({
    required String customerName,
    required Booking booking,
  }) {
    final formattedDate = _formatDate(booking.scheduledDate);
    final driverName = booking.driver?.fullName ?? 'Your Driver';
    final driverPhone = booking.driver?.phone ?? 'N/A';
    final vehicleName = booking.vehicle?.name ?? 'Vehicle';
    final vehiclePlate = booking.vehicle?.plateNumber ?? 'N/A';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Driver Assigned</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background-color: $_navyColor; padding: 30px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Trip Reserve</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 30px;">
              <div style="text-align: center; margin-bottom: 20px;">
                <div style="width: 60px; height: 60px; background-color: #e8f5e9; border-radius: 50%; display: inline-block; line-height: 60px;">
                  <span style="font-size: 30px;">&#10003;</span>
                </div>
              </div>

              <h2 style="color: $_navyColor; margin: 0 0 20px 0; font-size: 24px; text-align: center;">Driver Assigned!</h2>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Hi $customerName,
              </p>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Great news! A driver has been assigned to your booking. Here are the details:
              </p>

              <!-- Reference Number -->
              <div style="background-color: #f8f9fa; border-radius: 8px; padding: 15px; margin-bottom: 20px; text-align: center;">
                <p style="color: #666666; font-size: 14px; margin: 0 0 5px 0;">Reference Number</p>
                <p style="color: $_navyColor; font-size: 24px; font-weight: bold; margin: 0;">${booking.referenceNumber}</p>
              </div>

              <!-- Driver Details -->
              <div style="border: 2px solid $_amberColor; border-radius: 8px; padding: 20px; margin-bottom: 20px; background-color: #fffbf0;">
                <h3 style="color: $_navyColor; margin: 0 0 15px 0; font-size: 18px;">Your Driver</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Name</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: bold;">$driverName</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Phone</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$driverPhone</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Vehicle</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$vehicleName</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Plate Number</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: bold;">$vehiclePlate</td>
                  </tr>
                </table>
              </div>

              <!-- Trip Details -->
              <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px;">
                <h3 style="color: $_navyColor; margin: 0 0 15px 0; font-size: 18px;">Trip Details</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Date</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$formattedDate</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Pickup Time</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${booking.pickupTime}</td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 12px 0 8px 0;">
                      <div style="background-color: #e8f5e9; border-radius: 4px; padding: 10px;">
                        <p style="color: #2e7d32; font-size: 12px; margin: 0 0 5px 0; font-weight: bold;">PICKUP</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.pickupAddress}</p>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 8px 0;">
                      <div style="background-color: #ffebee; border-radius: 4px; padding: 10px;">
                        <p style="color: #c62828; font-size: 12px; margin: 0 0 5px 0; font-weight: bold;">DROP-OFF</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.dropoffAddress}</p>
                      </div>
                    </td>
                  </tr>
                </table>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e0e0e0;">
              <p style="color: #666666; font-size: 14px; margin: 0 0 10px 0;">
                Questions? Contact us at support@tripreserve.ph
              </p>
              <p style="color: #999999; font-size: 12px; margin: 0;">
                &copy; ${DateTime.now().year} Trip Reserve. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  /// Generate trip receipt email HTML
  static String tripReceipt({
    required String customerName,
    required Booking booking,
  }) {
    final formattedDate = _formatDate(booking.scheduledDate);
    final formattedAmount = _formatCurrency(booking.totalAmount);
    final driverName = booking.driver?.fullName ?? 'Driver';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Trip Receipt</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background-color: $_navyColor; padding: 30px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Trip Reserve</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 30px;">
              <h2 style="color: $_navyColor; margin: 0 0 10px 0; font-size: 24px; text-align: center;">Trip Complete</h2>
              <p style="color: #666666; font-size: 16px; margin: 0 0 30px 0; text-align: center;">Thank you for riding with us!</p>

              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Hi $customerName,
              </p>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Your trip has been completed. Here's your receipt:
              </p>

              <!-- Receipt Box -->
              <div style="border: 2px solid $_navyColor; border-radius: 8px; padding: 20px; margin-bottom: 20px;">
                <div style="text-align: center; margin-bottom: 20px; padding-bottom: 20px; border-bottom: 1px dashed #e0e0e0;">
                  <p style="color: #666666; font-size: 12px; margin: 0 0 5px 0;">RECEIPT</p>
                  <p style="color: $_navyColor; font-size: 20px; font-weight: bold; margin: 0;">${booking.referenceNumber}</p>
                  <p style="color: #666666; font-size: 14px; margin: 10px 0 0 0;">$formattedDate</p>
                </div>

                <!-- Route -->
                <div style="margin-bottom: 20px; padding-bottom: 20px; border-bottom: 1px dashed #e0e0e0;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="width: 30px; vertical-align: top; padding-top: 3px;">
                        <div style="width: 12px; height: 12px; background-color: #2e7d32; border-radius: 50%;"></div>
                      </td>
                      <td style="padding: 0 0 15px 0;">
                        <p style="color: #666666; font-size: 12px; margin: 0 0 5px 0;">FROM</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.pickupAddress}</p>
                      </td>
                    </tr>
                    <tr>
                      <td style="width: 30px; vertical-align: top; padding-top: 3px;">
                        <div style="width: 12px; height: 12px; background-color: #c62828; border-radius: 50%;"></div>
                      </td>
                      <td>
                        <p style="color: #666666; font-size: 12px; margin: 0 0 5px 0;">TO</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.dropoffAddress}</p>
                      </td>
                    </tr>
                  </table>
                </div>

                <!-- Trip Info -->
                <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom: 20px;">
                  <tr>
                    <td style="padding: 5px 0; color: #666666; font-size: 14px;">Driver</td>
                    <td style="padding: 5px 0; color: #333333; font-size: 14px; text-align: right;">$driverName</td>
                  </tr>
                  <tr>
                    <td style="padding: 5px 0; color: #666666; font-size: 14px;">Distance</td>
                    <td style="padding: 5px 0; color: #333333; font-size: 14px; text-align: right;">${booking.distanceText}</td>
                  </tr>
                  <tr>
                    <td style="padding: 5px 0; color: #666666; font-size: 14px;">Duration</td>
                    <td style="padding: 5px 0; color: #333333; font-size: 14px; text-align: right;">${booking.durationText}</td>
                  </tr>
                </table>

                <!-- Fare Breakdown -->
                <div style="border-top: 1px dashed #e0e0e0; padding-top: 20px;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td style="padding: 5px 0; color: #666666; font-size: 14px;">Base Fare</td>
                      <td style="padding: 5px 0; color: #333333; font-size: 14px; text-align: right;">${_formatCurrency(booking.baseFare)}</td>
                    </tr>
                    <tr>
                      <td style="padding: 5px 0; color: #666666; font-size: 14px;">Distance Fee</td>
                      <td style="padding: 5px 0; color: #333333; font-size: 14px; text-align: right;">${_formatCurrency(booking.distanceFee)}</td>
                    </tr>
                    ${booking.addonsFee > 0 ? '''
                    <tr>
                      <td style="padding: 5px 0; color: #666666; font-size: 14px;">Add-ons</td>
                      <td style="padding: 5px 0; color: #333333; font-size: 14px; text-align: right;">${_formatCurrency(booking.addonsFee)}</td>
                    </tr>
                    ''' : ''}
                    <tr>
                      <td colspan="2" style="padding-top: 15px; border-top: 1px solid #e0e0e0;"></td>
                    </tr>
                    <tr>
                      <td style="padding: 10px 0; color: $_navyColor; font-size: 20px; font-weight: bold;">TOTAL</td>
                      <td style="padding: 10px 0; color: $_navyColor; font-size: 20px; font-weight: bold; text-align: right;">$formattedAmount</td>
                    </tr>
                  </table>
                </div>
              </div>

              <p style="color: #666666; font-size: 14px; text-align: center; margin: 0;">
                We hope you enjoyed your ride. See you next time!
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e0e0e0;">
              <p style="color: #666666; font-size: 14px; margin: 0 0 10px 0;">
                Questions? Contact us at support@tripreserve.ph
              </p>
              <p style="color: #999999; font-size: 12px; margin: 0;">
                &copy; ${DateTime.now().year} Trip Reserve. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  /// Generate trip started notification email HTML
  static String tripStarted({
    required String customerName,
    required Booking booking,
  }) {
    final formattedDate = _formatDate(booking.scheduledDate);
    final driverName = booking.driver?.fullName ?? 'Your Driver';
    final driverPhone = booking.driver?.phone ?? 'N/A';
    final vehicleName = booking.vehicle?.name ?? 'Vehicle';
    final vehiclePlate = booking.vehicle?.plateNumber ?? 'N/A';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Trip Started</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background-color: $_navyColor; padding: 30px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Trip Reserve</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 30px;">
              <div style="text-align: center; margin-bottom: 20px;">
                <div style="width: 60px; height: 60px; background-color: #ede7f6; border-radius: 50%; display: inline-block; line-height: 60px;">
                  <span style="font-size: 30px;">&#128663;</span>
                </div>
              </div>

              <h2 style="color: $_navyColor; margin: 0 0 20px 0; font-size: 24px; text-align: center;">Your Trip Has Started!</h2>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Hi $customerName,
              </p>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Your driver is on the way! Your trip is now in progress.
              </p>

              <!-- Reference Number -->
              <div style="background-color: #f3e5f5; border-radius: 8px; padding: 15px; margin-bottom: 20px; text-align: center;">
                <p style="color: #666666; font-size: 14px; margin: 0 0 5px 0;">Reference Number</p>
                <p style="color: $_navyColor; font-size: 24px; font-weight: bold; margin: 0;">${booking.referenceNumber}</p>
              </div>

              <!-- Driver Details -->
              <div style="border: 2px solid $_amberColor; border-radius: 8px; padding: 20px; margin-bottom: 20px; background-color: #fffbf0;">
                <h3 style="color: $_navyColor; margin: 0 0 15px 0; font-size: 18px;">Your Driver</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Name</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: bold;">$driverName</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Phone</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$driverPhone</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Vehicle</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$vehicleName</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Plate Number</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right; font-weight: bold;">$vehiclePlate</td>
                  </tr>
                </table>
              </div>

              <!-- Trip Route -->
              <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px;">
                <h3 style="color: $_navyColor; margin: 0 0 15px 0; font-size: 18px;">Trip Route</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Date</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$formattedDate</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Pickup Time</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${booking.pickupTime}</td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 12px 0 8px 0;">
                      <div style="background-color: #e8f5e9; border-radius: 4px; padding: 10px;">
                        <p style="color: #2e7d32; font-size: 12px; margin: 0 0 5px 0; font-weight: bold;">PICKUP</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.pickupAddress}</p>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 8px 0;">
                      <div style="background-color: #ffebee; border-radius: 4px; padding: 10px;">
                        <p style="color: #c62828; font-size: 12px; margin: 0 0 5px 0; font-weight: bold;">DROP-OFF</p>
                        <p style="color: #333333; font-size: 14px; margin: 0;">${booking.dropoffAddress}</p>
                      </div>
                    </td>
                  </tr>
                </table>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e0e0e0;">
              <p style="color: #666666; font-size: 14px; margin: 0 0 10px 0;">
                Questions? Contact us at support@tripreserve.ph
              </p>
              <p style="color: #999999; font-size: 12px; margin: 0;">
                &copy; ${DateTime.now().year} Trip Reserve. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  /// Generate booking cancellation email HTML
  static String bookingCancelled({
    required String recipientName,
    required Booking booking,
    required bool isCustomer,
    String? reason,
  }) {
    final formattedDate = _formatDate(booking.scheduledDate);
    final cancelledBy = isCustomer ? 'you' : 'the customer';
    final reasonText = reason != null && reason.isNotEmpty
        ? reason
        : 'No reason provided';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Booking Cancelled</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 20px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width: 600px; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
          <!-- Header -->
          <tr>
            <td style="background-color: $_navyColor; padding: 30px; text-align: center;">
              <h1 style="color: #ffffff; margin: 0; font-size: 28px;">Trip Reserve</h1>
            </td>
          </tr>

          <!-- Content -->
          <tr>
            <td style="padding: 30px;">
              <div style="text-align: center; margin-bottom: 20px;">
                <div style="width: 60px; height: 60px; background-color: #ffebee; border-radius: 50%; display: inline-block; line-height: 60px;">
                  <span style="font-size: 30px; color: #c62828;">&#10005;</span>
                </div>
              </div>

              <h2 style="color: #c62828; margin: 0 0 20px 0; font-size: 24px; text-align: center;">Booking Cancelled</h2>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                Hi $recipientName,
              </p>
              <p style="color: #333333; font-size: 16px; line-height: 1.5; margin: 0 0 20px 0;">
                The following booking has been cancelled by $cancelledBy:
              </p>

              <!-- Reference Number -->
              <div style="background-color: #ffebee; border-radius: 8px; padding: 15px; margin-bottom: 20px; text-align: center;">
                <p style="color: #666666; font-size: 14px; margin: 0 0 5px 0;">Reference Number</p>
                <p style="color: #c62828; font-size: 24px; font-weight: bold; margin: 0;">${booking.referenceNumber}</p>
              </div>

              <!-- Trip Details -->
              <div style="border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; margin-bottom: 20px;">
                <h3 style="color: $_navyColor; margin: 0 0 15px 0; font-size: 18px;">Cancelled Trip Details</h3>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Date</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">$formattedDate</td>
                  </tr>
                  <tr>
                    <td style="padding: 8px 0; color: #666666; font-size: 14px;">Pickup Time</td>
                    <td style="padding: 8px 0; color: #333333; font-size: 14px; text-align: right;">${booking.pickupTime}</td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 12px 0 8px 0;">
                      <p style="color: #666666; font-size: 12px; margin: 0 0 5px 0;">FROM</p>
                      <p style="color: #333333; font-size: 14px; margin: 0;">${booking.pickupAddress}</p>
                    </td>
                  </tr>
                  <tr>
                    <td colspan="2" style="padding: 8px 0;">
                      <p style="color: #666666; font-size: 12px; margin: 0 0 5px 0;">TO</p>
                      <p style="color: #333333; font-size: 14px; margin: 0;">${booking.dropoffAddress}</p>
                    </td>
                  </tr>
                </table>
              </div>

              <!-- Cancellation Reason -->
              <div style="background-color: #f8f9fa; border-radius: 8px; padding: 15px; margin-bottom: 20px;">
                <p style="color: #666666; font-size: 12px; margin: 0 0 5px 0; font-weight: bold;">CANCELLATION REASON</p>
                <p style="color: #333333; font-size: 14px; margin: 0;">$reasonText</p>
              </div>

              ${isCustomer ? '''
              <p style="color: #666666; font-size: 14px; text-align: center; margin: 0;">
                Need to book another trip? Open the Trip Reserve app to get started.
              </p>
              ''' : '''
              <p style="color: #666666; font-size: 14px; text-align: center; margin: 0;">
                The booking slot is now available for other customers.
              </p>
              '''}
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #f8f9fa; padding: 20px; text-align: center; border-top: 1px solid #e0e0e0;">
              <p style="color: #666666; font-size: 14px; margin: 0 0 10px 0;">
                Questions? Contact us at support@tripreserve.ph
              </p>
              <p style="color: #999999; font-size: 12px; margin: 0;">
                &copy; ${DateTime.now().year} Trip Reserve. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  /// Format date as "Mon, Jan 1, 2024"
  static String _formatDate(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, $monthName ${date.day}, ${date.year}';
  }

  /// Format currency as "₱1,234.56"
  static String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    // Add thousands separators
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }

    return '${AppConfig.currencySymbol}${buffer.toString()}.$decPart';
  }
}
