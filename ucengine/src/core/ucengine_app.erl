%%
%%  U.C.Engine - Unified Colloboration Engine
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
    error_logger:tty(false),
    application:start(crypto),
    mnesia:create_schema([node()|nodes()]),
    application:start(mnesia, permanent),
    ibrowse:start(),
    application:start(metrics),

    Arguments = init:get_arguments(),
    [[ConfigurationPath]] = utils:get(Arguments, [c], [["etc/uce.cfg"]]),
    case uce_sup:start_link(ConfigurationPath) of
        {ok, Pid} ->
            setup(),
            {ok, Pid};
        Error ->
            {error, Error}
    end.

setup() ->
    save_pid(),
    setup_search(),
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

setup_server() ->
    [{DefaultHost, _Config}|Hosts] = config:get(hosts),
    yaws:start_embedded(config:get(DefaultHost, root),
                        [{servername, DefaultHost},
                         {listen, {0,0,0,0}},
                         {port, config:get(port)},
                         {access_log, true},
                         {partial_post_size, nolimit},
                         {appmods, [{"/api/" ++ ?VERSION, appmod_uce}]}],
                        [{auth_log, false},
                         {logdir, config:get(log_dir)},
                         {copy_errlog, false},
                         {debug, false},
                         {copy_error_log, false},
                         {max_connections, nolimit}]),
    lists:foreach(fun({Vhost, _}) ->
                          yaws:add_server(config:get(Vhost, root),
                                          [{servername, Vhost},
                                           {listen, {0,0,0,0}},
                                           {port, config:get(port)},
                                           {appmods, [{"/api/" ++ ?VERSION, appmod_uce}]}])
                  end, Hosts),
    {ok, GConf, SConfs} = yaws_api:getconf(),
    yaws_api:setconf(GConf#gconf{cache_refresh_secs=config:get(cache_refresh)}, SConfs).

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
