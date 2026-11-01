import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
import 'package:classipod/core/theme/ipod_gradients.dart';
import 'package:classipod/core/theme/ipod_typography.dart';
import 'package:classipod/features/custom_screen_elements/custom_screen.dart';
import 'package:classipod/features/settings/services/device_storage_service.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeviceInfoScreen extends ConsumerStatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  ConsumerState<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends ConsumerState<DeviceInfoScreen>
    with CustomScreen {
  final DeviceStorageService _storageService = DeviceStorageService();
  DeviceStorageInfo? _storage;
  Object? _error;
  bool _loading = true;

  @override
  String get routeName => Routes.info.name;

  @override
  List<String> get displayItems => const ['Storage'];

  @override
  Future<void> onSelectPressed() => _loadStorage();

  @override
  void initState() {
    super.initState();
    _loadStorage();
  }

  Future<void> _loadStorage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        throw UnsupportedError('Device info is currently available on Android.');
      }
      final info = await _storageService.getStorageInfo();
      if (mounted) setState(() => _storage = info);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatBytes(int bytes) {
    final value = bytes / (1024 * 1024 * 1024);
    return '${value.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final storage = _storage;
    final used = storage?.usedBytes ?? 0;
    final audio = storage == null
        ? 0
        : storage.audioBytes.clamp(0, storage.usedBytes);
    final other = storage == null ? 0 : storage.otherBytes;
    final free = storage?.availableBytes ?? 0;
    final total = storage?.totalBytes ?? 0;
    final usedFraction = total == 0 ? 0.0 : used / total;
    final audioFraction = total == 0 ? 0.0 : audio / total;
    final otherFraction = total == 0 ? 0.0 : other / total;

    return CupertinoPageScaffold(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Device Information',
                    style: IpodTypography.title.copyWith(
                      color: context.appPrimaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Could not read device storage.',
                              style: IpodTypography.body.copyWith(
                                color: context.appPrimaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            CupertinoButton(
                              onPressed: _loadStorage,
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : storage == null
                    ? const SizedBox.shrink()
                    : _buildStorageContent(
                        context,
                        storage,
                        audio,
                        other,
                        free,
                        audioFraction,
                        otherFraction,
                        usedFraction,
                      ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 4),
                onPressed: _loadStorage,
                child: Text(
                  'Refresh',
                  style: IpodTypography.metadata.copyWith(
                    color: context.appPrimaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageContent(
    BuildContext context,
    DeviceStorageInfo storage,
    int audio,
    int other,
    int free,
    double audioFraction,
    double otherFraction,
    double usedFraction,
  ) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _storageFigure(
                  context,
                  _formatBytes(storage.usedBytes),
                  'Used',
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.android, size: 54, color: Color(0xFF83B735)),
              ),
              Expanded(
                child: _storageFigure(
                  context,
                  _formatBytes(free),
                  'Available',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    flex: (audioFraction * 10000).round().clamp(0, 10000),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(gradient: IpodGradients.progress),
                    ),
                  ),
                  Expanded(
                    flex: (otherFraction * 10000).round().clamp(0, 10000),
                    child: const ColoredBox(color: Color(0xFF8C9FD7)),
                  ),
                  Expanded(
                    flex: ((1 - usedFraction) * 10000).round().clamp(0, 10000),
                    child: const ColoredBox(color: Color(0xFFE7E8E5)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _category(context, const Color(0xFF35AEE5), 'Audio', audio),
              ),
              Expanded(
                child: _category(context, const Color(0xFF8298D7), 'Other', other),
              ),
              Expanded(
                child: _category(context, const Color(0xFFDDE2E5), 'Free', free),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: context.appOutlineColor),
          Row(
            children: [
              const Icon(Icons.music_note, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audio storage', style: IpodTypography.menu.copyWith(
                      color: context.appPrimaryTextColor,
                    )),
                    Text(
                      '${_formatBytes(audio)} indexed on this device',
                      style: IpodTypography.description.copyWith(
                        color: context.appSecondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Storage figures are provided by Android. Audio is calculated from indexed media files; Other is an estimate of the remaining used space.',
            textAlign: TextAlign.center,
            style: IpodTypography.caption.copyWith(
              color: context.appSecondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _storageFigure(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: IpodTypography.title.copyWith(
            fontSize: 19,
            color: context.appPrimaryTextColor,
          ),
        ),
        Text(
          label,
          style: IpodTypography.description.copyWith(
            color: context.appSecondaryTextColor,
          ),
        ),
      ],
    );
  }

  Widget _category(BuildContext context, Color color, String label, int bytes) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: IpodTypography.metadata.copyWith(
                  color: context.appPrimaryTextColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatBytes(bytes),
          style: IpodTypography.caption.copyWith(
            color: context.appSecondaryTextColor,
          ),
        ),
      ],
    );
  }
}
