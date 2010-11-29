-module(uce_acl_mongodb).

-author('victor.goya@af83.com').

-export([add/1,
	 delete/5,
	 list/3,
	 from_collection/1,
	 to_collection/1]).

-include("uce.hrl").
-include("mongodb.hrl").

add(#uce_acl{}=ACL) ->
    case catch emongo:insert(?MONGO_POOL, "uce_acl", ?MODULE:to_collection(ACL)) of
	{'EXIT', _} ->
	    {error, bad_parameters};
	_ ->
	    ok
    end.

delete(Uid, Object, Action, Location, Conditions) ->
    case exists(Uid, Object, Action, Location, Conditions) of
	false ->
	    {error, not_found};
	true ->
	    case catch emongo:delete(?MONGO_POOL, "uce_acl", [{"uid", Uid},
							      {"object", Object},
							      {"action", Action},
							      {"location", Location},
							      {"conditions", Conditions}]) of
		{'EXIT', _} ->
		    {error, bad_parameters};
		_ ->
		    ok
	    end
    end.

list(Uid, Object, Action) ->
    case catch emongo:find_all(?MONGO_POOL, "uce_acl", [{"uid", Uid},
                                                        {"object", Object},
                                                        {"action", Action}]) of
	
	{'EXIT', _} ->
	    {error, bad_parameters};
	ACLCollections ->
	    ACL = lists:map(fun(Collection) ->
				    ?MODULE:from_collection(Collection)
			    end,
			    ACLCollections),
	    AllActions = case Action of
			     "all" ->
				 [];
			     _ ->
				 ?MODULE:list(Uid, Object, "all")
			 end,
	    AllObjects = case Object of
			     "all" ->
				 [];
			     _ ->
				 ?MODULE:list(Uid, "all", Action)
			 end,
	    ACL ++ AllActions ++ AllObjects
    end.

from_collection(Collection) ->
    case utils:get(mongodb_helpers:collection_to_list(Collection),
		   ["uid", "object", "action", "location", "conditions"]) of
	[Uid, Object, Action, Location, Conditions] ->
	    #uce_acl{uid=Uid,
		     action=Action,
		     object=Object,
		     location=Location,
		     conditions=Conditions};
	_ ->
	    {error, bad_parameters}
    end.
						      
to_collection(#uce_acl{uid=Uid,
		       object=Object,
		       action=Action,
		       location=Location,
		       conditions=Conditions}) ->
    [{"uid", Uid},
     {"object", Object},
     {"action", Action},
     {"location", Location},
     {"conditions", Conditions}].

exists(Uid, Object, Action, Location, Conditions) ->
    case catch emongo:find_all(?MONGO_POOL, "uce_acl", [{"uid", Uid},
                                                        {"object", Object},
                                                        {"action", Action},
                                                        {"location", Location},
                                                        {"conditions", Conditions}],
			  [{limit, 1}]) of
	{'EXIT', _} ->
	    false;
	[] ->
	    false;
	_ ->
	    true
    end.
