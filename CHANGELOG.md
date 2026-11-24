## 0.1.0

- Initial release.
- `TapakInterceptor` — Dio interceptor that records requests/responses into `TapakStore`.
- `TapakHttpClient` — `http` package `Client` wrapper with the same recording behaviour.
- `TapakStore` — ChangeNotifier singleton with configurable transaction cap.
- `TapakInspectorScreen` — list screen with live search/filter.
- `TapakDetailScreen` — Overview / Request / Response tabs with body viewer and copy support.
- `TapakOverlay` — floating button overlay that shows live request count and error state.
