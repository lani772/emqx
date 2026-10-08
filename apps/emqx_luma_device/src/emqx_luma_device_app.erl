-module(emqx_luma_device_app).
-behaviour(application).
-export([start/2, stop/1]).
start(_Type, _Args) -> emqx_luma_device_sup:start_link().
stop(_State) -> ok.
