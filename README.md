# Tapak

<p align="center">
  <img src="tapak.jpeg" alt="Tapak logo" width="180">
</p>

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
| 📡 **HTTP Logging** | Automatically logs all Dio and `http` requests |
| 🎨 **Beautiful UI** | Color-coded method badges and status indicators |
| ⏱️ **Timing** | Request/response duration tracking |
| 📋 **Full Inspection** | Headers, body, query params with copy-to-clipboard |
| 🔍 **Search & Filter** | Filter by URL or method; search inside any body |
| 🎯 **JSON Viewer** | Regex-based syntax-highlighted viewer — no lag on large responses |
| 🔴 **Error Alerts** | Overlay button turns red on errors |
| 🖥️ **Console Logging** | Optional formatted debug console output (capped at 100 lines) |
| 🌙 **Dark Mode** | Full dark/light theme support |
| 🪄 **iOS-style Overlay** | Draggable frosted-glass button with idle fade and press animation |
| 🎨 **Custom Button Color** | Set any colour for the overlay button at runtime |
| 👁️ **Toggle Button** | Show or hide the overlay button without restarting |
| 📤 **HAR Export** | Export all recorded requests as HAR 1.2 (copied to clipboard) |
| 🔢 **Binary Body Decoding** | `List<int>` byte-array responses decoded to UTF-8 automatically |

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
    enabled: kDebugMode,      // show in UI inspector
    logToConsole: kDebugMode, // also print to debug console
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

final response = await client.get(Uri.parse('https://api.example.com/posts'));
```

### 3. Add overlay button

Wrap your home widget inside `MaterialApp.builder`:

```dart
MaterialApp(
  builder: (context, child) => TapakOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
  home: const MyHomePage(),
)
```

**That's it!** A draggable iOS-style button appears on the right side of the screen showing the live request count. Tap it to open the inspector.

---

## 📖 Usage

### Overlay Button

The floating button provides quick access to the inspector. It starts at the right-middle of the screen and can be dragged anywhere.

```dart
MaterialApp(
  builder: (context, child) => TapakOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
)
```

**Button behaviour:**
- Shows live request count
- Turns **red** when any request has errored
- Fades to 40% opacity after 4 s of inactivity (wakes on touch or new request)
- Scales down on press for tactile feedback
- Fully draggable — position persists across the session
- Default position: right edge, vertically centred

**Toggle visibility at runtime:**

```dart
TapakStore.instance.showButton = false; // hide
TapakStore.instance.showButton = true;  // show
```

**Set a custom colour:**

```dart
TapakStore.instance.buttonColor = Colors.teal;    // custom
TapakStore.instance.buttonColor = null;           // back to auto (grey → blue → red)
```

> The error state (red) always overrides a custom colour so the signal is never lost.

### Navigate Manually

Open the inspector from anywhere in your app:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const TapakInspectorScreen()),
);
```

### HAR Export

Tap the **download** icon in the inspector app bar to copy all recorded requests as a [HAR 1.2](https://w3c.github.io/web-performance/specs/HAR/Overview.html) JSON string to the clipboard. Paste it into [Chrome DevTools](https://developer.chrome.com/docs/devtools), [Charles](https://www.charlesproxy.com), or any HAR viewer.

You can also generate HAR programmatically:

```dart
import 'package:tapak/tapak.dart';

final har = HarExporter.toHarString(TapakStore.instance.transactions);
// or as a Map for custom serialisation:
final map = HarExporter.toHarMap(TapakStore.instance.transactions);
```

---

## ⚙️ Configuration

### Console Logging

```dart
TapakInterceptor(
  enabled: true,       // UI inspector
  logToConsole: true,  // debug console output
)
```

Console output (truncated at 100 lines for large responses):

```
[Tapak] ╔══════════════════════════════════════════════════════════════════════╗
        ║ << RESPONSE  [200]  1.2s                                             ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ GET  /posts/1                                                        ║
        ╠══════════════════════════════════════════════════════════════════════╣
        ║ {                                                                    ║
        ║   "userId": 1,                                                       ║
        ║   "id": 1,                                                           ║
        ║   "title": "sunt aut facere repellat..."                             ║
        ║ }                                                                    ║
        ╚══════════════════════════════════════════════════════════════════════╝
```

### Console Options

```dart
TapakPrinter.title = 'MyApp API';  // custom prefix in every log line
TapakPrinter.showHeaders = true;   // include headers in output
```

### Store Configuration

```dart
// Increase transaction cap (default: 200)
TapakStore.instance.maxTransactions = 500;

// Clear all logs
TapakStore.instance.clear();

// Show / hide the overlay button
TapakStore.instance.showButton = false;

// Set a custom button colour
TapakStore.instance.buttonColor = Colors.deepPurple;

// Listen to changes
TapakStore.instance.addListener(() {
  final count = TapakStore.instance.transactions.length;
  debugPrint('Tapak: $count requests recorded');
});
```

---

## 🔧 API Reference

### TapakInterceptor (Dio)

```dart
TapakInterceptor({
  TapakStore? store,         // custom store instance (default: TapakStore.instance)
  bool enabled = true,       // enable UI inspector
  bool logToConsole = false, // enable console logging
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
  bool enabled = true,  // set to kDebugMode to hide in release builds
})
```

### TapakStore

```dart
// Singleton
TapakStore.instance

// Properties
List<HttpTransaction> transactions   // newest-first, read-only
int maxTransactions                  // cap (default: 200)
bool showButton                      // show/hide the overlay FAB
Color? buttonColor                   // null = auto colour scheme

// Methods
void add(HttpTransaction tx)
void update(HttpTransaction tx)
void clear()
HttpTransaction? findById(String id)
```

### HarExporter

```dart
// Pretty-printed HAR 1.2 JSON string
HarExporter.toHarString(List<HttpTransaction> transactions)

// Raw Map for custom serialisation
HarExporter.toHarMap(List<HttpTransaction> transactions)
```

### TapakPrinter

```dart
TapakPrinter.title = 'MyApp';      // custom title prefix (default: null)
TapakPrinter.showHeaders = false;  // include headers in output (default: false)
```

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
  final _dio = Dio()
    ..interceptors.add(TapakInterceptor(
      enabled: kDebugMode,
      logToConsole: kDebugMode,
    ));

  Future<void> _fetchPosts() async {
    await _dio.get('https://jsonplaceholder.typicode.com/posts');
  }

  Future<void> _createPost() async {
    await _dio.post(
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
            ElevatedButton(onPressed: _fetchPosts, child: const Text('GET Posts')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _createPost, child: const Text('POST Create')),
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

MIT — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Alice](https://github.com/jhomlala/alice) — inspiration for this project
- [Chucker](https://github.com/ChuckerTeam/chucker) — Android HTTP inspector
- [pretty_dio_logger](https://pub.dev/packages/pretty_dio_logger) — console logging inspiration

---

<p align="center">
  Made with ❤️ for Flutter developers
</p>
