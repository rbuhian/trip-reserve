import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/document.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/supabase_provider.dart';
import '../../../repositories/document_repository.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/document_upload_card.dart';

/// Provider for driver's license document
final driversLicenseProvider = FutureProvider<Document?>((ref) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getDriversLicense();
});

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  XFile? _pendingLicense;
  bool _isUploadingLicense = false;

  Future<void> _pickLicense() async {
    final file = await ImagePickerHelper.pickDocument();
    if (file != null) {
      setState(() {
        _pendingLicense = file;
      });
      await _uploadLicense();
    }
  }

  Future<void> _uploadLicense() async {
    if (_pendingLicense == null) return;

    setState(() => _isUploadingLicense = true);

    try {
      final user = ref.read(authUserProvider).value;
      if (user == null) throw Exception('Not authenticated');

      final storageService = ref.read(storageServiceProvider);
      final documentRepo = ref.read(documentRepositoryProvider);

      final result = await storageService.uploadDocument(
        userId: user.id,
        documentType: DocumentType.driversLicense,
        file: _pendingLicense!,
      );

      await documentRepo.uploadDocument(DocumentUpload(
        documentType: DocumentType.driversLicense,
        storagePath: result.storagePath,
        url: result.url,
        fileName: result.fileName,
        fileSize: result.fileSize,
        mimeType: result.mimeType,
      ));

      // Refresh the license provider
      ref.invalidate(driversLicenseProvider);

      if (mounted) {
        setState(() => _pendingLicense = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('License uploaded successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLicense = false);
      }
    }
  }

  Future<void> _deleteLicense() async {
    final license = ref.read(driversLicenseProvider).value;
    if (license == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete License?'),
        content: const Text('Are you sure you want to delete your uploaded license?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final storageService = ref.read(storageServiceProvider);
      final documentRepo = ref.read(documentRepositoryProvider);

      await storageService.deleteDocument(license.storagePath);
      await documentRepo.deleteDocument(license.id);

      ref.invalidate(driversLicenseProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('License deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authUserProvider);
    final licenseAsync = ref.watch(driversLicenseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile header
          user.when(
            data: (userData) => _buildProfileHeader(userData, colorScheme),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error loading profile'),
          ),

          const SizedBox(height: 32),

          // Documents section
          Text(
            'Documents',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your documents for verification',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Driver's License
          licenseAsync.when(
            data: (license) => DocumentUploadCard(
              documentType: DocumentType.driversLicense,
              currentDocument: license,
              pendingFile: _pendingLicense,
              isUploading: _isUploadingLicense,
              onTap: _pickLicense,
              onDelete: license != null ? _deleteLicense : null,
              onView: license != null
                  ? () => _viewDocument(license.url)
                  : null,
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error),
                  const SizedBox(height: 8),
                  Text('Error loading documents', style: TextStyle(color: colorScheme.error)),
                  TextButton(
                    onPressed: () => ref.invalidate(driversLicenseProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Account actions
          Text(
            'Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Sign out button
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(dynamic user, ColorScheme colorScheme) {
    if (user == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 36,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            backgroundImage: user.avatarUrl != null
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null
                ? Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (user.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.phone!,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () {
              // TODO: Navigate to edit profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit profile coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: Icon(
              Icons.edit_outlined,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _viewDocument(String url) async {
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showDocumentOptions(url);
        }
      }
    } catch (e) {
      if (mounted) {
        _showDocumentOptions(url);
      }
    }
  }

  void _showDocumentOptions(String url) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy URL'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('URL copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Open in Browser'),
                onTap: () async {
                  Navigator.pop(context);
                  final uri = Uri.parse(url);
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }
}
