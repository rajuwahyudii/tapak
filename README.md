# Tapak

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.0+-blue.svg" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.0+-blue.svg" alt="Dart">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</p>

**Tapak** is a lightweight in-app HTTP inspector for Flutter. See every API call — request, response, headers, timing — right inside your running app.

Inspired by [Alice](https://github.com/jhomlala/alice) and [Chucker](https://github.com/ChuckerTeam/chucker).

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📡 **HTTP Logging** | Automatically logs all Dio and http requests |
| 🎨 **Beautiful UI** | Color-coded method badges and status indicators |
| ⏱️ **Timing** | Request/response duration tracking |
| 📋 **Full Inspection** | Headers, body, query params with copy-to-clipboard |
| 🔍 **Search & Filter** | Filter by URL, method, or status |
| 🎯 **JSON Viewer** | Syntax-highlighted, searchable JSON tree |
| 🔴 **Error Alerts** | Overlay button turns red on errors |
| 🖥️ **Console Logging** | Optional beautiful debug console output |
| 🌙 **Dark Mode** | Full dark/light theme support |

---

## 📸 Screenshots

<!-- Add your screenshots here -->
<!--
<p align="center">
  <img src="screenshots/list.png" width="200">
  <img src="screenshots/detail.png" width="200">
  <img src="screenshots/json.png" width="200">
</p>
-->

---

## 🚀 Quick Start

### 1. Add dependency

```yaml
dependencies:
  tapak: ^0.1.0
```

### 2. Add interceptor

**For Dio:**

```dart
import 'package:flutter/foundation.dart';
import 'package:tapak/tapak.dart';

final dio = Dio()
  ..interceptors.add(TapakInterceptor(
    enabled: kDebugMode,      // Show in UI inspector
    logToConsole: kDebugMode, // Print to debug console
  ));
```

**For http package:**

```dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tapak/tapak.dart';

final client = TapakHttpClient(
  http.Client(),
  enabled: kDebugMode,
  logToConsole: kDebugMode,
);

// Use like a regular http.Client
final response = await client.get(Uri.parse('https://api.example.com/posts'));
```

### 3. Add overlay button

Wrap inside `MaterialApp.builder`:

```dart
MaterialApp(
  builder: (context, child) => TapakOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
  home: const MyHomePage(),
)
```

**That's it!** A floating button appears showing live request count. Tap to open the inspector.

---

## 📖 Usage

### Overlay Button (Recommended)

The floating overlay button provides quick access to the inspector:

```dart
MaterialApp(
  builder: (context, child) => TapakOverlay(
    enabled: kDebugMode,  // Only show in debug mode
    child: child!,
  ),
  home: const MyHomePage(),
)
```

Features:
- Shows live request count
- Turns **red** when any request has errored
- Draggable to any position
- Tap to open full inspector

### Navigate Manually

Open the inspector screen from anywhere:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const TapakInspectorScreen()),
);
```

### View Transaction Details

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => TapakDetailScreen(transaction: transaction),
  ),
);
```

---

## ⚙️ Configuration

### Console Logging

Control what appears in the debug console:

```dart
TapakInterceptor(
  enabled: true,       // UI inspector
  logToConsole: true,  // Debug console output
)
```

Console output with beautiful formatting:

```
[Tapak] ┌──────────────────────────────────────────────────────────┐
        │ << RESPONSE  [200]  1.2s                                 │
        ├──────────────────────────────────────────────────────────┤
        │ GET  /posts/1                                            │
        ├──────────────────────────────────────────────────────────┤
        │ {                                                        │
        │   "userId": 1,                                           │
        │   "id": 1,                                               │
        │   "title": "sunt aut facere repellat..."                 │
        │ }                                                        │
        └──────────────────────────────────────────────────────────┘
```

### Console Options

```dart
// Set a custom title for logs
TapakPrinter.title = 'MyApp API';

// Show headers in console output
TapakPrinter.showHeaders = true;
```

Console output with title and client type:

```
[Tapak] ┌──────────────────────────────────────────────────────────┐
        │ [MyApp API]  >> REQUEST  (dio)                           │
        ├──────────────────────────────────────────────────────────┤
        │ GET  https://api.example.com/posts                       │
        └──────────────────────────────────────────────────────────┘

[Tapak] ┌──────────────────────────────────────────────────────────┐
        │ [MyApp API]  << RESPONSE  [200]  1.2s  (dio)             │
        ├──────────────────────────────────────────────────────────┤
        │ GET  /posts                                              │
        ├──────────────────────────────────────────────────────────┤
        │ {                                                        │
        │   "data": [...]                                          │
        │ }                                                        │
        └──────────────────────────────────────────────────────────┘
```

