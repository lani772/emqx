# LUMA Device Platform — Phase 2: Device Registry

Phase 2 introduces a persistent-architecture boundary for registered LUMA devices.

## Device identity

A registered device has:

- device_id
- permanent_uid
- tenant_id
- owner_id
- device_type
- name
- model
- firmware_version
- capabilities
- status
- registered_at
- last_seen_at

## API

POST /api/v1/devices/register
GET  /api/v1/devices
GET  /api/v1/devices/{device_id}

Registration rejects duplicate device IDs with CONFLICT and validates the required identity fields.

## Current implementation note

The Phase 2 registry uses an ETS-backed registry to establish the service/data-ownership boundary and API behavior without introducing an external database dependency yet. ETS is not the final production persistence layer. A later persistence phase will replace or back this registry with durable storage.

## Next

Phase 3 will add device authentication/credentials and MQTT ACL isolation so each ESP32 can access only its own LUMA topics.
