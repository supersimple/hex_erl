-module(hex_repo).
-export([
    default_options/0,
    get_names/0,
    get_names/1,
    get_versions/0,
    get_versions/1,
    get_package/1,
    get_package/2,
    get_tarball/2,
    get_tarball/3
]).
%% https://hex.pm/docs/public_keys
-define(HEXPM_PUBLIC_KEY, <<"-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApqREcFDt5vV21JVe2QNB
Edvzk6w36aNFhVGWN5toNJRjRJ6m4hIuG4KaXtDWVLjnvct6MYMfqhC79HAGwyF+
IqR6Q6a5bbFSsImgBJwz1oadoVKD6ZNetAuCIK84cjMrEFRkELtEIPNHblCzUkkM
3rS9+DPlnfG8hBvGi6tvQIuZmXGCxF/73hU0/MyGhbmEjIKRtG6b0sJYKelRLTPW
XgK7s5pESgiwf2YC/2MGDXjAJfpfCd0RpLdvd4eRiXtVlE9qO9bND94E7PgQ/xqZ
J1i2xWFndWa6nfFnRxZmCStCOZWYYPlaxr+FZceFbpMwzTNs4g3d4tLNUcbKAIH4
0wIDAQAB
-----END PUBLIC KEY-----">>).

-type options() :: [{client, client()} | {repo, repo()} | {verify, boolean()}|
                    {etag, etag()}     | {cache_dir, file:filename_all()}].
-type etag() :: binary().
-type client() :: #{adapter => hex_http:adapter(), user_agent_string => string()}.
-type repo() :: #{uri => string(), public_key => binary()}.

%%====================================================================
%% API functions
%%====================================================================

%% @doc
%% Default options used to interact with the repository.
%% @end
-spec default_options() -> options().
default_options() ->
    Client = #{adapter => hex_http_httpc, user_agent_fragment => <<"(httpc)">>},
    Repo = #{uri => <<"https://repo.hex.pm">>, public_key => ?HEXPM_PUBLIC_KEY},
    lists:sort([{client, Client}, {repo, Repo}, {verify, true}]).

%% @doc
%% Gets names resource from the repository.
%%
%% Examples:
%%
%% ```
%%     hex_repo:get_names().
%%     %%=> {ok,
%%     %%=>     #{package => [
%%     %%=>         #{name => <<"package1">>},
%%     %%=>         #{name => <<"package2">>},
%%     %%=>     ]},
%%     %%=>     [{etag, ...}, ...]}
%% '''
%% @end
-spec get_names() -> {ok, map(), proplists:proplist()} | {error, term()}.
get_names() ->
    get_names([]).

%% @doc
%% Gets names resource from the repository.
%%
%% `Options` is merged with `default_options/0`.
%%
%% See `get_names/0' for examples.
%% @end
-spec get_names(options()) -> {ok, map(), proplists:proplist()} | {error, term()}.
get_names(Options) when is_list(Options) ->
    Decoder = fun hex_registry:decode_names/1,
    get_protobuf(<<"/names">>, Decoder, merge_with_default_options(Options)).

%% @doc
%% Gets versions resource from the repository.
%%
%% Examples:
%%
%% ```
%%     hex_repo:get_versions().
%%     %%=> {ok,
%%     %%=>     #{packages => [
%%     %%=>         #{name => <<"package1">>, retired => [],
%%     %%=>           versions => [<<"1.0.0">>]},
%%     %%=>         #{name => <<"package2">>, retired => [<<"0.5.0>>"],
%%     %%=>           versions => [<<"0.5.0">>, <<"1.0.0">>]},
%%     %%=>     ]},
%%     %%=>     [{etag, ...}, ...]}
%% '''
%% @end
-spec get_versions() -> {ok, map(), proplists:proplist()} | {error, term()}.
get_versions() ->
    get_versions([]).

%% @doc
%% Gets versions resource from the repository.
%%
%% `Options` is merged with `default_options/0`.
%%
%% See `get_versions/0' for examples.
%% @end
-spec get_versions(options()) -> {ok, map(), proplists:proplist()} | {error, term()}.
get_versions(Options) when is_list(Options) ->
    Decoder = fun hex_registry:decode_versions/1,
    get_protobuf(<<"/versions">>, Decoder, merge_with_default_options(Options)).

%% @doc
%% Gets package resource from the repository.
%%
%% Examples:
%%
%% ```
%%     hex_repo:get_package(<<"package1">>).
%%     %%=> {ok,
%%     %%=>     #{releases => [
%%     %%=>         #{checksum => ..., version => <<"0.5.0">>, dependencies => []},
%%     %%=>         #{checksum => ..., version => <<"1.0.0">>, dependencies => [
%%     %%=>             #{package => <<"package2">>, optional => true, requirement => <<"~> 0.1">>}
%%     %%=>         ]},
%%     %%=>     ]},
%%     %%=>     [{etag, ...}, ...]}
%% '''
%% @end
-spec get_package(binary()) -> {ok, map(), proplists:proplist()} | {error, term()}.
get_package(Name) when is_binary(Name) ->
    get_package(Name, []).

%% @doc
%% Gets package resource from the repository.
%%
%% `Options` is merged with `default_options/0`.
%%
%% See `get_package/1' for examples.
%% @end
-spec get_package(binary(), options()) -> {ok, map(), proplists:proplist()} | {error, term()}.
get_package(Name, Options) when is_binary(Name) and is_list(Options) ->
    Decoder = fun hex_registry:decode_package/1,
    get_protobuf(<<"/packages/", Name/binary>>, Decoder, merge_with_default_options(Options)).

%% @doc
%% Gets tarball from the repository.
%%
%% Examples:
%%
%% ```
%%     {ok, Tarball, _Proplist} = hex_repo:get_tarball(<<"package1">>, <<"1.0.0">>),
%%     {ok, #{metadata := Metadata}} = hex_tarball:unpack(Tarball, memory).
%% '''
%% @end
-spec get_tarball(binary(), binary()) -> {ok, hex_tarball:tarball(), proplists:proplist()} | {error, term()}.
get_tarball(Name, Version) when is_binary(Name) and is_binary(Version) ->
    get_tarball(Name, Version, []).

%% @doc
%% Gets tarball from the repository.
%%
%% `Options` is merged with `default_options/0`.
%%
%% See `get_tarball/2' for examples.
%% @end
-spec get_tarball(string(), string(), options()) -> {ok, hex_tarball:tarball(), proplists:proplist()} | {error, term()}.
get_tarball(Name, Version, Options) ->
    Options2 = merge_with_default_options(Options),
    Client = proplists:get_value(client, Options2),
    Repo = proplists:get_value(repo, Options2),
    CacheDir = proplists:get_value(cache_dir, Options2),
    ReqHeaders = make_headers(Options2),

    case get(Client, tarball_uri(Repo, Name, Version), ReqHeaders) of
        {ok, {200, RespHeaders, Tarball}} ->
            ReturnOpts = get_headers([{<<"etag">>, etag}], RespHeaders),
            ok = maybe_put_cache(CacheDir, tarball_filename(Name, Version), Tarball),
            {ok, Tarball, [{cache, miss} | ReturnOpts]};

        {ok, {304, RespHeaders, _Body}} ->
            ReturnOpts = get_headers([{<<"etag">>, etag}], RespHeaders),
            {ok, Tarball} = get_cache(CacheDir, tarball_filename(Name, Version)),
            {ok, Tarball, [{cache, hit} | ReturnOpts]};

        {ok, {403, _RespHeaders, _Body}} ->
            {error, not_found};

        {error, Reason} ->
            {error, Reason}
    end.

%%====================================================================
%% Internal functions
%%====================================================================

%% @private
%% @doc Given a list of tuples of binary header fields and atom
%% names to use in a proplist as output, along with a map of header key/values,
%% extract the given fields from the map of headers if they exist and return
%% them in a proplist.
%%
%% <B>N.B.</B>: The proplist may be empty!
-spec get_headers([{ Field :: binary(), OptionName :: atom()}],
                  Headers :: map()) -> proplists:proplist().
get_headers(Fields, Headers) ->
    lists:foldl(fun(F, Acc) -> extract_field(F, Acc, Headers) end, [], Fields).

extract_field({Field, OptionName}, Acc, Headers) ->
    case maps:is_key(Field, Headers) of
        false -> Acc;
        true -> [{OptionName, maps:get(Field, Headers)} | Acc]
    end.

make_headers(Options) ->
    lists:foldl(fun set_header/2, #{}, Options).

set_header({etag, ETag}, Headers) -> maps:put(<<"if-none-match">>, ETag, Headers);
set_header({api_key, Token}, Headers) -> maps:put(<<"authorization">>, Token, Headers);
set_header(_Option, Headers) -> Headers.

get(Client, URI, Headers) ->
    hex_http:get(Client, URI, Headers).

get_protobuf(Path, Decoder, Options) ->
    Client = proplists:get_value(client, Options),
    #{uri := URI, public_key := PublicKey} = proplists:get_value(repo, Options),
    CacheDir = proplists:get_value(cache_dir, Options),
    CachePath = filename:basename(Path),
    ReqHeaders = make_headers(Options),

    case get(Client, <<URI/binary, Path/binary>>, ReqHeaders) of
        {ok, {200, RespHeaders, Compressed}} ->
            ReturnOpts = get_headers([{<<"etag">>, etag}], RespHeaders),
            ok = maybe_put_cache(CacheDir, CachePath, Compressed),
            Signed = zlib:gunzip(Compressed),
            case decode(Signed, PublicKey, Decoder, Options) of
                {ok, Decoded} ->
                    {ok, Decoded, [{cache, miss} | ReturnOpts]};
                {error, _} = Error ->
                    Error
            end;

        {ok, {304, RespHeaders, _Body}} ->
            ReturnOpts = get_headers([{<<"etag">>, etag}], RespHeaders),
            {ok, Compressed} = get_cache(CacheDir, CachePath),
            Signed = zlib:gunzip(Compressed),
            case decode(Signed, PublicKey, Decoder, Options) of
                {ok, Decoded} ->
                    {ok, Decoded, [{cache, hit} | ReturnOpts]};
                {error, _} = Error ->
                    Error
            end;

        {ok, {403, _, _}} ->
            {error, not_found};

        {error, Reason} ->
            {error, Reason}
    end.

decode(Signed, PublicKey, Decoder, Options) ->
    Verify = proplists:get_value(verify, Options, true),

    case Verify of
        true ->
            case hex_registry:decode_and_verify_signed(Signed, PublicKey) of
                {ok, Payload} ->
                    {ok, Decoder(Payload)};
                Other ->
                    Other
            end;
        false ->
            #{payload := Payload} = hex_registry:decode_signed(Signed),
            {ok, Decoder(Payload)}
    end.

tarball_uri(#{uri := URI}, Name, Version) ->
    Filename = tarball_filename(Name, Version),
    <<URI/binary, "/tarballs/", Filename/binary>>.

tarball_filename(Name, Version) ->
    <<Name/binary, "-", Version/binary, ".tar">>.

maybe_put_cache(undefined, _Filename, _Data) ->
    ok;
maybe_put_cache(CacheDir, Filename, Data) ->
    put_cache(CacheDir, Filename, Data).

put_cache(CacheDir, Filename, Data) ->
    Path = filename:join(CacheDir, Filename),
    ok = filelib:ensure_dir(Path),
    file:write_file(Path, Data).

get_cache(undefined, _Filename) ->
    {error, no_cache_dir};
get_cache(CacheDir, Filename) ->
    Path = filename:join(CacheDir, Filename),
    file:read_file(Path).

merge_with_default_options(Options) when is_list(Options) ->
    lists:ukeymerge(1, lists:sort(Options), default_options()).
