// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_cloudflare_r2/otel_cloudflare_r2.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_cloudflare_r2-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('PutObject records class A op + jurisdiction + location', () async {
    await tracedCloudflareR2<String>(
      operation: 'PutObject',
      invoke: () async => const CloudflareR2CallResult(
        value: 'ok',
        result: CloudflareR2Result(
          bucket: 'assets',
          objectKey: 'images/photo.png',
          bytes: 524288,
          classAOperations: 1,
          jurisdiction: 'eu',
          location: 'weur',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('cloudflare_r2 PutObject')!);
    expect(a['cloudflare_r2.bucket'], 'assets');
    expect(a['cloudflare_r2.class_a_ops'], 1);
    expect(a['cloudflare_r2.jurisdiction'], 'eu');
    expect(a['cloudflare_r2.location'], 'weur');
  });

  test('GetObject via custom domain recorded', () async {
    await tracedCloudflareR2<String>(
      operation: 'GetObject',
      invoke: () async => const CloudflareR2CallResult(
        value: 'ok',
        result: CloudflareR2Result(
          classBOperations: 1,
          viaCustomDomain: true,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('cloudflare_r2 GetObject')!);
    expect(a['cloudflare_r2.via_custom_domain'], true);
    expect(a['cloudflare_r2.class_b_ops'], 1);
  });

  test('suppression skips spans', () async {
    await runWithoutCloudflareR2InstrumentationAsync(() async {
      await tracedCloudflareR2<String>(
        operation: 'ListBuckets',
        invoke: () async => const CloudflareR2CallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('cloudflare_r2 '), isEmpty);
  });
}
