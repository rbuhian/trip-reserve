import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import 'email_templates.dart';

/// Result of an email send operation
class EmailResult {
  final bool success;
  final String? messageId;
  final String? error;

  const EmailResult({
    required this.success,
    this.messageId,
    this.error,
  });

  factory EmailResult.fromJson(Map<String, dynamic> json) {
    return EmailResult(
      success: json['success'] as bool? ?? false,
      messageId: json['messageId'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// Exception for email service errors
class EmailServiceException implements Exception {
  final String message;
  final String? code;

  const EmailServiceException(this.message, {this.code});

  @override
  String toString() => 'EmailServiceException: $message${code != null ? ' ($code)' : ''}';
}

/// Service for sending booking-related emails via Supabase Edge Function
class EmailService {
  final SupabaseClient _client;

  EmailService(this._client);

  /// Send an email via the Supabase Edge Function
  Future<EmailResult> _sendEmail({
    required String to,
    required String subject,
    required String html,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'send-email',
        body: {
          'to': to,
          'subject': subject,
          'html': html,
        },
      );

      if (response.status != 200) {
        developer.log(
          'Email send failed with status ${response.status}',
          name: 'EmailService',
          error: response.data,
        );
        return EmailResult(
          success: false,
          error: 'Failed to send email (status ${response.status})',
        );
      }

      final data = response.data as Map<String, dynamic>;
      return EmailResult.fromJson(data);
    } catch (e) {
      developer.log(
        'Email send error',
        name: 'EmailService',
        error: e,
      );
      return EmailResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get user email by ID
  Future<String?> _getUserEmail(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('email')
          .eq('id', userId)
          .maybeSingle();
      return response?['email'] as String?;
    } catch (e) {
      developer.log(
        'Failed to get user email for $userId',
        name: 'EmailService',
        error: e,
      );
      return null;
    }
  }

  /// Get user full name by ID
  Future<String?> _getUserName(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      return response?['full_name'] as String?;
    } catch (e) {
      developer.log(
        'Failed to get user name for $userId',
        name: 'EmailService',
        error: e,
      );
      return null;
    }
  }

  /// Send booking confirmation email to customer
  ///
  /// Called after a booking is created.
  Future<EmailResult> sendBookingConfirmation(Booking booking) async {
    final customerEmail = await _getUserEmail(booking.customerId);
    if (customerEmail == null) {
      developer.log(
        'Cannot send booking confirmation: customer email not found',
        name: 'EmailService',
      );
      return const EmailResult(
        success: false,
        error: 'Customer email not found',
      );
    }

    final customerName = booking.customer?.fullName ??
        await _getUserName(booking.customerId) ??
        'Customer';

    final html = EmailTemplates.bookingConfirmation(
      customerName: customerName,
      booking: booking,
    );

    developer.log(
      'Sending booking confirmation to $customerEmail for ${booking.referenceNumber}',
      name: 'EmailService',
    );

    return _sendEmail(
      to: customerEmail,
      subject: 'Booking Confirmed - ${booking.referenceNumber}',
      html: html,
    );
  }

  /// Send driver assigned notification to customer
  ///
  /// Called after a driver accepts the booking.
  Future<EmailResult> sendDriverAssigned(Booking booking) async {
    final customerEmail = await _getUserEmail(booking.customerId);
    if (customerEmail == null) {
      developer.log(
        'Cannot send driver assigned email: customer email not found',
        name: 'EmailService',
      );
      return const EmailResult(
        success: false,
        error: 'Customer email not found',
      );
    }

    final customerName = booking.customer?.fullName ??
        await _getUserName(booking.customerId) ??
        'Customer';

    final html = EmailTemplates.driverAssigned(
      customerName: customerName,
      booking: booking,
    );

    developer.log(
      'Sending driver assigned notification to $customerEmail for ${booking.referenceNumber}',
      name: 'EmailService',
    );

    return _sendEmail(
      to: customerEmail,
      subject: 'Driver Assigned - ${booking.referenceNumber}',
      html: html,
    );
  }

  /// Send trip started notification to customer
  ///
  /// Called when a driver starts the trip (status → in_progress).
  Future<EmailResult> sendTripStarted(Booking booking) async {
    final customerEmail = await _getUserEmail(booking.customerId);
    if (customerEmail == null) {
      developer.log(
        'Cannot send trip started email: customer email not found',
        name: 'EmailService',
      );
      return const EmailResult(
        success: false,
        error: 'Customer email not found',
      );
    }

    final customerName = booking.customer?.fullName ??
        await _getUserName(booking.customerId) ??
        'Customer';

    final html = EmailTemplates.tripStarted(
      customerName: customerName,
      booking: booking,
    );

    developer.log(
      'Sending trip started notification to $customerEmail for ${booking.referenceNumber}',
      name: 'EmailService',
    );

    return _sendEmail(
      to: customerEmail,
      subject: 'Your Trip Has Started - ${booking.referenceNumber}',
      html: html,
    );
  }

  /// Send trip receipt to customer
  ///
  /// Called after a trip is completed.
  Future<EmailResult> sendTripReceipt(Booking booking) async {
    final customerEmail = await _getUserEmail(booking.customerId);
    if (customerEmail == null) {
      developer.log(
        'Cannot send trip receipt: customer email not found',
        name: 'EmailService',
      );
      return const EmailResult(
        success: false,
        error: 'Customer email not found',
      );
    }

    final customerName = booking.customer?.fullName ??
        await _getUserName(booking.customerId) ??
        'Customer';

    final html = EmailTemplates.tripReceipt(
      customerName: customerName,
      booking: booking,
    );

    developer.log(
      'Sending trip receipt to $customerEmail for ${booking.referenceNumber}',
      name: 'EmailService',
    );

    return _sendEmail(
      to: customerEmail,
      subject: 'Trip Receipt - ${booking.referenceNumber}',
      html: html,
    );
  }

  /// Send booking cancellation notification
  ///
  /// Called after a booking is cancelled.
  /// Sends to both customer and driver (if assigned).
  Future<List<EmailResult>> sendBookingCancelled(
    Booking booking, {
    String? reason,
  }) async {
    final results = <EmailResult>[];

    // Send to customer
    final customerEmail = await _getUserEmail(booking.customerId);
    if (customerEmail != null) {
      final customerName = booking.customer?.fullName ??
          await _getUserName(booking.customerId) ??
          'Customer';

      final customerHtml = EmailTemplates.bookingCancelled(
        recipientName: customerName,
        booking: booking,
        isCustomer: true,
        reason: reason ?? booking.cancellationReason,
      );

      developer.log(
        'Sending cancellation to customer $customerEmail for ${booking.referenceNumber}',
        name: 'EmailService',
      );

      final customerResult = await _sendEmail(
        to: customerEmail,
        subject: 'Booking Cancelled - ${booking.referenceNumber}',
        html: customerHtml,
      );
      results.add(customerResult);
    }

    // Send to driver if assigned
    if (booking.driverId != null) {
      final driverEmail = await _getUserEmail(booking.driverId!);
      if (driverEmail != null) {
        final driverName = booking.driver?.fullName ??
            await _getUserName(booking.driverId!) ??
            'Driver';

        final driverHtml = EmailTemplates.bookingCancelled(
          recipientName: driverName,
          booking: booking,
          isCustomer: false,
          reason: reason ?? booking.cancellationReason,
        );

        developer.log(
          'Sending cancellation to driver $driverEmail for ${booking.referenceNumber}',
          name: 'EmailService',
        );

        final driverResult = await _sendEmail(
          to: driverEmail,
          subject: 'Booking Cancelled - ${booking.referenceNumber}',
          html: driverHtml,
        );
        results.add(driverResult);
      }
    }

    return results;
  }
}
