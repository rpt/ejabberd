%%%------------------------------------------------------------------------
%%% File:   ejabberd_snmp_backend.erl
%%% Author: Aleksandra Lipiec <aleksandra.lipiec@erlang-solutions.com>
%%%         Radoslaw Szymczyszyn <radoslaw.szymczyszyn@erlang-solutions.com>
%%% Description: Backend specific calculations for SNMP counters
%%%
%%% Created: 9 Aug 2011 by <radoslaw.szymczyszyn@erlang-solutions.com>
%%%-----------------------------------------------------------------------
-module(ejabberd_snmp_backend).

-include("ejabberd.hrl").
-include("jlib.hrl").
-include("mod_privacy.hrl").
-include("mod_roster.hrl").

%% Public API
-export([privacy_list_length/0,
         roster_size/0,
         roster_groups/0,
         registered_count/0
        ]).

%% Internal exports (used below by dispatch/0)
-export([mnesia_privacy_list_length/0,
         mnesia_roster_size/0,
         mnesia_roster_groups/0
        ]).

%% This is one of the gen_mod modules with different backends
-type ejabberd_module() :: atom().

%%-------------------
%% API
%%-------------------

privacy_list_length() ->
    dispatch(backends(mod_privacy), privacy_list_length).

roster_size() ->
    dispatch(backends(mod_roster), roster_size).

roster_groups() ->
    dispatch(backends(mod_roster), roster_groups).

registered_count() ->
    Hosts = ejabberd_config:get_global_option(hosts),
    Backends = sets:to_list(
                 lists:foldl(fun(Host, Set) ->
                                     Backend = ejabberd_config:get_local_option(
                                                 {auth_method, Host}),
                                     sets:add_element(Backend, Set)
                             end, sets:new(), Hosts)),
    lists:foldl(fun(Backend, Res) ->
                          Res + registered_count_disp(Backend)
                  end, 0, Backends).

%%-------------------
%% Helpers
%%-------------------

%% Determine backend for Module.
%%
%% This function is based on the assumption that different mod_sth backends
%% have different suffixes, e.g. mod_privacy for mnesia, mod_privacy_odbc
%% for ODBC.
%% Furthermore, they must be present in mnesia table local_config.
%% No module may appear with two or more different backends simultaneously
%% (impossible anyway, but mentioning it can't hurt).
-spec backends(ejabberd_module()) -> mnesia | odbc | none | {error, term()}.
backends(Module) ->
    %% extend if/when more backends appear (see also _1_)
    MnesiaBackend = Module,
    OdbcBackend = list_to_atom(atom_to_list(Module) ++ "_odbc"),
    
    Hosts = ejabberd_config:get_global_option(hosts),
    
    F = fun(Host, Set) ->
                Modules = ejabberd_config:get_local_option({modules, Host}),
                Select = fun({Mod,_}, Acc) ->
                                 %% ASSUMPTION: either mod_something or mod_something_odbc
                                 %% (or some other backend) is used, never both/all
                                 case Mod of
                                     %% _1_ add cases for more backends
                                     MnesiaBackend -> mnesia;
                                     OdbcBackend -> odbc;
                                     _ -> Acc
                                 end
                         end,
                sets:add_element(lists:foldl(Select, none, Modules), Set)
        end,
    sets:to_list(lists:foldl(F, sets:new(), Hosts)).
    
-spec dispatch(mnesia | odbc, atom()) -> term().
dispatch(Backends, Function) ->
    lists:foldl(fun(Backend, Res) ->
               BackendFunction = list_to_atom(atom_to_list(Backend) ++ "_"
                                                  ++ atom_to_list(Function)),
               case Backend of
                   mnesia ->
                       Res + apply(?MODULE, BackendFunction, []);
                   odbc ->
                       {error, ?ERR_INTERNAL_SERVER_ERROR};
                   _ ->
                       {error, ?ERR_INTERNAL_SERVER_ERROR}
               end
           end, 0, Backends). 


mnesia_privacy_list_length() ->
    F = fun() ->
        TotalItemsAndListCount = fun(#privacy{lists = NamedLists}, Acc) ->
            {_Names, Lists} = lists:unzip(NamedLists),
            lists:foldl(fun(ListItems, {TotalItems, ListCount}) ->
                    {TotalItems + length(ListItems), ListCount+1}
                end,
                Acc, Lists)
        end,
        case mnesia:foldl(TotalItemsAndListCount, {0,0}, privacy) of
            {_, 0} ->
                0;
            {TotalItems, ListCount} ->
                erlang:round(TotalItems / ListCount)
        end
    end,
    case mnesia:transaction(F) of
        {atomic, AvgLength} ->
            AvgLength;
        _ ->
            {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

mnesia_roster_size() ->
    F = fun() ->
        length(
            mnesia:foldl(fun(#roster{us = User}, Acc) ->
                lists:keystore(User, 1, Acc, {User,true})
            end,
            [], roster))
    end,
    case mnesia:transaction(F) of
        {atomic, 0} ->
            0;
        {atomic, UserCount} ->
            TableSize = mnesia:table_info(roster, size),
            erlang:round(TableSize / UserCount);
        _ ->
            {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

mnesia_roster_groups() ->
    F = fun() ->
        {Users, Groups} = mnesia:foldl(
            fun(#roster{us = User, groups = Groups}, {UAcc, GAcc}) ->
                NewUAcc = lists:keystore(User, 1, UAcc, {User,true}),
                NewGroups =
                    lists:filter(
                        fun(G) ->
                            not lists:member(G, GAcc)
                        end,
                        Groups),
                NewGAcc =
                    lists:foldl(
                        fun(G, Acc) ->
                            lists:keystore(G, 1, Acc, {G, true})
                        end,
                        GAcc, NewGroups),
                {NewUAcc, NewGAcc}
            end,
            {[],[]}, roster),
        {length(Users), length(Groups)}
    end,
    case mnesia:transaction(F) of
        {atomic, {0, _}} ->
            0;
        {atomic, {UserCount, GroupCount}} ->
            erlang:round(GroupCount / UserCount);
        _ ->
            {error, ?ERR_INTERNAL_SERVER_ERROR}
    end.

registered_count_disp(internal) ->
    ets:info(passwd, size);
registered_count_disp(_) ->
    0.         %% no such instance
