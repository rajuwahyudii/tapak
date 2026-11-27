# Tapak — Agent Guide

This project uses **Tapak** (`package:tapak/tapak.dart`) as its in-app HTTP inspector and debug logger.
When working in this codebase, follow the rules below so every HTTP call, log event, and QA scenario goes through Tapak correctly.

---

## Setup (required once per project)

Every Flutter project using Tapak needs two things wired up. Check if they already exist before adding them.

### 1. Interceptor on every HTTP client

**Dio:**
```dart
import 'package:flutter/foundation.dart';
import 'package:tapak/tapak.dart';

final dio = Dio()
  ..interceptors.add(TapakInterceptor(
    enabled: kDebugMode,
    logToConsole: kDebugMode,
  ));
```

**http package:**
```dart
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tapak/tapak.dart';

final client = TapakHttpClient(
  http.Client(),
  enabled: kDebugMode,
  logToConsole: kDebugMode,
);
```

> Never create a raw `Dio()` or `http.Client()` without wrapping it. Always use `TapakInterceptor` or `TapakHttpClient`.

### 2. Overlay in MaterialApp

```dart
MaterialApp(
  navigatorKey: TapakStore.instance.navigatorKey, // optional but recommended
  builder: (context, child) => TapakOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
)
```

---

## HTTP Logging

Tapak records every request and response automatically once the interceptor is wired up. You do not need to add any extra code around API calls.

What gets captured per request:
- Method, URL, query params
- Request headers and body
- Response status code, headers, and body
- Duration (ms or s)
- Error message on failure

**Reading captured data in code:**
```dart
// All transactions, newest first
final transactions = TapakStore.instance.transactions;

// Find a specific one
final tx = TapakStore.instance.findById(someId);

// Access response body
final body = tx?.responseBody;         // raw (Map, List, or String)
final pretty = tx?.formattedResponseBody; // pretty-printed JSON string

// Access request body
final reqBody = tx?.formattedRequestBody;

// Check status
if (tx?.status == TransactionStatus.success) { ... }
if (tx?.status == TransactionStatus.error) { ... }

// Duration
print(tx?.durationText); // e.g. "240ms" or "1.2s"
```

---

## Custom Logger

Use `TapakLog` instead of `print`, `debugPrint`, or `logger` packages. Entries appear in the Tapak Logs screen (menu → View logs) and in the debug console.

```dart
import 'package:tapak/tapak.dart';

TapakLog.debug('auth',          'checking token expiry');
TapakLog.info('remote_config',  'flags loaded: ${flags.length}');
TapakLog.success('payment',     'charge confirmed: $orderId');
TapakLog.warning('cache',       'stale data, reloading');
TapakLog.danger('sync',         'push failed: $error');
```

**Rules for the title argument:**
- Use a short snake_case tag that identifies the module or feature, e.g. `auth`, `cart`, `location`, `remote_config`.
- Keep messages factual: include variable values where useful.

**When to log:**
| Situation | Level |
|-----------|-------|
| Start of a process, entering a state | `debug` |
| Informational milestone | `info` |
| Operation completed successfully | `success` |
| Non-fatal issue, degraded state | `warning` |
| Unrecoverable error, data loss risk | `danger` |

---

## QA: Simulate Date

Use this when testing date-sensitive backend logic (expiry, scheduling, promotions, etc.) without changing the device clock.

**The device clock stays at real `DateTime.now()`. Only the outgoing HTTP request receives the simulated date.**

### Turn simulation on
```dart
// Simulate "today is 1 Jan 2026 at midnight"
TapakStore.instance.simulatedDate = DateTime(2026, 1, 1);
```

### Turn simulation off
```dart
TapakStore.instance.simulatedDate = null;
```

### Where the date is sent

By default it is injected as the `X-Simulated-Date` HTTP header on every request:
```
X-Simulated-Date: 2026-01-01T00:00:00.000Z
```

The server must read this header and use it as the current date for the request.

### Customise injection

