# HTTP service: zap -> Baz migration

## Status

Done: the service runs on [Baz](https://github.com/technologylab-ai/baz)
(pinned `8c8a3ed`, `build.zig.zon`). Baz and its `bounded_http` engine panic
unless the compiler is exactly **Zig 0.17.0** (`.zig-version`), so the whole
repo, library included, is built with 0.17.0 now. The 0.17.1 release is rejected
by Baz's `build.zig`; `-Dservice=false` builds only the library (that works on
newer Zig; not re-checked on 0.17.1 after Baz was added).

Verified with `zig build run` and curl: `/api/hello`, `/api/version`,
`POST /api/features/common`, `POST /api/rules/apply` (valid rule, invalid rule
-> 400, bad JSON -> 400, invalid UTF-8 -> 400), `OPTIONS` (204 + `Allow`), 404,
405, CORS headers on success and error responses.

## What changed

- `src/main.zig`: `AppWithLocals(Shared, Locals)`, bind `0.0.0.0:3003`, global
  CORS middleware, `on_error` hook.
- `src/routes/routes.zig`: `app.route` registrations and the `on_error` mapping
  (`router-errors.zig` -> HTTP status). `regez`, `matcher.zig` and the hand-made
  dispatcher/`Access` table were removed; Baz does static-over-capture ranking,
  404/405, `OPTIONS` and `HEAD`.
- `src/routes/params.zig`: `paramAs(T, ctx, name)` for typed path captures
  (ints, bool, enums, strings; bad input -> `error.BadRequest` -> 400).
  Unused until a route has `:params`. Tests run with `zig build test-service`.
- `src/middle/`: `context.zig` (`Shared`, `Locals`), `header.zig` (CORS +
  `Expires`; also called from `on_error`, because Baz drops draft headers when a
  handler errors).
- `src/services/*.zig`: handlers take `*Context`, return errors, respond with
  `ctx.response.jsonValue` / `.text`.
- `build.zig`: facil.io and regez wiring removed. The backend still links libc,
  because `libph_lib.so` needs the dynamic loader's TLS (Baz alone does not).
  `-Dservice` defaults to true.

## Limits to know

- Baz bounds memory up front: `connections`, `output_bytes` and
  `response.body_bytes` in `main.zig` are sized for the 512 MiB budget. A
  response over `body_bytes` (32 KiB) fails; request bodies are copied into
  fixed 4 KiB (features) / 16 KiB (rules) stack buffers.
- Handlers run inline on the event loop (Baz default). Rule application is short;
  switch `.execution` to workers if heavy calls are added.

## Deploy

Now uses the standard owl deploy (`deploy/deploy.sh` + `deploy/deploy.conf`,
rules in the infra repo's `DEPLOY-RULES.md`). The service reads `PORT` from the
environment and listens on 127.0.0.1 only (Caddy is the public side). Builds use
`ReleaseSafe` because Baz rejects ReleaseFast/ReleaseSmall. The old `run.sh`,
`ecosystem.config.cjs`, `update-demo.sh`, `Dockerfile` and `c-src/` were removed.
The first `./deploy/deploy.sh init` / deploy has not been run yet.
