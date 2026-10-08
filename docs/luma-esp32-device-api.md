# LUMA ESP32 Device API

This document defines the first device-control layer added to the EMQX fork.

## MQTT contract

ESP32 devices connect to the broker as normal MQTT clients. A device command is published to:

`luma/devices/{device_id}/command`

Command payload:

```json
{
  "command_id": "unique-id",
  "device_id": "esp32-001",
  "command": "set_power",
  "params": {
    "state": true
  },
  "response_topic": "luma/devices/esp32-001/command/unique-id/response",
  "timestamp": 0
}
```

The ESP32 may publish the result to the supplied response topic.

## HTTP API

The first endpoints are:

- `GET /api/v5/devices`
- `GET /api/v5/devices/{deviceid}`
- `POST /api/v5/devices/{deviceid}/command`

Example command:

```json
{
  "command": "set_power",
  "params": {
    "state": true
  },
  "qos": 1
}
```

## Device identification

The first implementation discovers connected devices through EMQX's existing client management API and defaults to client IDs beginning with `esp32-`.

This is intentionally an initial compatibility layer. Persistent registration, ownership, credentials, telemetry history, command acknowledgement, OTA, and device groups should be added as separate capabilities rather than mixing persistent business data into the broker's client registry.
