%%--------------------------------------------------------------------
%% Copyright (c) 2013-2018 EMQ Enterprise, Inc. (http://emqtt.io)
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emq_auth_http_cli).

-include_lib("emqttd/include/emqttd.hrl").

-export([request/3, request/4, feedvar/2, feedvar/3]).

%%--------------------------------------------------------------------
%% HTTP Request
%%--------------------------------------------------------------------

request(get, Url, Params) ->
  Req = {Url ++ "?" ++ mochiweb_util:urlencode(Params), []},
  reply(request_(get, Req, [{autoredirect, true}], [], 0));

request(post, Url, Params) ->
  Req = {Url, [], "application/x-www-form-urlencoded", mochiweb_util:urlencode(Params)},
  reply(request_(post, Req, [{autoredirect, true}], [], 0)).

request(post, Url, Params, Headers) ->
  Req = {Url, Headers, "application/x-www-form-urlencoded", mochiweb_util:urlencode(Params)},
  reply(request_(post, Req, [{autoredirect, true}], [], 0)).

request_(Method, Req, HTTPOpts, Opts, Times) ->
  %% Resend request, when TCP closed by remotely
  case httpc:request(Method, Req, HTTPOpts, Opts) of
    {error, socket_closed_remotely} when Times < 3 ->
      timer:sleep(trunc(math:pow(10, Times))),
      request_(Method, Req, HTTPOpts, Opts, Times + 1);
    Other -> Other
  end.

reply({ok, {{_, Code, _}, _Headers, Body}}) ->
  {ok, Code, Body};
reply({ok, Code, Body}) ->
  {ok, Code, Body};
reply({error, Error}) ->
  {error, Error}.

%%--------------------------------------------------------------------
%% Feed Variables
%%--------------------------------------------------------------------

feedvar(Params, #mqtt_client{username = Username, client_id = ClientId, peername = {IpAddr, _}}) ->
  lists:map(fun({Param, "%u"}) -> {Param, Username};
    ({Param, "%c"}) -> {Param, ClientId};
    ({Param, "%a"}) -> {Param, inet:ntoa(IpAddr)};
    (Param) -> Param
            end, Params).

feedvar(Params, Var, Val) ->
  lists:map(fun({Param, Var0}) when Var0 == Var -> {Param, Val}; (Param) -> Param end, Params).

