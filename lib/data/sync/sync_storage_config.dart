class SyncStorageConfig {
  const SyncStorageConfig({
    required this.enabled,
    required this.endpoint,
    required this.region,
    required this.bucket,
    required this.folder,
    required this.accessKey,
    required this.secretKey,
    required this.usePathStyle,
  });

  const SyncStorageConfig.empty()
    : enabled = false,
      endpoint = '',
      region = 'us-east-1',
      bucket = '',
      folder = 'taskflow-sync',
      accessKey = '',
      secretKey = '',
      usePathStyle = true;

  final bool enabled;
  final String endpoint;
  final String region;
  final String bucket;
  final String folder;
  final String accessKey;
  final String secretKey;
  final bool usePathStyle;

  bool get isComplete {
    return endpoint.trim().isNotEmpty &&
        region.trim().isNotEmpty &&
        bucket.trim().isNotEmpty &&
        accessKey.trim().isNotEmpty &&
        secretKey.trim().isNotEmpty;
  }

  SyncStorageConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? region,
    String? bucket,
    String? folder,
    String? accessKey,
    String? secretKey,
    bool? usePathStyle,
  }) {
    return SyncStorageConfig(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      region: region ?? this.region,
      bucket: bucket ?? this.bucket,
      folder: folder ?? this.folder,
      accessKey: accessKey ?? this.accessKey,
      secretKey: secretKey ?? this.secretKey,
      usePathStyle: usePathStyle ?? this.usePathStyle,
    );
  }
}
