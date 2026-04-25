import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:taskflow/data/sync/sync_storage_config.dart';

class S3ObjectStorageClient {
  S3ObjectStorageClient(this.config, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final SyncStorageConfig config;
  final http.Client _httpClient;

  String get _normalizedFolder {
    final trimmed = config.folder.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.replaceAll(RegExp(r'^/+|/+$'), '');
  }

  String _keyWithFolder(String key) {
    final folder = _normalizedFolder;
    if (folder.isEmpty) {
      return key;
    }
    return '$folder/$key';
  }

  Uri _buildUri({required String key, Map<String, String>? query}) {
    final endpoint = config.endpoint.trim();
    final rawEndpoint =
        endpoint.startsWith('http://') || endpoint.startsWith('https://')
        ? endpoint
        : 'https://$endpoint';
    final base = Uri.parse(rawEndpoint);

    final encodedKey = key
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');

    if (config.usePathStyle) {
      final pathSegments = <String>[
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        config.bucket.trim(),
        ...encodedKey.split('/').where((segment) => segment.isNotEmpty),
      ];
      return base.replace(pathSegments: pathSegments, queryParameters: query);
    }

    final host = '${config.bucket.trim()}.${base.host}';
    return base.replace(
      host: host,
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        ...encodedKey.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: query,
    );
  }

  Future<void> testConnection() async {
    final uri = _buildUri(
      key: '',
      query: <String, String>{
        'list-type': '2',
        'max-keys': '1',
        if (_normalizedFolder.isNotEmpty) 'prefix': '$_normalizedFolder/',
      },
    );
    final response = await _signedRequest(uri: uri, method: 'GET');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('连接失败: HTTP ${response.statusCode} ${response.body}');
    }
  }

  Future<String?> getText(String key) async {
    final uri = _buildUri(key: _keyWithFolder(key));
    final response = await _signedRequest(uri: uri, method: 'GET');
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('读取失败: HTTP ${response.statusCode} ${response.body}');
    }
    return response.body;
  }

  Future<void> putText(String key, String content) async {
    final uri = _buildUri(key: _keyWithFolder(key));
    final response = await _signedRequest(
      uri: uri,
      method: 'PUT',
      body: utf8.encode(content),
      headers: const <String, String>{'content-type': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('写入失败: HTTP ${response.statusCode} ${response.body}');
    }
  }

  Future<http.Response> _signedRequest({
    required Uri uri,
    required String method,
    List<int>? body,
    Map<String, String>? headers,
  }) async {
    final payload = body ?? const <int>[];
    final payloadHash = _sha256Hex(payload);
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);

    final canonicalHeaders = <String, String>{
      'host': _hostHeader(uri),
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': amzDate,
      ...?headers,
    };

    final signedHeaders =
        canonicalHeaders.keys.map((key) => key.toLowerCase()).toList()..sort();

    final canonicalHeadersText = signedHeaders
        .map((key) => '$key:${canonicalHeaders[key]!.trim()}')
        .join('\n');

    final canonicalRequest = [
      method.toUpperCase(),
      _canonicalPath(uri),
      _canonicalQuery(uri),
      '$canonicalHeadersText\n',
      signedHeaders.join(';'),
      payloadHash,
    ].join('\n');

    final credentialScope =
        '$dateStamp/${config.region.trim()}/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _sha256Hex(utf8.encode(canonicalRequest)),
    ].join('\n');

    final signingKey = _signingKey(
      config.secretKey.trim(),
      dateStamp,
      config.region.trim(),
    );
    final signature = _hmacSha256Hex(signingKey, stringToSign);

    final authorization =
        'AWS4-HMAC-SHA256 Credential=${config.accessKey.trim()}/$credentialScope, '
        'SignedHeaders=${signedHeaders.join(';')}, Signature=$signature';

    final requestHeaders = <String, String>{
      ...canonicalHeaders,
      'authorization': authorization,
    };

    return _httpClient
        .send(
          http.Request(method.toUpperCase(), uri)
            ..headers.addAll(requestHeaders)
            ..bodyBytes = payload,
        )
        .then(http.Response.fromStream);
  }

  String _canonicalPath(Uri uri) {
    if (uri.path.isEmpty) {
      return '/';
    }
    return uri.pathSegments.isEmpty
        ? '/'
        : '/${uri.pathSegments.map(Uri.encodeComponent).join('/')}';
  }

  String _canonicalQuery(Uri uri) {
    if (uri.queryParametersAll.isEmpty) {
      return '';
    }
    final entries = <MapEntry<String, String>>[];
    uri.queryParametersAll.forEach((key, values) {
      for (final value in values) {
        entries.add(MapEntry(key, value));
      }
    });
    entries.sort((a, b) {
      final keyCompare = a.key.compareTo(b.key);
      if (keyCompare != 0) {
        return keyCompare;
      }
      return a.value.compareTo(b.value);
    });
    return entries
        .map((entry) => '${_uriEncode(entry.key)}=${_uriEncode(entry.value)}')
        .join('&');
  }

  String _uriEncode(String value) {
    return Uri.encodeQueryComponent(
      value,
    ).replaceAll('+', '%20').replaceAll('*', '%2A').replaceAll('%7E', '~');
  }

  String _hostHeader(Uri uri) {
    if (uri.hasPort && uri.port != 443 && uri.port != 80) {
      return '${uri.host}:${uri.port}';
    }
    return uri.host;
  }

  String _sha256Hex(List<int> input) {
    return sha256.convert(input).toString();
  }

  List<int> _hmacSha256(List<int> key, String message) {
    return Hmac(sha256, key).convert(utf8.encode(message)).bytes;
  }

  String _hmacSha256Hex(List<int> key, String message) {
    return Hmac(sha256, key).convert(utf8.encode(message)).toString();
  }

  List<int> _signingKey(String secretKey, String date, String region) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), date);
    final kRegion = _hmacSha256(kDate, region);
    final kService = _hmacSha256(kRegion, 's3');
    return _hmacSha256(kService, 'aws4_request');
  }

  String _amzDate(DateTime time) {
    return '${time.year}${_twoDigits(time.month)}${_twoDigits(time.day)}T'
        '${_twoDigits(time.hour)}${_twoDigits(time.minute)}${_twoDigits(time.second)}Z';
  }

  String _dateStamp(DateTime time) {
    return '${time.year}${_twoDigits(time.month)}${_twoDigits(time.day)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
