# LUMA ESP32 Broker Upgrade Roadmap

## Phase 1 — MQTT control bridge
- [x] Native EMQX management API module.
- [x] List connected ESP32 clients.
- [x] Inspect a connected ESP32 client.
- [x] Publish JSON commands over MQTT.
- [x] Generate command IDs and response topics.
- [x] Document the MQTT and HTTP contract.

## Phase 2 — Device registry
Add a persistent registry separate from EMQX's transient connection/client state.

Device record:
- device_id
- permanent_uid
- tenant_id
- owner_id
- name
- model
- firmware_version
- status
- registered_at
- last_seen_at
- capabilities
- metadata
- credential status

Registration flow:
1. ESP32 connects with temporary credentials.
2. Broker verifies the temporary identity.
3. API creates a permanent device identity.
4. Device receives permanent credentials.
5. Device reconnects using the permanent identity.
6. Registry keeps the device even when offline.

## Phase 3 — Telemetry
ESP32 publishes:
- `luma/devices/{id}/telemetry`
- `luma/devices/{id}/state`
- `luma/devices/{id}/availability`

Add normalized telemetry ingestion, validation and persistence.

## Phase 4 — Reliable commands
Add:
- command timeout
- acknowledgement
- retry policy
- idempotency key
- command history
- response correlation
- explicit offline errors

## Phase 5 — Security and tenancy
Add:
- tenant isolation
- device ownership
- scoped API keys
- per-device MQTT ACLs
- TLS
- credential rotation
- audit logs

## Phase 6 — LUMA integration
Expose a stable external API for the LUMA backend:
- device CRUD
- registration
- online status
- telemetry
- commands
- command history
- schedules
- scenes
- firmware/OTA
- WebSocket device events

Important design rule: EMQX remains the MQTT transport and broker. Persistent LUMA business data should have explicit ownership and storage rather than being forced into EMQX's internal connection tables.
