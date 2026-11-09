// Native platforms use the OS-backed secure credential store.
// Web builds (dart2js and dart2wasm) use an in-memory preview session.
// Never write refresh tokens to insecure browser storage on HTTP LAN origins.
export 'session_storage_native.dart'
    if (dart.library.html) 'session_storage_web.dart'
    if (dart.library.js_interop) 'session_storage_web.dart';