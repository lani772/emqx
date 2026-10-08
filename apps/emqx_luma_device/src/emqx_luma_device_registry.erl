-module(emqx_luma_device_registry).
-export([start/0, register/1, get/1, list/0, update/2, delete/1, touch/1]).
-define(TABLE, emqx_luma_device_registry).
start() ->
    case ets:info(?TABLE) of
        undefined -> ets:new(?TABLE, [named_table, public, set, {read_concurrency, true}]), ok;
        _ -> ok
    end.
register(Device) when is_map(Device) ->
    start(),
    DeviceId = maps:get(device_id, Device),
    Now = erlang:system_time(millisecond),
    Record = Device#{device_id => DeviceId, registered_at => maps:get(registered_at, Device, Now), last_seen_at => maps:get(last_seen_at, Device, undefined), status => maps:get(status, Device, offline)},
    true = ets:insert(?TABLE, {DeviceId, Record}),
    {ok, Record}.
get(DeviceId) ->
    start(),
    case ets:lookup(?TABLE, DeviceId) of [{_, Device}] -> {ok, Device}; [] -> not_found end.
list() ->
    start(),
    [Device || {_, Device} <- ets:tab2list(?TABLE)].
update(DeviceId, Changes) ->
    case get(DeviceId) of
        {ok, Device} -> register(maps:merge(Device, Changes));
        not_found -> not_found
    end.
delete(DeviceId) ->
    start(),
    ets:delete(?TABLE, DeviceId),
    ok.
touch(DeviceId) ->
    update(DeviceId, #{last_seen_at => erlang:system_time(millisecond), status => online}).
