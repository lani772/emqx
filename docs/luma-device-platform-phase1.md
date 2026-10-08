# LUMA Device Platform — Phase 1

This branch starts the frontend-facing device API inside the EMQX fork.

Phase 1 provides device discovery for connected ESP32 clients, device lookup, connection status, command submission, command IDs and response topics.

MQTT commands use luma/devices/{device_id}/command.

The command envelope contains command_id, device_id, command, params, response_topic and timestamp.

This phase intentionally uses current EMQX client/session state. Persistent registration, ownership, telemetry storage, heartbeat processing, retry queues and OTA are later phases.

GitHub Actions should compile and test this branch before it is considered valid.
