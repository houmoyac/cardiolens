/// Local dev backend, reachable when the phone is on the same WiFi as the
/// Mac running `uv run uvicorn cardiolens.api:app --host 0.0.0.0 --port 8000`.
/// No deployed backend exists yet — see ARCHITECTURE.md. Update the IP if
/// your Mac's local address changes (check with `ipconfig getifaddr en0`).
const String apiBaseUrl = 'http://192.168.1.3:8000';
