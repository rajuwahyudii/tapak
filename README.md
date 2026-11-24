# tapak

An in-app HTTP inspector for Flutter. See every API call — request, response, headers, timing — right inside your running app. Like Chucker on Android or Alice for Flutter.

## Features

- Logs all Dio requests automatically
- Color-coded HTTP method and status code badges
- Request/response timing
- Full headers and body viewer (with copy-to-clipboard)
- Search/filter by URL or method
- Error highlighting (the overlay button turns red)
- Configurable transaction cap (default 200)
- Zero UI dependencies beyond Flutter Material

## Getting started

Add to `pubspec.yaml`:

```yaml
dependencies:
  tapak: ^0.1.0
```

## Usage

### 1. Add the interceptor — Dio

```dart
import 'package:flutter/foundation.dart';
import 'package:tapak/tapak.dart';

final dio = Dio()
  ..interceptors.add(TapakInterceptor(enabled: kDebugMode));
```

### 1. Wrap the client — `http` package

```dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tapak/tapak.dart';

final client = TapakHttpClient(http.Client(), enabled: kDebugMode);

// Use exactly like a regular http.Client:
final response = await client.get(Uri.parse('https://example.com/api'));

// Close when done (e.g. in dispose):
client.close();
```

### 2a. Overlay button (recommended)

Wrap the child inside `MaterialApp.builder` so the Navigator is available:

```dart
MaterialApp(
  builder: (context, child) => TapakOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
  home: const MyHomePage(),
)
```

The floating button shows the live request count and turns red when any request has errored. Tap it to open the inspector.

### 2b. Navigate manually

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const TapakInspectorScreen()),
);
```

## Configuration

```dart
// Keep more transactions in memory (default: 200)
TapakStore.instance.maxTransactions = 500;

// Clear logs programmatically
TapakStore.instance.clear();

// Listen to changes (ChangeNotifier)
TapakStore.instance.addListener(() {
  final count = TapakStore.instance.transactions.length;
});
```

## File structure

```
lib/
  tapak.dart                        ← public barrel export
  src/
    model/http_transaction.dart     ← request/response data model
    store/tapak_store.dart          ← ChangeNotifier singleton
    interceptor/tapak_interceptor.dart  ← Dio interceptor
    ui/
      tapak_inspector_screen.dart   ← transaction list screen
      tapak_detail_screen.dart      ← overview / request / response tabs
      tapak_overlay.dart            ← floating launcher button
      widgets/
        method_badge.dart
        status_badge.dart
        body_viewer.dart
```
