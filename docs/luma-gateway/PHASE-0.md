# LUMA Gateway — Phase 0 Baseline

**Status:** repository branch created; discovery started; build/test validation not yet run.

## Scope and safety boundary

- Working repository: `lani772/emqx` (the user's repository).
- Working branch: `feature/luma-gateway-phase0`, created from `master`.
- Do not write to, push to, or open a pull request against `emqx/emqx`.
- Keep the public LUMA API in a separate service. EMQX remains the MQTT broker and enforces device authentication/topic authorization.
- Expected initial scale: 1,000–10,000 connected devices.
- Device authentication direction: short-lived JWTs or signed tokens validated by EMQX; do not put long-lived shared secrets in firmware or source control.

## Version decision

Use a GA/stable EMQX release line rather than an alpha release. The upstream release page lists **6.1.5** as a GA release (released 29 September 2026 at the time this plan was written). Before implementing broker-specific extensions, verify the exact source ancestry and build profile in this repository and pin a compatible stable tag/commit. Do not silently rebase this working branch to upstream.

Reference: https://github.com/emqx/emqx/releases

## Findings so far

- The default branch is `master`.
- The repository has an EMQX umbrella `mix.exs`; its header documents that a release build is expected rather than simply starting with `iex -S mix`.
- A `docker-compose.yml` file was not found at the repository root.
- Existing related branches include `feature/esp32-device-api`, `feature/luma-device-platform-phase1`, and `feature/luma-device-platform-phase2`. This Phase 0 work is isolated on a new branch.
- The plugin extension points and the actual compile/test workflow have not yet been validated.
- No build or test has been run by this Phase 0 setup step. Do not treat branch creation or source inspection as a passing build.

## Initial architecture

1. **EMQX broker plane:** MQTT/TLS listeners, JWT authentication, per-device topic ACLs, rate limits, and broker-native routing/rules where supported by the chosen stable version.
2. **Separate LUMA API/control plane:** device registration, tenant/user ownership, scoped external API keys, command lifecycle, audit events, and OpenAPI.
3. **PostgreSQL:** device registry, command state, API clients, audit log, and (after throughput testing) telemetry. Consider TimescaleDB only if time-series volume and retention needs justify it.
4. **Web clients:** MQTT over WebSocket through EMQX where appropriate, with the same identity and topic ACL model. A plain-JSON WebSocket fan-out API is a later option, not a Phase 0 dependency.

## Draft database schema (logical, not migrated)

- `devices(id, tenant_id, external_id, name, status, created_at, updated_at)`
  - Unique constraint on `(tenant_id, external_id)`.
- `device_credentials(id, device_id, credential_type, token_subject, public_key_or_hash, expires_at, revoked_at, created_at)`
  - Never store plaintext passwords or signing secrets. If JWT is used, store only identifiers/claims needed for revocation and audit; signing keys belong in a secret manager.
- `api_clients(id, tenant_id, name, key_hash, scopes, rate_limit, expires_at, revoked_at, created_at)`
  - Show an API key only once at creation; persist only a secure hash.
- `device_commands(id, tenant_id, device_id, idempotency_key, payload, status, created_at, sent_at, acked_at, expires_at, error_code)`
  - Unique constraint on `(tenant_id, idempotency_key)`; status transitions: `pending -> sent -> acked`, or terminal `failed/timeout/expired`.
- `device_telemetry(id, tenant_id, device_id, observed_at, received_at, schema_version, payload)`
  - Partition/hypertable decision deferred until load tests establish message rate, retention, and query patterns.
- `audit_events(id, tenant_id, actor_type, actor_id, action, resource_type, resource_id, request_id, occurred_at, metadata)`

Use migrations and foreign keys in the implementation. Validate payload shape and enforce tenant ownership in the API; never trust a device-supplied tenant ID.

## Draft topic and ACL contract

For device ID `{deviceId}`:

- Device may publish: `devices/{deviceId}/telemetry`, `devices/{deviceId}/status`, `devices/{deviceId}/heartbeat`, `devices/{deviceId}/responses/+`.
- Device may subscribe: `devices/{deviceId}/commands`, `devices/{deviceId}/config`, `devices/{deviceId}/firmware`.
- Device must not publish to command/config/firmware topics or access another device's topic.
- A user or service may access only topics for devices authorized by the LUMA API's ownership/tenant policy.
- Treat these as logical topic names; final prefixes and ACL expression syntax must be tested against the selected EMQX stable version.

## Phase 0 checklist

- [x] Create an isolated working branch in `lani772/emqx`.
- [x] Record the intended stable-release policy and initial architecture.
- [x] Draft database entities and device topic permissions.
- [ ] Confirm exact upstream/base commit and repository source ancestry.
- [ ] Read `plugins/emqx_offline_messages`, `plugins/emqx_username_quota`, `plugins/emqx_sync_request`, `PLUGIN.md`, and the rule-engine documentation in the actual checked-out source.
- [ ] Identify the repository's supported build container/CI workflow and pin Erlang/OTP, Elixir, and other required tool versions.
- [ ] Run the supported build and relevant tests; record commands, exit codes, and CI links.
- [ ] Confirm a compatible GA tag/commit before adding broker-specific implementation code.

## Validation report

**Build:** NOT RUN. The connected GitHub interface used for this step can inspect and edit repository files but does not provide a local shell to compile the Erlang/Mix project.

**Tests:** NOT RUN. No tests are claimed as passing.

**Next action:** complete source/version and CI discovery, then run the supported build in GitHub Actions or a local/container environment before implementing the gateway plugin.


## Follow-up source inspection (read-only)

- `PLUGIN.md` confirms in-monorepo plugins belong under `plugins/`; plugin apps require their own `mix.exs` and `VERSION`. The repository uses Mix for compile/test/package workflows.
- `plugins/emqx_offline_messages/README.md` documents persistence of selected QoS 1/2 messages when no matching subscriber is online, with Redis and MySQL backends. Its documented commands are `make` and `make plugins/emqx_offline_messages-ct`. This is not yet a recommendation to enable it; delivery semantics and duplicate handling must be tested before choosing it over a separate queue.
- `plugins/emqx_username_quota/README.md` documents per-username session quotas and notes that namespace-based limits may be possible with `client_attrs.tns`; evaluate built-in namespace/client attributes before adopting the plugin.
- `plugins/emqx_sync_request/README.md` documents a REST-to-MQTT request helper for exactly one online, non-shared subscriber. Requests are node-local, bypass the normal publish pipeline, and do not persist inflight state. Do not make this the durable command/ack subsystem without addressing those limitations.
- `.github/workflows/_push-entrypoint.yaml` runs on pushes to selected branches (including `master`, release branches, and `ci/**`) and supports manual dispatch. The new `feature/luma-gateway-phase0` branch is not covered by its listed push branch patterns, and no workflow-dispatch action is available through the current connected GitHub interface.
- Root `docker-compose.yml`, root `VERSION`, root `rebar.config`, and the guessed `apps/emqx/src/emqx.app.src` path were not found. The exact release version therefore remains unverified from these inspected paths; do not treat upstream 6.1.5 as confirmed to match this repository's current source.

## Updated Phase 0 status

- [x] Read the plugin development guide.
- [x] Inspect README-level semantics for offline messages, username quota, and sync request.
- [x] Inspect the repository's push workflow triggers.
- [ ] Identify the exact version from the repository's actual version source and compare it with a stable GA tag.
- [ ] Run the supported compile and test commands in an environment that has the required Erlang/OTP and Elixir toolchain.
