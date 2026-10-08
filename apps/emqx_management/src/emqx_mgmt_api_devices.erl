%%--------------------------------------------------------------------
%% LUMA / ESP32 device control API for the lani772 EMQX fork.
%%
%% This module intentionally builds on EMQX's existing management and
%% publish APIs. It does not modify the MQTT broker routing engine.
%%--------------------------------------------------------------------
-module(emqx_mgmt_api_devices).

-behaviour(minirest_api).

-include_lib("typerefl/include/types.hrl").
-include_lib("hocon/include/hoconsc.hrl").
-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx_utils/include/emqx_api_key_scopes.hrl").

-export([
    api_spec/0,
    paths/0,
    schema/1,
    fields/1,
    namespace/0,
    scopes/0
]).

-export([
    devices/2,
    device/2,
    command/2
]).

-define(TAGS, [<<"ESP32 Devices">>]).
-define(DEVICE_PREFIX, <<"esp32-">>).
-define(DEFAULT_QOS, 1).

namespace() -> undefined.

api_spec() ->
    emqx_dashboard_swagger:spec(?MODULE, #{check_schema => true, translate_body => true}).

%% Reuse EMQX's publish permission for device commands.
%% Device discovery/status is also intentionally protected by the same
%% management API scope until a dedicated device scope is introduced.
scopes() -> ?SCOPE_PUBLISH.

paths() ->
    [
        <<"/devices">>,
        <<"/devices/:deviceid">>,
        <<"/devices/:deviceid/command">>
    ].

schema("/devices") ->
    #{
        'operationId' => devices,
        get => #{
            description => <<"List connected MQTT clients that use the ESP32 client-id convention.">>,
            tags => ?TAGS,
            parameters => [
                {prefix,
                    hoconsc:mk(binary(), #{
                        in => query,
                        required => false,
                        default => ?DEVICE_PREFIX,
                        desc => <<"Client ID prefix used to identify ESP32 devices.">>
                    })}
            ],
            responses => #{
                200 => hoconsc:mk(map(), #{desc => <<"Connected ESP32 device list.">>})
            }
        }
    };
schema("/devices/:deviceid") ->
    #{
        'operationId' => device,
        get => #{
            description => <<"Get the current EMQX client information for an ESP32 device.">>,
            tags => ?TAGS,
            parameters => [
                {deviceid, hoconsc:mk(binary(), #{in => path, required => true})}
            ],
            responses => #{
                200 => hoconsc:mk(map(), #{desc => <<"Device information.">>}),
                404 => hoconsc:mk(map(), #{desc => <<"Device is not connected or not found.">>})
            }
        }
    };
schema("/devices/:deviceid/command") ->
    #{
        'operationId' => command,
        post => #{
            description => <<"Publish a command to an ESP32 device. The device should subscribe to luma/devices/<device_id>/command.">>,
            tags => ?TAGS,
            parameters => [
                {deviceid, hoconsc:mk(binary(), #{in => path, required => true})}
            ],
            'requestBody' => hoconsc:mk(hoconsc:ref(?MODULE, command), #{}),
            responses => #{
                200 => hoconsc:mk(hoconsc:ref(?MODULE, command_response), #{}),
                400 => hoconsc:mk(map(), #{desc => <<"Invalid command.">>}),
                503 => hoconsc:mk(map(), #{desc => <<"Command could not be dispatched.">>})
            }
        }
    }.

fields(command) ->
    [
        {command,
            hoconsc:mk(binary(), #{
                required => true,
                desc => <<"Command name, for example set_power or set_brightness.">>,
                example => <<"set_power">>
            })},
        {params,
            hoconsc:mk(map(), #{
                required => false,
                default => #{},
                desc => <<"Command parameters.">>
            })},
        {qos,
            hoconsc:mk(emqx_schema:qos(), #{
                required => false,
                default => ?DEFAULT_QOS
            })},
        {retain,
            hoconsc:mk(boolean(), #{
                required => false,
                default => false
            })}
    ];
