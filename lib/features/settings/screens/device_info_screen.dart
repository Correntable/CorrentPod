import 'package:classipod/core/extensions/build_context_extensions.dart';
import 'package:classipod/core/navigation/routes.dart';
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
  List<String> get displayItems => const ['Refresh'];

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
        throw UnsupportedError('Device information is available on Android only.');
      }
      final info = await _storageService.getStorageInfo();
      if (mounted) setState(() => _storage = info);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatBytes(int bytes) =>
      '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';

  @override
  Widget build(BuildContext context) {
    final storage = _storage;
    final used = storage?.usedBytes ?? 0;
    final free = storage?.availableBytes ?? 0;
    final audio = storage?.audioBytes.clamp(0, used) ?? 0;
    final video = storage?.videoBytes.clamp(0, used) ?? 0;
    final photos = storage?.photoBytes.clamp(0, used) ?? 0;
    final other = (used - audio - video - photos).clamp(0, used);
    final total = storage?.totalBytes ?? 0;
    final usedRatio = total == 0 ? 0.0 : (used / total).clamp(0.0, 1.0);

    return CupertinoPageScaffold(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEAF5FC), Color(0xFFC8DCEC), Color(0xFFB6CDE0)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : _error != null
                    ? _errorContent(context)
                    : storage == null
                        ? const SizedBox.shrink()
                        : _storageContent(
                            context,
                            storage,
                            audio: audio,
                            video: video,
                            photos: photos,
                            other: other,
                            usedRatio: usedRatio,
                          ),
          ),
        ),
      ),
    );
  }

  Widget _errorContent(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not read device storage.',
                textAlign: TextAlign.center,
                style: IpodTypography.body.copyWith(color: const Color(0xFF243342))),
            CupertinoButton(onPressed: _loadStorage, child: const Text('Try Again')),
          ],
        ),
      );

  Widget _storageContent(
    BuildContext context,
    DeviceStorageInfo storage, {
    required int audio,
    required int video,
    required int photos,
    required int other,
    required double usedRatio,
  }) {
    final free = storage.availableBytes;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 390;
      return Column(
        children: [
          Text('Device Information',
              textAlign: TextAlign.center,
              style: IpodTypography.title.copyWith(
                color: const Color(0xFF172B3D),
                fontSize: compact ? 20 : 23,
                fontWeight: FontWeight.w700,
              )),
          SizedBox(height: compact ? 12 : 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _storageFigure(_formatBytes(storage.usedBytes), 'Used')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.android, size: compact ? 66 : 82,
                    color: const Color(0xFF83B735)),
              ),
              Expanded(child: _storageFigure(_formatBytes(free), 'Available')),
            ],
          ),
          SizedBox(height: compact ? 20 : 34),
          _usageBar(usedRatio),
          SizedBox(height: compact ? 14 : 22),
          Row(children: [
            Expanded(child: _category(const Color(0xFF35AEE5), 'Audio', audio)),
            Expanded(child: _category(const Color(0xFF8298D7), 'Video', video)),
            Expanded(child: _category(const Color(0xFFE8B83D), 'Photos', photos)),
            Expanded(child: _category(const Color(0xFFE99543), 'Other', other)),
          ]),
          const Spacer(),
          Container(height: 1, color: const Color(0x66869EAF)),
          SizedBox(height: compact ? 8 : 14),
          Row(children: [
            const Icon(Icons.music_note, size: 34, color: Color(0xFF263D50)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Music Library', style: IpodTypography.menu.copyWith(
                  color: const Color(0xFF172B3D), fontWeight: FontWeight.w700)),
                Text('${_formatBytes(audio)} stored on this device',
                    style: IpodTypography.description.copyWith(
                      color: const Color(0xFF40566A))),
              ],
            )),
          ]),
          SizedBox(height: compact ? 5 : 10),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 18),
            onPressed: _loadStorage,
            child: Text('Refresh', style: IpodTypography.metadata.copyWith(
              color: const Color(0xFF172B3D), fontWeight: FontWeight.w700)),
          ),
        ],
      );
    });
  }

  Widget _storageFigure(String value, String label) => Column(
        children: [
          Text(value, textAlign: TextAlign.center,
              style: IpodTypography.title.copyWith(
                fontSize: 21, fontWeight: FontWeight.w700,
                color: const Color(0xFF172B3D))),
          Text(label, style: IpodTypography.description.copyWith(
              color: const Color(0xFF40566A))),
        ],
      );

  Widget _usageBar(double ratio) => Container(
        height: 25,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF91AFC4), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x55849DB0), blurRadius: 3, offset: Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            Align(alignment: Alignment.centerLeft, child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xFF8BE0FF), Color(0xFF31B4F0), Color(0xFF087CCB)])),
              ),
            )),
            Positioned(left: 0, right: 0, top: 2, height: 5,
              child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0x66FFFFFF), const Color(0x00FFFFFF)]),
                borderRadius: BorderRadius.circular(20)))),
          ]),
        ),
      );

  Widget _category(Color color, String label, int bytes) => Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 11, height: 11,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2),
                boxShadow: const [BoxShadow(color: Color(0x33809AAA), blurRadius: 2, offset: Offset(0, 1))])),
            const SizedBox(width: 5),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
              style: IpodTypography.metadata.copyWith(
                color: const Color(0xFF172B3D), fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 5),
          Text(_formatBytes(bytes), style: IpodTypography.caption.copyWith(
            color: const Color(0xFF40566A))),
        ],
      );
}
