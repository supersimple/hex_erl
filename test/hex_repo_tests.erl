-module(hex_repo_tests).
-include_lib("eunit/include/eunit.hrl").
-define(OPTIONS, [
    {client, #{adapter => hex_http_test, user_agent_fragment => <<"(test)">>}},
    {repo, #{
        uri => <<"https://repo.test">>,
        public_key => hex_test_helpers:fixture("test_pub.pem")}
    },
    {verify, true}
]).
% -define(OPTIONS, []).

get_names_test() ->
    {ok, #{packages := Packages}, _} = hex_repo:get_names(?OPTIONS),
    [#{name := <<"ecto">>}] =
        lists:filter(fun(#{name := Name}) -> Name == <<"ecto">> end, Packages),
    ok.

get_names_cache_test() ->
    hex_test_helpers:in_tmp(fun() ->
        Options = [{cache_dir, "cache"} | ?OPTIONS],
        {ok, _, [{cache, miss}, {etag, ETag}]} = hex_repo:get_names(Options),

        Options2 = [{etag, ETag} | Options],
        {ok, _, [{cache, hit}, {etag, ETag}]} = hex_repo:get_names(Options2),
        ok
    end).

get_versions_test() ->
    {ok, #{packages := Packages}, _} = hex_repo:get_versions(?OPTIONS),
    [#{name := <<"ecto">>, versions := _}] =
        lists:filter(fun(#{name := Name}) -> Name == <<"ecto">> end, Packages),
    ok.

get_package_test() ->
    {ok, #{releases := Releases}, _} = hex_repo:get_package(<<"ecto">>, ?OPTIONS),
    [#{version := <<"1.0.0">>}] =
        lists:filter(fun(#{version := Version}) -> Version == <<"1.0.0">> end, Releases),

    {error, not_found} = hex_repo:get_package(<<"nonexisting">>, ?OPTIONS),
    ok.

get_tarball_test() ->
    {ok, Tarball, _} = hex_repo:get_tarball(<<"ecto">>, <<"1.0.0">>, ?OPTIONS),
    {ok, _} = hex_tarball:unpack(Tarball, memory),
    ok.

get_tarball_cache_test() ->
    hex_test_helpers:in_tmp(fun() ->
        Options = [{cache_dir, "cache/tarballs"} | ?OPTIONS],
        {ok, _, [{cache, miss}, {etag, ETag}]} = hex_repo:get_tarball(<<"ecto">>, <<"1.0.0">>, Options),

        Options2 = [{etag, ETag} | Options],
        {ok, _, [{cache, hit}, {etag, ETag}]} = hex_repo:get_tarball(<<"ecto">>, <<"1.0.0">>, Options2),
        ok
    end).
