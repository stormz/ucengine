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
-module(access_helpers).

-export([to_json/1]).

-include("uce.hrl").

to_json(ACL)
  when is_list(ACL) ->
    {array, [?MODULE:to_json(Access) || Access <- ACL]};
to_json(#uce_access{action=Action,
		    object=Object,
		    conditions=Conditions}) ->
    {struct,
     [{action, Action},
      {object, Object},
      {conditions, {struct, Conditions}}]}.
