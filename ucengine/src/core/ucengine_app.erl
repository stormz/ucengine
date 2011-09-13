%%
%%  U.C.Engine - Unified Collaboration Engine
%%  Copyright (C) 2011 af83
%%
%%  This program is free software: you can redistribute it and/or modify
%%  it under the terms of the GNU Affero General Public License as published by
%%  the Free Software Foundation, either version 3 of the License, or
%%  (at your option) any later version.
%%
%%  This program is distributed in the hope that it will be useful,
%%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%%  GNU Affero General Public License for more details.
%%
%%  You should have received a copy of the GNU Affero General Public License
%%  along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%
-module(ucengine_app).
-author('victor.goya@af83.com').

-behaviour(application).

-export([start/0]).


%% application callback
-export([start/2, stop/1]).

-include("uce.hrl").
-include_lib("yaws/include/yaws.hrl").


start() ->
    application:start(ucengine).

start(_, _) ->
    start_apps([sasl, crypto, metrics, gproc, ibrowse]),
    mnesia:create_schema([node()|nodes()]),
    application:start(mnesia, permanent),
    error_logger:tty(false),

    Arguments = init:get_arguments(),
    [[ConfigurationPath]] = utils:get(Arguments, [c], [["etc/uce.cfg"]]),
    ok = config:init(ConfigurationPath),
    case uce_sup:start_link() of
        {ok, Pid} ->
            setup(),
            {ok, Pid};
        Error ->
            {error, Error}
    end.

start_apps([]) ->
    ok;
start_apps([App|Apps]) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok;
        Error ->
            io:format("error ~p~n", [Error])
    end,
    start_apps(Apps).

setup() ->
    save_pid(),
    setup_search(),
    setup_routes(),
    setup_server(),
    ok.

stop(State) ->
    remove_pid(),
    State.

setup_search() ->
    case config:get(search) of
        solr ->
            ChildSpec = {uce_solr_commiter,
                         {uce_solr_commiter, start_link, []},
                         permanent, brutal_kill, worker, [uce_solr_commiter]},
            {ok, _Pid} = uce_sup:start_child(ChildSpec);
        _ ->
            []
    end.

setup_routes() ->
    routes:init().

setup_server() ->
    [{DefaultHost, _Config}|Hosts] = config:get(hosts),
    yaws:start_embedded(config:get(DefaultHost, wwwroot),
                        [{servername, DefaultHost},
                         {listen, config:get(bind_ip)},
                         {port, config:get(port)},
                         {access_log, true},
                         {partial_post_size, nolimit},
                         {opaque, DefaultHost},
                         {appmods, [{"/api/" ++ ?VERSION, uce_appmod}]}],
                        [{flags, [{auth_log, false},
                                  {copy_errlog, false},
                                  {pick_first_virthost_on_nomatch, false},
                                  {debug, false}
                                 ]},
                         {logdir, config:get(log_dir)},
                         {cache_refresh_secs, config:get(cache_refresh)}]),
    lists:foreach(fun({Vhost, _}) ->
                          yaws:add_server(config:get(Vhost, wwwroot),
                                          [{servername, Vhost},
                                           {listen, config:get(bind_ip)},
                                           {port, config:get(port)},
                                           {opaque, Vhost},
                                           {appmods, [{"/api/" ++ ?VERSION, uce_appmod}]}])
                  end, Hosts).

save_pid() ->
    Pid = os:getpid(),
    PidFile = config:get(pidfile),
    {ok, PidFileId} = file:open(PidFile, [read, write]),
    io:fwrite(PidFileId, "~s", [Pid]),
    file:close(PidFileId),
    ok.

remove_pid() ->
    PidFile = config:get(pidfile),
    file:delete(PidFile),
    ok.
