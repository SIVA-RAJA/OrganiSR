import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';

class BackupScreen extends StatefulWidget {
  final VoidCallback onDataRestored;

  const BackupScreen({super.key, required this.onDataRestored});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  String _appPath = '';
  int _dbSize = 0;
  int _mediaCount = 0;
  int _mediaSize = 0;
  DateTime? _lastBackupDate;
  bool _autoBackupEnabled = true;
  bool _hasBackup = false;
  int _backupFileSize = 0;
  String _backupPath = '';

  @override
  void initState() {
    super.initState();
    _loadStorageDetails();
  }

  Future<void> _loadStorageDetails() async {
    setState(() => _isLoading = true);
    await StorageService.instance.initialize();

    final appDir = StorageService.instance.appBaseDir;
    final dbFile = File(StorageService.instance.dbFilePath);
    final mediaDir = StorageService.instance.mediaDir;

    int dbSizeBytes = 0;
    if (await dbFile.exists()) {
      dbSizeBytes = await dbFile.length();
    }

    int mediaFileCount = 0;
    int mediaSizeBytes = 0;
    if (await mediaDir.exists()) {
      final mediaEntities = mediaDir.listSync();
      for (final e in mediaEntities) {
        if (e is File) {
          mediaFileCount++;
          mediaSizeBytes += await e.length();
        }
      }
    }

    final lastDate = await StorageService.instance.getLastBackupDate();
    final autoEnabled = await StorageService.instance.isAutoBackupEnabled();
    final exists = StorageService.instance.hasBackup();
    final bSize = StorageService.instance.getBackupSize();

    if (mounted) {
      setState(() {
        _appPath = appDir.path;
        _dbSize = dbSizeBytes;
        _mediaCount = mediaFileCount;
        _mediaSize = mediaSizeBytes;
        _lastBackupDate = lastDate;
        _autoBackupEnabled = autoEnabled;
        _hasBackup = exists;
        _backupFileSize = bSize;
        _backupPath = StorageService.instance.singleBackupFilePath;
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _triggerManualBackup() async {
    setState(() => _isProcessing = true);
    try {
      final file = await StorageService.instance.createBackup();
      if (!mounted) return;
      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup updated successfully!')),
        );
      }
      await _loadStorageDetails();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreBackup([File? customFile]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Restore Backup (Safe Merge)?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Restoring will bring back all old pages and media without deleting any current pages you created.\n\nYour new data will never be deleted.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore & Merge', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final result = await StorageService.instance.restoreAndMergeBackup(customFile);

      if (!mounted) return;
      if (result.success) {
        widget.onDataRestored();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully restored ${result.restoredPages} old pages!\nPreserved all ${result.preservedPages} existing pages.',
            ),
          ),
        );
        await _loadStorageDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: ${result.errorMessage}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during restore: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickAndRestoreExternalFile() async {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['osr', 'zip'],
    );

    if (result != null && result.path != null) {
      final file = File(result.path!);
      await _restoreBackup(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Storage & Backup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Local Storage Folder Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.folder_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Local Storage',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _appPath,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const Divider(height: 24, color: Color(0xFF222222)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _storageStat(
                          label: 'Database',
                          value: _formatBytes(_dbSize),
                          icon: Icons.storage_outlined,
                        ),
                        _storageStat(
                          label: 'Media Files',
                          value: '$_mediaCount (${_formatBytes(_mediaSize)})',
                          icon: Icons.image_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Single Unified Backup Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasBackup ? Icons.shield_outlined : Icons.cloud_off_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _hasBackup ? 'Backup Available' : 'No Backup Yet',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastBackupDate != null
                                    ? 'Last updated: ${DateFormat('MMM d, yyyy • HH:mm').format(_lastBackupDate!)}'
                                    : 'Tap "Backup Now" to create your single backup file.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_hasBackup)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatBytes(_backupFileSize),
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Backup Path
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D0D),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _backupPath,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF777777)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Smart Merge Explanation Banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Safe Merge: Restoring keeps both your current and old data intact. New pages are never deleted.',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons for Single Backup
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.backup_outlined, size: 18),
                            label: const Text('Backup Now', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _triggerManualBackup,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.restore_outlined, size: 18, color: Colors.white),
                            label: const Text('Restore', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF333333)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _hasBackup ? () => _restoreBackup() : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Weekly Auto-Backup Switch
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.autorenew_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly Auto-Backup',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Automatically updates backup once a week',
                              style: TextStyle(fontSize: 10, color: Color(0xFF777777)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _autoBackupEnabled,
                      activeThumbColor: Colors.white,
                      onChanged: (val) async {
                        await StorageService.instance.setAutoBackupEnabled(val);
                        setState(() => _autoBackupEnabled = val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Optional external file restore
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.file_open_outlined, size: 16, color: Colors.white54),
                  label: const Text('Restore from External File...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onPressed: _pickAndRestoreExternalFile,
                ),
              ),
            ],
          ),

          if (_isProcessing)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Merging backup & media...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _storageStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white60),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5))),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ],
    );
  }
}
