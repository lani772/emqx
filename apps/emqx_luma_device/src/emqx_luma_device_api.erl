-module(emqx_luma_device_api).
-behaviour(minirest_api).
-export([api_spec/0, paths/0, schema/1, fields/1, namespace/0, scopes/0]).
-export([register/2, devices/2, device/2]).
-define(TAGS, [<<"LUMA Devices">>]).
namespace() -> undefined.
api_spec() -> emqx_dashboard_swagger:spec(?MODULE, #{check_schema => true}).
scopes() -> ?SCOPE_PUBLISH.
paths() -> ["/devices/register", "/devices", "/devices/:deviceid"].
schema("/devices/register") -> #{'operationId' => register, post => #{description => <<"Register a LUMA device in the device registry.">>, tags => ?TAGS, 'requestBody' => hoconsc:ref(?MODULE, register_request), responses => #{201 => hoconsc:ref(?MODULE, device_response), 400 => hoconsc:mk(map(), #{})}}};
schema("/devices") -> #{'operationId' => devices, get => #{description => <<"List registered LUMA devices.">>, tags => ?TAGS, responses => #{200 => hoconsc:ref(?MODULE, device_list_response)}}};
schema("/devices/:deviceid") -> #{'operationId' => device, get => #{description => <<"Get a registered LUMA device.">>, tags => ?TAGS, parameters => [{deviceid, hoconsc:mk(binary(), #{in => path, required => true})}], responses => #{200 => hoconsc:ref(?MODULE, device_response), 404 => hoconsc:mk(map(), #{})}}}.
fields(register_request) -> [{device_id, hoconsc:mk(binary(), #{required => true})}, {permanent_uid, hoconsc:mk(binary(), #{required => true})}, {device_type, hoconsc:mk(binary(), #{required => true})}, {name, hoconsc:mk(binary(), #{required => false, default => <<>>})}, {model, hoconsc:mk(binary(), #{required => false, default => <<>>})}, {firmware_version, hoconsc:mk(binary(), #{required => false, default => <<>>})}, {capabilities, hoconsc:mk(map(), #{required => false, default => #{}})}, {tenant_id, hoconsc:mk(binary(), #{required => false, default => <<>>})}, {owner_id, hoconsc:mk(binary(), #{required => false, default => <<>>})}];
fields(device_response) -> [{device_id, hoconsc:mk(binary(), #{})}, {permanent_uid, hoconsc:mk(binary(), #{})}, {device_type, hoconsc:mk(binary(), #{})}, {name, hoconsc:mk(binary(), #{})}, {model, hoconsc:mk(binary(), #{})}, {firmware_version, hoconsc:mk(binary(), #{})}, {capabilities, hoconsc:mk(map(), #{})}, {tenant_id, hoconsc:mk(binary(), #{})}, {owner_id, hoconsc:mk(binary(), #{})}, {status, hoconsc:mk(binary(), #{})}, {registered_at, hoconsc:mk(integer(), #{})}, {last_seen_at, hoconsc:mk(integer(), #{})}];
fields(device_list_response) -> [{data, hoconsc:mk(list(), #{})}].
register(post, #{body := Body}) ->
    case required(Body, [<<"device_id">>, <<"permanent_uid">>, <<"device_type">>]) of
        ok ->
            DeviceId = maps:get(<<"device_id">>, Body),
            Device = #{device_id => DeviceId, permanent_uid => maps:get(<<"permanent_uid">>, Body), device_type => maps:get(<<"device_type">>, Body), name => maps:get(<<"name">>, Body, <<>>), model => maps:get(<<"model">>, Body, <<>>), firmware_version => maps:get(<<"firmware_version">>, Body, <<>>), capabilities => maps:get(<<"capabilities">>, Body, #{}), tenant_id => maps:get(<<"tenant_id">>, Body, <<>>), owner_id => maps:get(<<"owner_id">>, Body, <<>>), status => offline},
            case emqx_luma_device_registry:get(DeviceId) of
                {ok, _} -> {409, #{code => <<"CONFLICT">>, message => <<"Device already registered">>}};
                not_found -> {ok, Saved} = emqx_luma_device_registry:register(Device), {201, Saved}
            end;
        {error, Missing} -> {400, #{code => <<"VALIDATION_ERROR">>, message => Missing}}
    end.
devices(get, _Req) -> {200, #{data => emqx_luma_device_registry:list()}}.
device(get, #{bindings := #{deviceid := DeviceId}}) ->
    case emqx_luma_device_registry:get(DeviceId) of
        {ok, Device} -> {200, Device};
        not_found -> {404, #{code => <<"NOT_FOUND">>, message => <<"Device not found">>}}
    end.
required(Body, Keys) ->
    case lists:dropwhile(fun(K) -> maps:get(K, Body, undefined) =/= undefined andalso maps:get(K, Body) =/= <<>> end, Keys) of
        [] -> ok;
        [Missing|_] -> {error, <<"Missing required field: ", Missing/binary>>}
    end.
