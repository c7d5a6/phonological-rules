# TODO: migrate the HTTP service from zap to Baz

## Status

The library (`ph_lib`, its tests, `ph_profile`) builds on Zig 0.17.0. The HTTP
service (`phonological-rules-backend`) does not.

- [zap](https://github.com/zigzap/zap) was archived on 2026-09-06 and has no Zig
  0.17 support. Its successor is
  [Baz](https://github.com/technologylab-ai/baz) (Bounded Async Zap), which
  requires Zig 0.17.0 (`minimum_zig_version = "0.17.0"`, port merged 2026-10-04,
  commit `8c8a3ed`).
- zap was removed from `build.zig.zon`. Zig 0.17 compiles the `build.zig` of
  every available dependency, even an unused lazy one, and zap's no longer
  compiles. Keeping it declared breaks the library build too.
- The service build is behind `-Dservice` (default `false`), in
  `buildService` in `build.zig`. `zig build -Dservice` currently stops with
  `no dependency named zap`.
- `deploy/deploy.sh` builds the backend, so deploys are blocked until this is
  done.

## zap usage to replace

| File | zap API used |
| --- | --- |
| `src/main.zig` | `zap.Middleware.Listener(Context)` (`port`, `max_clients`, `log`), `listener.listen()`, `zap.start(.{ .threads, .workers })`, `.zap` log scope in `std_options` |
| `src/middle/header.zig` | `zap.Middleware.Handler(Context)`; CORS / `Expires` headers via `r.setHeader`; short-circuits `OPTIONS` with `r.sendBody("")` |
| `src/middle/controller.zig` | `zap.Middleware.Handler(Context)`; per-request arena, calls `routes.dispatch_routes` |
| `src/middle/context.zig` | Per-request `Context` (all fields defaulted), `SharedAllocator` global for the listener |
| `src/routes/routes.zig` | `zap.Request`, `zap.http.Method`, `r.methodAsEnum()`, `r.path`, `r.sendError(err, null, status)`, `r.sendBody`; own regex router (`regez` C lib) with `{name}` captures |
| `src/services/common.zig` | `r.setContentType(.JSON)`, `r.sendJson` |
| `src/services/features.zig` | `r.parseBody()`, `r.body`, `r.sendError`, `r.setContentType(.JSON)`, `r.sendJson` |
| `src/services/rules.zig` | `r.parseBody()`, `r.body`, `r.sendError`, `r.setContentType(.TEXT)`, `r.sendBody` |

## zap → Baz mapping

From Baz's `README.md`, `docs/APP-API.md`, `docs/MIDDLEWARE.md`,
`src/response.zig`. Check the current API reference
(<https://technologylab-ai.github.io/baz/api/>) before porting; Baz is
experimental.

| zap | Baz |
| --- | --- |
| `zap.Middleware.Listener(Context).init(.{ .port, … }, handler, getAllocator)` + `listen()` | `web.AppWithLocals(Shared, Locals).init(.{ .allocator = init.gpa, .io = init.io, .shared = &shared, .server = …, .response = … })`, then `start()` → `run()` → `deinit()` |
| `zap.start(.{ .threads, .workers })` | Server / worker limits in the App `.server` options (see Baz `docs/LIMITS.md`) |
| `Context` (per-request struct with defaults) | `Locals` type of `AppWithLocals`, available as `ctx.locals` |
| `SharedAllocator` global | `Shared` struct passed as `.shared`, available as `ctx.shared`; allocator comes from `init.gpa` |
| Middleware chain (`Handler.init(onRequest, other)`, `handleOther`) | Global hooks in `Options.middleware` (`.before` returns `.continue_request` or `.respond`); per-route hooks via `routeWith(…, .{ .middleware = … })` |
| Own regex router + `getRouteParams` (`{id}`) | `app.route("POST", "/api/rules/apply", handler)` or `app.endpoint(path, &obj)`; captures `/users/:id` read with `ctx.param("id")` (raw text, parse ints yourself) |
| `r.methodAsEnum()`, `r.path` | `ctx.request.method()`, `ctx.request.target()`; usually not needed once Baz routes |
| `OPTIONS` short-circuit in header middleware | Baz answers `OPTIONS` itself (with `Allow`); add CORS headers in a global before hook |
| `r.setHeader(name, value)` | `ctx.response.header(name, value)` |
| `r.parseBody()` + `r.body` | `ctx.request.body().contiguous()` (or `copyTo(buf)` when not contiguous) |
| `r.setContentType(.JSON)` + `r.sendJson(json)` | `ctx.response.jsonBytes(200, json)` or `ctx.response.jsonValue(200, value)` |
| `r.setContentType(.TEXT)` + `r.sendBody(s)` | `ctx.response.text(200, s)` |
| `r.sendError(err, null, status)` | `ctx.response.errorResponse(status)`, or return an error and use the App `on_error` hook with `web.defaultErrorStatus(err)` |
| 404 fallback in `dispatch_routes` | Built in (404 unknown path, 405 wrong method); custom `not_found` handler optional |

Notes:

- Baz is pure Zig (no facil.io). On Linux it uses io_uring and needs no libc.
  This service still links libc for `regez`, but the router may make `regez`
  unnecessary.
- Request data is borrowed: do not keep slices from `ctx.request` after the
  handler returns. Copy into the per-request arena if a service needs them.
- Baz binds IPv4 loopback by default; set an explicit address for the deployed
  server.

## Checklist

1. Add Baz to `build.zig.zon`:
   `zig fetch --save git+https://github.com/technologylab-ai/baz#<commit>`.
2. In `buildService` (`build.zig`): import `baz` instead of `zap`; drop the
   `facil.io` artifact, its install, and the `$ORIGIN/../lib` /
   `$ORIGIN/libs` rpaths it needed (keep them if `ph_lib` stays a shared lib).
3. Rewrite `src/main.zig` around `AppWithLocals(Shared, Locals)`; remove the
   `.zap` log scope; change `builtin.mode == .Debug` to `.debug` (3 places,
   Zig 0.17 lowercased `std.lang.Optimize`).
4. Replace `src/middle/header.zig` with a global before hook that sets the CORS
   and `Expires` headers. Replace `src/middle/controller.zig` and
   `dispatch_routes` with Baz route registration.
5. Port `src/services/*.zig` and `src/routes/routes.zig` to
   `*Application.Context` using the mapping above. Decide whether the
   `regez`-based matcher (`src/routes/matcher.zig`, `c-src/`) is still needed.
6. Make `-Dservice` default to `true` (or remove the option).
7. Update `deploy/deploy.sh` / `deploy/run.sh` (no `libfacil.io.so` to ship),
   and bump `ZIG_VERSION` in `Dockerfile` (currently `0.15.2`) to `0.17.0`.
8. Verify: `zig build -Dservice`, `zig build run`, then curl
   `/api/hello`, `/api/version`, `POST /api/features/common`,
   `POST /api/rules/apply`, and an `OPTIONS` preflight.

## Fallback: keep zap on Zig 0.17

If Baz has to wait, zap 0.10.6 (commit `f6099ec`) builds on Zig 0.17 with three
one-line patches. You would need to vendor it (for example `deps/zap/` with
`.path = "deps/zap"` in `build.zig.zon`) or fork it, because the fetched
package in `zig-pkg/` is not tracked:

- `facil.io/build.zig`: `optimize != .Debug` → `optimize != .debug`
- `build.zig` (`TestSystem.addTest`): `self.b.addModule(test_name, .{` →
  `self.b.createModule(.{`
- `src/zap.zig`: `std.fmt.bufPrintZ(&portbuf, "{d}", .{…})` →
  `std.fmt.bufPrintSentinel(&portbuf, "{d}", .{…}, 0)`

Plus the service's own `.Debug` → `.debug` fix in `src/main.zig`. With these,
the backend built and served on port 3003 in a scratch copy.