fields(command_response) ->
    [
        {command_id, hoconsc:mk(binary(), #{desc => <<"Unique command identifier.">>)},
        {device_id, hoconsc:mk(binary(), #{desc => <<"ESP32 device identifier.">>)},
        {topic, hoconsc:mk(binary(), #{desc => <<"MQTT command topic.">>)},
        {qos, hoconsc:mk(emqx_schema:qos(), #{desc => <<"MQTT QoS used for the command.">>)},
        {response_topic, hoconsc:mk(binary(), #{desc => <<"Expected asynchronous command response topic.">>)}
    ].

devices(get, #{query_string := Query}) ->
    Prefix = maps:get(<<"prefix">>, Query, ?DEVICE_PREFIX),
    %% Use the existing management client API so cluster-aware client
    %% discovery and its established formatting remain in one place.
    case emqx_mgmt_api_clients:clients(get, #{
        query_string => #{
            <<"like_clientid">> => <<Prefix/binary, "%">>,
            <<"limit">> => 100
        }
    }) of
        {200, #{data := Data, meta := Meta}} ->
            {200, #{data => [device_view(D) || D <- Data], meta => Meta}};
        Other ->
            Other
    end.

device(get, #{bindings := #{deviceid := DeviceId}}) ->
    case emqx_mgmt_api_clients:client(get, #{
        bindings => #{clientid => DeviceId}
    }) of
        {200, Client} ->
            {200, device_view(Client)};
        {404, _} = NotFound ->
            NotFound;
        Other ->
            Other
    end.

command(post, #{
    bindings := #{deviceid := DeviceId},
    body := Body
}) ->
    case validate_device_id(DeviceId) of
        ok ->
            publish_command(DeviceId, Body);
        {error, Message} ->
            {400, #{code => <<"INVALID_DEVICE_ID">>, message => Message}}
    end.

validate_device_id(<<>>) ->
    {error, <<"deviceid must not be empty">>};
validate_device_id(DeviceId) when byte_size(DeviceId) > 128 ->
    {error, <<"deviceid is too long">>};
validate_device_id(_DeviceId) ->
    ok.

publish_command(DeviceId, Body) ->
    CommandId = emqx_guid:to_hexstr(emqx_guid:gen()),
    Command = maps:get(<<"command">>, Body),
    Params = maps:get(<<"params">>, Body, #{}),
    QoS = maps:get(<<"qos">>, Body, ?DEFAULT_QOS),
    Retain = maps:get(<<"retain">>, Body, false),
    Topic = <<"luma/devices/", DeviceId/binary, "/command">>,
    ResponseTopic = <<"luma/devices/", DeviceId/binary, "/command/", CommandId/binary, "/response">>,
    Payload = emqx_utils_json:encode(#{
        <<"command_id">> => CommandId,
        <<"device_id">> => DeviceId,
        <<"command">> => Command,
        <<"params">> => Params,
        <<"response_topic">> => ResponseTopic,
        <<"timestamp">> => erlang:system_time(millisecond)
    }),
    Message = emqx_message:make(
        ?EXT_TRACE__HTTP_API_INTERNAL_CLIENTID,
        QoS,
        Topic,
        Payload,
        #{retain => Retain},
        #{}
    ),
    case emqx_mgmt:publish(Message) of
        [] ->
            {503, #{
                code => <<"DEVICE_OFFLINE">>,
                message => <<"No matching ESP32 subscriber is currently connected">>
            }};
        _PublishResult ->
            {200, #{
                command_id => CommandId,
                device_id => DeviceId,
                topic => Topic,
                qos => QoS,
                response_topic => ResponseTopic
            }}
    end.

device_view(Device) when is_map(Device) ->
    Device#{device_id => maps:get(clientid, Device, maps:get(<<"clientid">>, Device, undefined))};
device_view(Device) ->
    Device.
