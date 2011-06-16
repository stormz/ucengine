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
-module(appmod_uce).

-author('victor.goya@af83.com').

-include("uce.hrl").
-include_lib("yaws/include/yaws_api.hrl").

-export([out/1]).

convert2(string, Value) ->
    Value;
convert2(integer, Value) when is_integer(Value) ->
    Value;
convert2(integer, Value) ->
    case string:to_integer(Value) of
        {error, _} ->
            {error, bad_parameters};
        {Integer, _} ->
            Integer
    end;
convert2(atom, Value) when is_atom(Value) ->
    Value;
convert2(atom, Value) ->
    list_to_atom(Value);
convert2(dictionary, Value) ->
    Value;
convert2(file, Value) when is_record(Value, file_upload) ->
    Value;
convert2(file, _Value) ->
    {error, bad_parameters}.

convert(Param, Type)
  when is_atom(Type) ->
    convert(Param, [Type]);
convert(_, []) ->
    throw({error, bad_parameters});
convert(Param, [Type|Tail]) ->
    Result = convert2(Type, Param),
    case Result of
        {error, _} ->
            convert(Param, Tail);
        _ ->
            Result
    end.

validate(_, []) ->
    [];
validate(Query, [{Name, Default, Types}|ParamsSpecList]) ->
    case utils:get(Query, [Name], [Default]) of
        [required] ->
            throw({error, missing_parameters});
        [RawValue] ->
            [convert(RawValue, Types)] ++ validate(Query, ParamsSpecList)
    end.

call_handlers(Domain, {Module, Function, ParamsSpecList}, Query, Match, Arg) ->
    case catch validate(Query, ParamsSpecList) of
        {error, Reason} ->
            json_helpers:error(Domain, Reason);
        Params ->
            ?DEBUG("~p: call ~p:~p matching ~p with ~p~n", [Domain, Module, Function, Match, Params]),
            Now = now(),
            try Module:Function(Domain, Match, Params, Arg) of
                {streamcontent_with_timeout, _, _, _} = Stream ->
                    cors_helpers:format_cors_headers(Domain) ++ [Stream];
                Response when is_list(Response) ->
                    ?TIMER_APPEND(atom_to_list(Module) ++ "_" ++ atom_to_list(Function), Now),
                    Response
            catch
                {error, Reason} ->
                    ?ERROR_MSG("~p: error: ~p:~p: ~p ~p~n", [Domain, Module, Function, Reason, Params]),
                    json_helpers:error(Domain, Reason);
                E ->
                    ?ERROR_MSG("~p: error: ~p:~p: ~p ~p~n", [Domain, Module, Function, Params, E]),
                    json_helpers:unexpected_error(Domain)
            end
    end.

out(#arg{} = Arg) ->
    case get_host(Arg) of
        {ok, Host} ->
            case uce_http:parse(Host, Arg) of
                {error, Reason} ->
                    json_helpers:error(Reason);
                {get_more, _, _} = State ->
                    State;
                {Method, Path, Query} ->
                    process(Host, Method, Path, Query, Arg)
            end;
        {error, Reason} ->
            json_helpers:error(Reason)
    end.

process(_Host, _Method, undefined, _Query, _Arg) ->
    json_helpers:error(not_found);
process(Host, Method, Path, Query, Arg) ->
    case routes:get(Method, Path) of
        {ok, Match, Handlers} ->
            call_handlers(Host, Handlers, Query, Match, Arg);
        {error, not_found} ->
            ?ERROR_MSG("~p ~p: no route found~n", [Method, Path]),
            json_helpers:error(not_found);
        {error, Reason} ->
            json_helpers:error(Reason)
    end.

get_host(#arg{} = Arg) ->
    case extract_host(Arg) of
        {ok, Host} ->
            valid_host(Host, config:get(hosts));
        {error, Reason} ->
            {error, Reason}
    end.

extract_host(#arg{headers = Headers}) ->
    case catch string:sub_word(Headers#headers.host, 1, $:) of
        Host when is_list(Host) ->
            {ok, Host};
        _ ->
            {error, not_found}
    end.

valid_host(Host, Hosts) ->
    case proplists:lookup(Host, Hosts) of
        none ->
            {error, not_found};
        _ ->
            {ok, Host}
    end.

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

create_headers() ->
    #arg{}.
create_headers(Host) ->
    #arg{headers = #headers{host=Host}}.

extract_host_test() ->
    ?assertEqual({ok, "localhost"}, extract_host(create_headers("localhost"))),
    ?assertEqual({ok, "localhost"}, extract_host(create_headers("localhost:5280"))),
    ?assertEqual({error, not_found}, extract_host(create_headers())).

host_valid_test() ->
    ?assertEqual({ok, "localhost"}, valid_host("localhost", [{"localhost", []}, {"demo", []}])),
    ?assertEqual({ok, "demo"}, valid_host("demo", [{"localhost", []}, {"demo", []}])),
    ?assertEqual({error, not_found}, valid_host("localhost", [{"demo", []}])).

-endif.
