-module(emqx_luma_device_registry_SUITE).
-compile(export_all).
-compile(nowarn_export_all).
all() -> [register_get_update_delete].
register_get_update_delete(_Config) ->
    emqx_luma_device_registry:start(),
    {ok, D} = emqx_luma_device_registry:register(#{device_id => <<"esp32-phase2-001">>, permanent_uid => <<"uid-001">>, device_type => <<"smart_lamp">>}),
    <<"esp32-phase2-001">> = maps:get(device_id, D),
    {ok, _} = emqx_luma_device_registry:get(<<"esp32-phase2-001">>),
    {ok, U} = emqx_luma_device_registry:update(<<"esp32-phase2-001">>, #{name => <<"Lamp 1">>}),
    <<"Lamp 1">> = maps:get(name, U),
    ok = emqx_luma_device_registry:delete(<<"esp32-phase2-001">>),
    not_found = emqx_luma_device_registry:get(<<"esp32-phase2-001">>),
    ok.
