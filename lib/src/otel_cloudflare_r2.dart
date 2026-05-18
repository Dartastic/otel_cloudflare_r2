// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_cloudflare_r2_suppression.dart';

const _tracerName = 'dartastic_otel_libs_cloudflare_r2';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class CloudflareR2Result {
  const CloudflareR2Result({
    this.bucket,
    this.objectKey,
    this.bytes,
    this.parts,
    this.classAOperations,
    this.classBOperations,
    this.jurisdiction,
    this.location,
    this.viaCustomDomain,
    this.requestId,
    this.statusCode,
  });

  /// Bucket name.
  final String? bucket;

  /// Object key.
  final String? objectKey;

  /// Object bytes (uploads/downloads).
  final int? bytes;

  /// Parts in a multipart upload.
  final int? parts;

  /// Class A operations counted (writes: PUT/COPY/POST/LIST — pricier
  /// than Class B).
  final int? classAOperations;

  /// Class B operations counted (reads: GET/HEAD).
  final int? classBOperations;

  /// `default` / `eu` / `fedramp` — R2 jurisdiction.
  final String? jurisdiction;

  /// Optional `cf-r2-location-hint` echo (`wnam`, `enam`, `weur`,
  /// `eeur`, `apac`, `oc`).
  final String? location;

  /// Whether served via a custom R2 domain (cf-cache hits possible
  /// vs S3-API which never caches).
  final bool? viaCustomDomain;

  /// `cf-ray`.
  final String? requestId;

  final int? statusCode;
}

class CloudflareR2CallResult<T> {
  const CloudflareR2CallResult({required this.value, this.result});
  final T value;
  final CloudflareR2Result? result;
}

/// Wraps a Cloudflare R2 call in a CLIENT span. [operation] is one of
/// `ListBuckets`, `CreateBucket`, `DeleteBucket`, `PutObject`,
/// `GetObject`, `HeadObject`, `DeleteObject`, `CopyObject`,
/// `ListObjectsV2`, `CreateMultipartUpload`, `UploadPart`,
/// `CompleteMultipartUpload`, `AbortMultipartUpload`,
/// `PutBucketCors`, `GetBucketCors`, `PutBucketLifecycleConfiguration`,
/// `GenerateSignedUrl`, `worker.binding.put`, `worker.binding.get`.
Future<T> tracedCloudflareR2<T>({
  required String operation,
  required Future<CloudflareR2CallResult<T>> Function() invoke,
}) async {
  if (cloudflareR2InstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'cloudflare_r2',
    'rpc.method': operation,
    'cloudflare_r2.operation': operation,
  };

  final span = _tracer().startSpan(
    'cloudflare_r2 $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.bucket != null) {
        extras.add(OTel.attributeString(
          'cloudflare_r2.bucket',
          r.result!.bucket!,
        ));
      }
      if (r.result!.objectKey != null) {
        extras.add(OTel.attributeString(
          'cloudflare_r2.object.key',
          r.result!.objectKey!,
        ));
      }
      if (r.result!.bytes != null) {
        extras.add(OTel.attributeInt(
          'cloudflare_r2.bytes',
          r.result!.bytes!,
        ));
      }
      if (r.result!.parts != null) {
        extras.add(OTel.attributeInt(
          'cloudflare_r2.parts',
          r.result!.parts!,
        ));
      }
      if (r.result!.classAOperations != null) {
        extras.add(OTel.attributeInt(
          'cloudflare_r2.class_a_ops',
          r.result!.classAOperations!,
        ));
      }
      if (r.result!.classBOperations != null) {
        extras.add(OTel.attributeInt(
          'cloudflare_r2.class_b_ops',
          r.result!.classBOperations!,
        ));
      }
      if (r.result!.jurisdiction != null) {
        extras.add(OTel.attributeString(
          'cloudflare_r2.jurisdiction',
          r.result!.jurisdiction!,
        ));
      }
      if (r.result!.location != null) {
        extras.add(OTel.attributeString(
          'cloudflare_r2.location',
          r.result!.location!,
        ));
      }
      if (r.result!.viaCustomDomain != null) {
        extras.add(OTel.attributeBool(
          'cloudflare_r2.via_custom_domain',
          r.result!.viaCustomDomain!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'cloudflare_r2.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Cloudflare R2 HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