### Store Configuration

```dart
// Increase transaction limit (default: 200)
TapakStore.instance.maxTransactions = 500;

// Clear all logs
TapakStore.instance.clear();

// Listen to changes
TapakStore.instance.addListener(() {
  print('Transactions: ${TapakStore.instance.transactions.length}');
});
```

---

## 🔧 API Reference

### TapakInterceptor (Dio)

```dart
TapakInterceptor({
  TapakStore? store,        // Custom store instance
  bool enabled = true,      // Enable UI inspector
  bool logToConsole = false, // Enable console logging
})
```

### TapakHttpClient (http package)

```dart
TapakHttpClient(
  Client innerClient,
  {
    TapakStore? store,
    bool enabled = true,
    bool logToConsole = false,
  }
)
```

### TapakOverlay

```dart
TapakOverlay({
  required Widget child,
  bool enabled = true,       // Show/hide overlay
  Alignment alignment = Alignment.bottomRight, // Initial position
})
```

### TapakStore

```dart
// Singleton instance
TapakStore.instance

// Properties
List<HttpTransaction> transactions  // All recorded transactions
int maxTransactions                 // Max transactions to keep (default: 200)

// Methods
void add(HttpTransaction tx)        // Add transaction
void update(HttpTransaction tx)     // Notify listeners of update
void clear()                        // Clear all transactions
HttpTransaction? findById(String id) // Find by ID
```

### TapakPrinter

```dart
// Static configuration
TapakPrinter.title = 'MyApp';       // Custom title in logs (default: null)
TapakPrinter.showHeaders = false;   // Show headers in console (default: false)
```

---

## 📁 Project Structure

```
lib/
├── tapak.dart                           # Public API exports
└── src/
    ├── client/
    │   └── tapak_http_client.dart       # http package wrapper
    ├── interceptor/
    │   └── tapak_interceptor.dart       # Dio interceptor
    ├── logger/
    │   └── tapak_printer.dart           # Console formatter
    ├── model/
    │   └── http_transaction.dart        # Data model
    ├── store/
    │   └── tapak_store.dart             # State management
    └── ui/
        ├── tapak_inspector_screen.dart  # Transaction list
        ├── tapak_detail_screen.dart     # Detail tabs
        ├── tapak_overlay.dart           # Floating button
        └── widgets/
            ├── body_viewer.dart         # JSON viewer with search
            ├── method_badge.dart        # HTTP method badge
            └── status_badge.dart        # Status code badge
```

---

## 🆚 Comparison with Alice

| Feature | Tapak | Alice |
|---------|-------|-------|
| Dio support | ✅ | ✅ |
| http package | ✅ | ✅ |
| Overlay button | ✅ | ✅ |
| JSON viewer | ✅ | ✅ |
| Search in body | ✅ | ✅ |
| Console logging | ✅ | ❌ |
| Zero dependencies | ✅ | ❌ |
| HAR export | ❌ | ✅ |
| Request replay | ❌ | ✅ |
| Notifications | ❌ | ✅ |

**Tapak** is designed to be lightweight with zero external dependencies beyond Flutter.

---

## 📝 Example

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tapak/tapak.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapak Demo',
      builder: (context, child) => TapakOverlay(
        enabled: kDebugMode,
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dio = Dio()
    ..interceptors.add(TapakInterceptor(
      enabled: kDebugMode,
      logToConsole: kDebugMode,
    ));

  Future<void> _fetchPosts() async {
    await dio.get('https://jsonplaceholder.typicode.com/posts');
  }

  Future<void> _createPost() async {
    await dio.post(
      'https://jsonplaceholder.typicode.com/posts',
      data: {'title': 'Test', 'body': 'Hello Tapak', 'userId': 1},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tapak Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _fetchPosts,
              child: const Text('GET Posts'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _createPost,
              child: const Text('POST Create'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Alice](https://github.com/jhomlala/alice) - Inspiration for this project
- [Chucker](https://github.com/ChuckerTeam/chucker) - Android HTTP inspector
- [pretty_dio_logger](https://pub.dev/packages/pretty_dio_logger) - Console logging inspiration

---

<p align="center">
  Made with ❤️ for Flutter developers
</p>
