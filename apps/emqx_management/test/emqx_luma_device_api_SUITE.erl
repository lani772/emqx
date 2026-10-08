-module(emqx_luma_device_api_SUITE).
-compile(export_all).
-compile(nowarn_export_all).
all() -> [paths_contract, schema_contract].
paths_contract(_Config) -> Paths = emqx_luma_device_api:paths(), true = lists:member("/devices", Paths), true = lists:member("/devices/:deviceid/commands", Paths), true = lists:member("/devices/:deviceid/status", Paths), ok.
schema_contract(_Config) -> Fields = emqx_luma_device_api:fields(command_request), true = lists:keymember(command, 1, Fields), true = lists:keymember(params, 1, Fields), ok.