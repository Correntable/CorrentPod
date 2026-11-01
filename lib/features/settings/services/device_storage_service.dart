import 'package:flutter/services.dart';

class DeviceStorageInfo {
  const DeviceStorageInfo({
    required this.totalBytes,
    required this.availableBytes,
    required this.audioBytes,
    required this.videoBytes,
    required this.photoBytes,
  });

  final int totalBytes;
  final int availableBytes;
  final int audioBytes;
  final int videoBytes;
  final int photoBytes;

  int get usedBytes => (totalBytes - availableBytes).clamp(0, totalBytes);
  int get otherBytes => (usedBytes - audioBytes).clamp(0, usedBytes);

  factory DeviceStorageInfo.fromMap(Map<Object?, Object?> map) {
    return DeviceStorageInfo(
      totalBytes: (map['totalBytes'] as num).toInt(),
      availableBytes: (map['availableBytes'] as num).toInt(),
      audioBytes: (map['audioBytes'] as num?)?.toInt() ?? 0,
      videoBytes: (map['videoBytes'] as num?)?.toInt() ?? 0,
      photoBytes: (map['photoBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeviceStorageService {
  static const MethodChannel _channel =
      MethodChannel('com.adeeteya.classipod/device_storage');

  Future<DeviceStorageInfo> getStorageInfo() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getStorageInfo',
    );
    if (result == null) {
      throw PlatformException(
        code: 'storage_unavailable',
        message: 'Device storage information is unavailable.',
      );
    }
    return DeviceStorageInfo.fromMap(result);
  }
}
