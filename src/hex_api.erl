-module(hex_api).
-export([
    default_options/0,
    get/1,
    get/2
]).

-type options() :: [{client, hex_http:client()} | {uri, binary()}].

-type search_params() :: [
    {sort, atom()} |
    {page, non_neg_integer()} |
    {description, binary()} |
    {extra, binary()}
].

-type resource() ::
    {key, Name :: binary()} |
    keys |
    {package, Name :: binary()} |
    {packages, search_params()} |
    {release, PackageName :: binary(), Version :: binary()} |
    {owner, PackageName :: binary(), Email :: binary()} |
    {owners, PackageName :: binary()} |
    {user, UsernameOrEmail :: binary()} |
    term().

%% @doc
%% Gets resource.
%%
%% Examples:
%%
%% ```
%%     {ok, Package} = hex_api:get({package, <<"ecto">>}),
%%     Package. %%=> #{<<"name">> => <<"ecto">>, ...}
%% '''
-spec get(resource()) -> {ok, map() | [map()]} | {error, term()}.
get(Resource) ->
    get(Resource, []).

%% @doc
%% Gets resource.
%%
%% `Options` is merged with `default_options/0`.
%%
%% See `get/1' for examples.
-spec get(resource(), options()) -> {ok, map() | [map()]} | {error, term()}.
get(Resource, Options) ->
    do_get(resource_uri(Resource), merge_with_default_options(Options)).

%% @doc
%% Default options used to interact with the API.
%% @end
-spec default_options() -> options().
default_options() ->
    Client = #{adapter => hex_http_httpc, user_agent_fragment => <<"(httpc)">>},
    URI = <<"https://hex.pm/api">>,
    [{client, Client}, {uri, URI}].

%%====================================================================
%% Internal functions
%%====================================================================

resource_uri({key, Name}) -> <<"/keys/", Name/binary>>;
resource_uri(keys) -> <<"/keys">>;
resource_uri({package, Name}) -> <<"/packages/", Name/binary>>;
resource_uri({packages, Params}) ->
    QueryString = encode_query_string(Params),
    <<"/packages?", QueryString/binary>>;
resource_uri({release, PackageName, Version}) -> <<"/packages/", PackageName/binary, "/releases/", Version/binary>>;
resource_uri({owners, PackageName}) -> <<"/packages/", PackageName/binary, "/owners">>;
resource_uri({owners, PackageName, Username}) -> <<"/packages/", PackageName/binary, "/owners/", Username/binary>>;
resource_uri({user, Username}) -> <<"/users/", Username/binary>>.

do_get(Path, Options) when is_binary(Path) and is_list(Options) ->
    Client = proplists:get_value(client, Options),
    URI = proplists:get_value(uri, Options),
    DefaultHeaders = make_headers(Options),
    ReqHeaders = maps:put(<<"accept">>, <<"application/vnd.hex+erlang">>, DefaultHeaders),

    case hex_http:get(Client, <<URI/binary, Path/binary>>, ReqHeaders) of
        {ok, {200, _RespHeaders, Body}} ->
            {ok, binary_to_term(Body)};

        {ok, {401, _RespHeaders, _Body}} ->
            {error, unauthorized};

        {ok, {404, _RespHeaders, _Body}} ->
            {error, not_found};

        Other ->
            Other
    end.

encode_query_string(List) ->
    QueryString =
        join("&",
            lists:map(fun
                ({K, V}) when is_atom(V) ->
                    atom_to_list(K) ++ "=" ++ atom_to_list(V);
                ({K, V}) when is_binary(V) ->
                    atom_to_list(K) ++ "=" ++ binary_to_list(V);
                ({K, V}) when is_integer(V) ->
                    atom_to_list(K) ++ "=" ++ integer_to_list(V)
            end, List)),
    Encoded = http_uri:encode(QueryString),
    list_to_binary(Encoded).

%% https://github.com/erlang/otp/blob/OTP-20.3/lib/stdlib/src/lists.erl#L1449:L1453
join(_Sep, []) -> [];
join(Sep, [H|T]) -> [H|join_prepend(Sep, T)].

join_prepend(_Sep, []) -> [];
join_prepend(Sep, [H|T]) -> [Sep,H|join_prepend(Sep,T)].

%% TODO: copy-pasted from hex_repo
make_headers(Options) ->
    lists:foldl(fun set_header/2, #{}, Options).

set_header({api_key, Token}, Headers) -> maps:put(<<"authorization">>, Token, Headers);
set_header(_Option, Headers) -> Headers.

merge_with_default_options(Options) when is_list(Options) ->
    lists:ukeymerge(1, lists:sort(Options), default_options()).
