-module(hex_api_tests).
-include_lib("eunit/include/eunit.hrl").
-define(OPTIONS, [
    {client, #{adapter => hex_http_test, user_agent_fragment => <<"(test)">>}},
    {uri, <<"https://api.test">>},
    {api_key, <<"dummy">>}
]).
% -define(OPTIONS, [{api_key, hex_test_helpers:api_key()}]).

get_test() ->
    {ok, #{}} = hex_api:get({package, <<"ecto">>}, ?OPTIONS),
    {ok, [#{} | _]} =
        hex_api:get({packages, [{search, <<"ecto">>}, {page, 1}]}, ?OPTIONS),
    {ok, [#{} | _]} = hex_api:get({owners, <<"decimal">>}, ?OPTIONS),
    {ok, #{}} = hex_api:get({release, <<"ecto">>, <<"1.0.0">>}, ?OPTIONS),
    {ok, #{}} = hex_api:get({user, <<"josevalim">>}, ?OPTIONS),
    {ok, [#{} | _]} = hex_api:get(keys, ?OPTIONS),
    ok.