```dart
// Use a different header name
TapakStore.instance.simulatedDateConfig = const TapakSimulatedDateConfig(
  headerName: 'X-Current-Date',
);

// Use a query param instead (Dio / TapakInterceptor only)
TapakStore.instance.simulatedDateConfig = const TapakSimulatedDateConfig(
  headerName: null,
  queryParamName: 'currentDate',
);

// Both header and query param at once
TapakStore.instance.simulatedDateConfig = const TapakSimulatedDateConfig(
  headerName: 'X-Simulated-Date',
  queryParamName: 'simulatedDate',
);

// Custom format (default is ISO 8601 UTC)
TapakStore.instance.simulatedDateConfig = TapakSimulatedDateConfig(
  format: (d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}',
);
```

> `TapakHttpClient` only supports header injection. Query param injection requires Dio's `TapakInterceptor`.

### In-app UI

Open the inspector → tap ⋮ menu → **QA Tools**. A date/time picker lets you set or clear the simulated date. An amber banner appears at the top of the inspector list whenever simulation is active.

---

## Request Replay

Replay any completed request from the inspector (long-press a row → Replay request).  
You can also trigger replay in code:

```dart
import 'package:tapak/tapak.dart';

// Get a transaction you want to replay
final tx = TapakStore.instance.transactions.first;

// Replay it — recorded as a new transaction with isReplayed = true
final newTx = await TapakReplayer.replay(tx);

print(newTx.statusCode);       // response status
print(newTx.formattedResponseBody); // response body
```

Replayed transactions are marked with an orange `replay` badge in the list. They are independent entries — the original is preserved.

---

## HAR Export

Useful for sharing a full session with backend engineers or pasting into Chrome DevTools / Charles.

**From the UI:** inspector → ⋮ menu → **Export as HAR** — copies to clipboard.

**In code:**
```dart
// Pretty-printed HAR 1.2 JSON string — ready to save as .har file
final har = HarExporter.toHarString(TapakStore.instance.transactions);

// Raw Map — use this if you need to serialise differently
final map = HarExporter.toHarMap(TapakStore.instance.transactions);
```

---

## Console Logging

Enable `logToConsole: true` on the interceptor or client to get a formatted box log in the debug console for every request and response. Keep it tied to `kDebugMode`.

Customise the prefix and header visibility:
```dart
TapakPrinter.title = 'MyApp';     // appears in every log line, default null
TapakPrinter.showHeaders = true;  // include request/response headers, default false
```

---

## Runtime Controls

```dart
// Hide the overlay button (e.g. during onboarding)
TapakStore.instance.showButton = false;

// Set a custom overlay button colour
TapakStore.instance.buttonColor = Colors.teal;
TapakStore.instance.buttonColor = null; // back to auto (grey → blue → red on error)

// Change inspector theme
TapakStore.instance.inspectorThemeMode = TapakThemeMode.dark;
TapakStore.instance.inspectorThemeMode = TapakThemeMode.light;
TapakStore.instance.inspectorThemeMode = TapakThemeMode.system; // default

// Raise or lower transaction memory cap (default 200)
TapakStore.instance.maxTransactions = 500;

// Clear everything
TapakStore.instance.clear();      // HTTP transactions
TapakStore.instance.clearLogs();  // custom log entries

// Navigate to inspector from code
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const TapakInspectorScreen()),
);
```

---

## Quick Reference

| Task | API |
|------|-----|
| Log debug | `TapakLog.debug('tag', 'message')` |
| Log info | `TapakLog.info('tag', 'message')` |
| Log success | `TapakLog.success('tag', 'message')` |
| Log warning | `TapakLog.warning('tag', 'message')` |
| Log danger | `TapakLog.danger('tag', 'message')` |
| Simulate date | `TapakStore.instance.simulatedDate = DateTime(2026, 1, 1)` |
| Clear simulation | `TapakStore.instance.simulatedDate = null` |
| Change injection header | `TapakStore.instance.simulatedDateConfig = TapakSimulatedDateConfig(headerName: 'X-Date')` |
| Replay a request | `await TapakReplayer.replay(tx)` |
| Get all transactions | `TapakStore.instance.transactions` |
| Get response body | `tx.formattedResponseBody` |
| Export HAR | `HarExporter.toHarString(TapakStore.instance.transactions)` |
| Hide overlay button | `TapakStore.instance.showButton = false` |
| Clear logs | `TapakStore.instance.clear()` |
