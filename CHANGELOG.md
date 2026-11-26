## 0.1.0

Initial release.

**HTTP Inspector**
- `TapakInterceptor` — Dio interceptor that records every request/response
- `TapakHttpClient` — `http` package client wrapper with the same recording behaviour
- `TapakInspectorScreen` — searchable transaction list with live request count
- `TapakDetailScreen` — Overview / Request / Response / Error tabs
- Syntax-highlighted JSON body viewer (regex tokenizer, no lag on large responses)
- `List<int>` byte-array response bodies decoded automatically as UTF-8
- Status badge shows a loading spinner while request is in-flight

**Overlay Button**
- `TapakOverlay` — iOS AssistiveTouch-style draggable floating button
- Idle fade, spring press animation, and coloured glow shadow
- Default position: right edge, vertically centred
- `TapakStore.instance.showButton` — show/hide at runtime
- `TapakStore.instance.buttonColor` — custom colour at runtime

**HAR Export**
- `HarExporter.toHarString` / `toHarMap` — HAR 1.2 format
- Export all requests from the inspector, or a single request from the detail screen
- Copies to clipboard

**Request Replay**
- `TapakReplayer.replay()` — re-sends any recorded request via the `http` package
- Replayed transactions flagged with a `↺ replay` badge in the list and detail screen
- Long-press a transaction card to replay via a bottom sheet

**Custom Logger**
- `TapakLog.debug` / `.info` / `.success` / `.warning` / `.danger`
- Entries stored in `TapakStore` and viewable in `TapakLogsScreen`
- Level filter, clear, and dark/light/system theme toggle in the inspector menu
- Console output: double-line box format emitted as a single call to prevent
  interleaving with other log sources

**Inspector UI**
- Search bar toggled via icon (hidden by default)
- `⋮` more menu: theme toggle, View logs, Export HAR, Clear logs
- Dark / Light / System theme toggle that applies to the entire inspector
- Detail screen `⋮` menu: Replay request, Export as HAR

**Performance**
- `formattedRequestBody` / `formattedResponseBody` cached after first access
- Transaction and log lists cached and invalidated only on mutation
- `add()` / `update()` / `addLog()` notifications batched via `Future.microtask`
- Body viewer renders large JSON responses as a single `RichText` widget

**Console Logging**
- `TapakPrinter` formats HTTP requests and responses in a double-line box
- `TapakLog` uses the same box format for visual consistency
- Output capped at 100 lines per body to avoid blocking the isolate
- ANSI colours applied when stdout is a real terminal; plain box in IDE consoles

**Stability**
- All `TapakLog` entry points wrapped in `try/catch` — never crashes the host app
- `TapakInterceptor` guards tapak code; `handler.next()` is always called
- `TapakHttpClient` guards bookkeeping; real network errors still propagate
