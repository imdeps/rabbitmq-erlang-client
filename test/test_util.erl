%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License at
%% http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
%% License for the specific language governing rights and limitations
%% under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2011-2015 Pivotal Software, Inc.  All rights reserved.
%%

-module(test_util).

-include_lib("eunit/include/eunit.hrl").
-include("amqp_client_internal.hrl").

-compile([export_all]).

-define(TEST_REPEATS, 100).

%% The latch constant defines how many processes are spawned in order
%% to run certain functionality in parallel. It follows the standard
%% countdown latch pattern.
-define(Latch, 100).

%% The wait constant defines how long a consumer waits before it
%% unsubscribes
-define(Wait, 200).

%% How to long wait for a process to die after an expected failure
-define(DeathWait, 5000).

%% AMQP URI parsing test
amqp_uri_parse_test() ->
    %% From the spec (adapted)
    ?assertMatch({ok, #amqp_params_network{username     = <<"user">>,
                                           password     = <<"pass">>,
                                           host         = "host",
                                           port         = 10000,
                                           virtual_host = <<"vhost">>,
                                           heartbeat    = 5}},
                 amqp_uri:parse(
                   "amqp://user:pass@host:10000/vhost?heartbeat=5")),
    ?assertMatch({ok, #amqp_params_network{username     = <<"usera">>,
                                           password     = <<"apass">>,
                                           host         = "hoast",
                                           port         = 10000,
                                           virtual_host = <<"v/host">>}},
                 amqp_uri:parse(
                   "aMQp://user%61:%61pass@ho%61st:10000/v%2fhost")),
    ?assertMatch({ok, #amqp_params_direct{}}, amqp_uri:parse("amqp://")),
    ?assertMatch({ok, #amqp_params_direct{username     = <<"">>,
                                          virtual_host = <<"">>}},
                 amqp_uri:parse("amqp://:@/")),
    ?assertMatch({ok, #amqp_params_network{username     = <<"">>,
                                           password     = <<"">>,
                                           virtual_host = <<"">>,
                                           host         = "host"}},
                 amqp_uri:parse("amqp://:@host/")),
    ?assertMatch({ok, #amqp_params_direct{username = <<"user">>}},
                 amqp_uri:parse("amqp://user@")),
    ?assertMatch({ok, #amqp_params_network{username = <<"user">>,
                                           password = <<"pass">>,
                                           host     = "localhost"}},
                 amqp_uri:parse("amqp://user:pass@localhost")),
    ?assertMatch({ok, #amqp_params_network{host         = "host",
                                           virtual_host = <<"/">>}},
                 amqp_uri:parse("amqp://host")),
    ?assertMatch({ok, #amqp_params_network{port = 10000,
                                           host = "localhost"}},
                 amqp_uri:parse("amqp://localhost:10000")),
    ?assertMatch({ok, #amqp_params_direct{virtual_host = <<"vhost">>}},
                 amqp_uri:parse("amqp:///vhost")),
    ?assertMatch({ok, #amqp_params_network{host         = "host",
                                           virtual_host = <<"">>}},
                 amqp_uri:parse("amqp://host/")),
    ?assertMatch({ok, #amqp_params_network{host         = "host",
                                           virtual_host = <<"/">>}},
                 amqp_uri:parse("amqp://host/%2f")),
    ?assertMatch({ok, #amqp_params_network{host = "::1"}},
                 amqp_uri:parse("amqp://[::1]")),

    %% Varous other cases
    ?assertMatch({ok, #amqp_params_network{host = "host", port = 100}},
                 amqp_uri:parse("amqp://host:100")),
    ?assertMatch({ok, #amqp_params_network{host = "::1", port = 100}},
                 amqp_uri:parse("amqp://[::1]:100")),

    ?assertMatch({ok, #amqp_params_network{host         = "host",
                                           virtual_host = <<"blah">>}},
                 amqp_uri:parse("amqp://host/blah")),
    ?assertMatch({ok, #amqp_params_network{host         = "host",
                                           port         = 100,
                                           virtual_host = <<"blah">>}},
                 amqp_uri:parse("amqp://host:100/blah")),
    ?assertMatch({ok, #amqp_params_network{host         = "::1",
                                           virtual_host = <<"blah">>}},
                 amqp_uri:parse("amqp://[::1]/blah")),
    ?assertMatch({ok, #amqp_params_network{host         = "::1",
                                           port         = 100,
                                           virtual_host = <<"blah">>}},
                 amqp_uri:parse("amqp://[::1]:100/blah")),

    ?assertMatch({ok, #amqp_params_network{username = <<"user">>,
                                           password = <<"pass">>,
                                           host     = "host"}},
                 amqp_uri:parse("amqp://user:pass@host")),
    ?assertMatch({ok, #amqp_params_network{username = <<"user">>,
                                           password = <<"pass">>,
                                           port     = 100}},
                 amqp_uri:parse("amqp://user:pass@host:100")),
    ?assertMatch({ok, #amqp_params_network{username = <<"user">>,
                                           password = <<"pass">>,
                                           host     = "::1"}},
                 amqp_uri:parse("amqp://user:pass@[::1]")),
    ?assertMatch({ok, #amqp_params_network{username = <<"user">>,
                                           password = <<"pass">>,
                                           host     = "::1",
                                           port     = 100}},
                 amqp_uri:parse("amqp://user:pass@[::1]:100")),

    %% Various failure cases
    ?assertMatch({error, _}, amqp_uri:parse("http://www.rabbitmq.com")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo:bar:baz")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo[::1]")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo:[::1]")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://[::1]foo")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo:1000xyz")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo:1000000")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo/bar/baz")),

    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo%1")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo%1x")),
    ?assertMatch({error, _}, amqp_uri:parse("amqp://foo%xy")),

    ok.

%%--------------------------------------------------------------------
%% Destination Parsing Tests
%%--------------------------------------------------------------------

route_destination_test() ->
    %% valid queue
    ?assertMatch({ok, {queue, "test"}}, parse_dest("/queue/test")),

    %% valid topic
    ?assertMatch({ok, {topic, "test"}}, parse_dest("/topic/test")),

    %% valid exchange
    ?assertMatch({ok, {exchange, {"test", undefined}}}, parse_dest("/exchange/test")),

    %% valid temp queue
    ?assertMatch({ok, {temp_queue, "test"}}, parse_dest("/temp-queue/test")),

    %% valid reply queue
    ?assertMatch({ok, {reply_queue, "test"}}, parse_dest("/reply-queue/test")),
    ?assertMatch({ok, {reply_queue, "test/2"}}, parse_dest("/reply-queue/test/2")),

    %% valid exchange with pattern
    ?assertMatch({ok, {exchange, {"test", "pattern"}}},
        parse_dest("/exchange/test/pattern")),

    %% valid pre-declared queue
    ?assertMatch({ok, {amqqueue, "test"}}, parse_dest("/amq/queue/test")),

    %% queue without name
    ?assertMatch({error, {invalid_destination, queue, ""}}, parse_dest("/queue")),
    ?assertMatch({ok, {queue, undefined}}, parse_dest("/queue", true)),

    %% topic without name
    ?assertMatch({error, {invalid_destination, topic, ""}}, parse_dest("/topic")),

    %% exchange without name
    ?assertMatch({error, {invalid_destination, exchange, ""}},
        parse_dest("/exchange")),

    %% exchange default name
    ?assertMatch({error, {invalid_destination, exchange, "//foo"}},
        parse_dest("/exchange//foo")),

    %% amqqueue without name
    ?assertMatch({error, {invalid_destination, amqqueue, ""}},
        parse_dest("/amq/queue")),

    %% queue without name with trailing slash
    ?assertMatch({error, {invalid_destination, queue, "/"}}, parse_dest("/queue/")),

    %% topic without name with trailing slash
    ?assertMatch({error, {invalid_destination, topic, "/"}}, parse_dest("/topic/")),

    %% exchange without name with trailing slash
    ?assertMatch({error, {invalid_destination, exchange, "/"}},
        parse_dest("/exchange/")),

    %% queue with invalid name
    ?assertMatch({error, {invalid_destination, queue, "/foo/bar"}},
        parse_dest("/queue/foo/bar")),

    %% topic with invalid name
    ?assertMatch({error, {invalid_destination, topic, "/foo/bar"}},
        parse_dest("/topic/foo/bar")),

    %% exchange with invalid name
    ?assertMatch({error, {invalid_destination, exchange, "/foo/bar/baz"}},
        parse_dest("/exchange/foo/bar/baz")),

    %% unknown destination
    ?assertMatch({error, {unknown_destination, "/blah/boo"}},
        parse_dest("/blah/boo")),

    %% queue with escaped name
    ?assertMatch({ok, {queue, "te/st"}}, parse_dest("/queue/te%2Fst")),

    %% valid exchange with escaped name and pattern
    ?assertMatch({ok, {exchange, {"te/st", "pa/tt/ern"}}},
        parse_dest("/exchange/te%2Fst/pa%2Ftt%2Fern")),

    ok.

parse_dest(Destination, Params) ->
    rabbit_routing_util:parse_endpoint(Destination, Params).
parse_dest(Destination) ->
    rabbit_routing_util:parse_endpoint(Destination).

%%%%
%%
%% This is an example of how the client interaction should work
%%
%%   {ok, Connection} = amqp_connection:start(network),
%%   {ok, Channel} = amqp_connection:open_channel(Connection),
%%   %%...do something useful
%%   amqp_channel:close(Channel),
%%   amqp_connection:close(Connection).
%%

lifecycle_test() ->
    {ok, Connection} = new_connection(),
    X = <<"x">>,
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel,
                      #'exchange.declare'{exchange = X,
                                          type = <<"topic">>}),
    Parent = self(),
    [spawn(fun () -> queue_exchange_binding(Channel, X, Parent, Tag) end)
     || Tag <- lists:seq(1, ?Latch)],
    latch_loop(),
    amqp_channel:call(Channel, #'exchange.delete'{exchange = X}),
    teardown(Connection, Channel),
    ok.

direct_no_user_test() ->
    {ok, Connection} = new_connection(just_direct, [{username, none},
                                                    {password, none}]),
    amqp_connection:close(Connection),
    wait_for_death(Connection).

direct_no_password_test() ->
    {ok, Connection} = new_connection(just_direct, [{username, <<"guest">>},
                                                    {password, none}]),
    amqp_connection:close(Connection),
    wait_for_death(Connection).

queue_exchange_binding(Channel, X, Parent, Tag) ->
    receive
        nothing -> ok
    after (?Latch - Tag rem 7) * 10 ->
        ok
    end,
    Q = <<"a.b.c", Tag:32>>,
    Binding = <<"a.b.c.*">>,
    #'queue.declare_ok'{queue = Q1}
        = amqp_channel:call(Channel, #'queue.declare'{queue = Q}),
    ?assertMatch(Q, Q1),
    Route = #'queue.bind'{queue = Q,
                          exchange = X,
                          routing_key = Binding},
    amqp_channel:call(Channel, Route),
    amqp_channel:call(Channel, #'queue.delete'{queue = Q}),
    Parent ! finished.

nowait_exchange_declare_test() ->
    {ok, Connection} = new_connection(),
    X = <<"x">>,
    {ok, Channel} = amqp_connection:open_channel(Connection),
    ?assertEqual(
      ok,
      amqp_channel:call(Channel, #'exchange.declare'{exchange = X,
                                                     type = <<"topic">>,
                                                     nowait = true})),
    teardown(Connection, Channel).

channel_lifecycle_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:close(Channel),
    {ok, Channel2} = amqp_connection:open_channel(Connection),
    teardown(Connection, Channel2),
    ok.

abstract_method_serialization_test(BeforeFun, MultiOpFun, AfterFun) ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    X = <<"test">>,
    Payload = list_to_binary(["x" || _ <- lists:seq(1, 1000)]),
    OpsPerProcess = 20,
    #'exchange.declare_ok'{} =
        amqp_channel:call(Channel, #'exchange.declare'{exchange = X,
                                                       type = <<"topic">>}),
    BeforeRet = BeforeFun(Channel, X),
    Parent = self(),
    [spawn(fun () -> Ret = [MultiOpFun(Channel, X, Payload, BeforeRet, I)
                            || _ <- lists:seq(1, OpsPerProcess)],
                   Parent ! {finished, Ret}
           end) || I <- lists:seq(1, ?Latch)],
    MultiOpRet = latch_loop(),
    AfterFun(Channel, X, Payload, BeforeRet, MultiOpRet),
    amqp_channel:call(Channel, #'exchange.delete'{exchange = X}),
    teardown(Connection, Channel).

%% This is designed to exercize the internal queuing mechanism
%% to ensure that sync methods are properly serialized
sync_method_serialization_test() ->
    abstract_method_serialization_test(
        fun (_, _) -> ok end,
        fun (Channel, _, _, _, Count) ->
                Q = fmt("test-~p", [Count]),
                #'queue.declare_ok'{queue = Q1} =
                    amqp_channel:call(Channel,
                                      #'queue.declare'{queue     = Q,
                                                       exclusive = true}),
                ?assertMatch(Q, Q1)
        end,
        fun (_, _, _, _, _) -> ok end).

%% This is designed to exercize the internal queuing mechanism
%% to ensure that sending async methods and then a sync method is serialized
%% properly
async_sync_method_serialization_test() ->
    abstract_method_serialization_test(
        fun (Channel, _X) ->
                #'queue.declare_ok'{queue = Q} =
                    amqp_channel:call(Channel, #'queue.declare'{}),
                Q
        end,
        fun (Channel, X, Payload, _, _) ->
                %% The async methods
                ok = amqp_channel:call(Channel,
                                       #'basic.publish'{exchange = X,
                                                        routing_key = <<"a">>},
                                       #amqp_msg{payload = Payload})
        end,
        fun (Channel, X, _, Q, _) ->
                %% The sync method
                #'queue.bind_ok'{} =
                    amqp_channel:call(Channel,
                                      #'queue.bind'{exchange = X,
                                                    queue = Q,
                                                    routing_key = <<"a">>}),
                %% No message should have been routed
                #'queue.declare_ok'{message_count = 0} =
                    amqp_channel:call(Channel,
                                      #'queue.declare'{queue = Q,
                                                       passive = true})
        end).

%% This is designed to exercize the internal queuing mechanism
%% to ensure that sending sync methods and then an async method is serialized
%% properly
sync_async_method_serialization_test() ->
    abstract_method_serialization_test(
        fun (_, _) -> ok end,
        fun (Channel, X, _Payload, _, _) ->
                %% The sync methods (called with cast to resume immediately;
                %% the order should still be preserved)
                #'queue.declare_ok'{queue = Q} =
                    amqp_channel:call(Channel,
                                      #'queue.declare'{exclusive = true}),
                amqp_channel:cast(Channel, #'queue.bind'{exchange = X,
                                                         queue = Q,
                                                         routing_key= <<"a">>}),
                Q
        end,
        fun (Channel, X, Payload, _, MultiOpRet) ->
                #'confirm.select_ok'{} = amqp_channel:call(
                                           Channel, #'confirm.select'{}),
                ok = amqp_channel:call(Channel,
                                       #'basic.publish'{exchange = X,
                                                        routing_key = <<"a">>},
                                       #amqp_msg{payload = Payload}),
                %% All queues must have gotten this message
                true = amqp_channel:wait_for_confirms(Channel),
                lists:foreach(
                    fun (Q) ->
                            #'queue.declare_ok'{message_count = 1} =
                                amqp_channel:call(
                                  Channel, #'queue.declare'{queue   = Q,
                                                            passive = true})
                    end, lists:flatten(MultiOpRet))
        end).

queue_unbind_test() ->
    {ok, Connection} = new_connection(),
    X = <<"eggs">>, Q = <<"foobar">>, Key = <<"quay">>,
    Payload = <<"foobar">>,
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'exchange.declare'{exchange = X}),
    amqp_channel:call(Channel, #'queue.declare'{queue = Q}),
    Bind = #'queue.bind'{queue = Q,
                         exchange = X,
                         routing_key = Key},
    amqp_channel:call(Channel, Bind),
    Publish = #'basic.publish'{exchange = X, routing_key = Key},
    amqp_channel:call(Channel, Publish, Msg = #amqp_msg{payload = Payload}),
    get_and_assert_equals(Channel, Q, Payload),
    Unbind = #'queue.unbind'{queue = Q,
                             exchange = X,
                             routing_key = Key},
    amqp_channel:call(Channel, Unbind),
    amqp_channel:call(Channel, Publish, Msg),
    get_and_assert_empty(Channel, Q),
    teardown(Connection, Channel).

get_and_assert_empty(Channel, Q) ->
    #'basic.get_empty'{}
        = amqp_channel:call(Channel, #'basic.get'{queue = Q, no_ack = true}).

get_and_assert_equals(Channel, Q, Payload) ->
    get_and_assert_equals(Channel, Q, Payload, true).

get_and_assert_equals(Channel, Q, Payload, NoAck) ->
    {GetOk = #'basic.get_ok'{}, Content}
        = amqp_channel:call(Channel, #'basic.get'{queue = Q, no_ack = NoAck}),
    #amqp_msg{payload = Payload2} = Content,
    ?assertMatch(Payload, Payload2),
    GetOk.

basic_get_test() ->
    basic_get_test1(new_connection()).

basic_get_ipv6_test() ->
    basic_get_test1(new_connection(just_network, [{host, "::1"}])).

basic_get_test1({ok, Connection}) ->
    {ok, Channel} = amqp_connection:open_channel(Connection),
    {ok, Q} = setup_publish(Channel),
    get_and_assert_equals(Channel, Q, <<"foobar">>),
    get_and_assert_empty(Channel, Q),
    teardown(Connection, Channel).

basic_return_test() ->
    {ok, Connection} = new_connection(),
    X = <<"test">>,
    Q = <<"test">>,
    Key = <<"test">>,
    Payload = <<"qwerty">>,
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:register_return_handler(Channel, self()),
    amqp_channel:call(Channel, #'exchange.declare'{exchange = X}),
    amqp_channel:call(Channel, #'queue.declare'{queue = Q,
                                                exclusive = true}),
    Publish = #'basic.publish'{exchange = X, routing_key = Key,
                               mandatory = true},
    amqp_channel:call(Channel, Publish, #amqp_msg{payload = Payload}),
    receive
        {BasicReturn = #'basic.return'{}, Content} ->
            #'basic.return'{reply_code = ReplyCode,
                            exchange = X} = BasicReturn,
            ?assertMatch(?NO_ROUTE, ReplyCode),
            #amqp_msg{payload = Payload2} = Content,
            ?assertMatch(Payload, Payload2);
        WhatsThis1 ->
            exit({bad_message, WhatsThis1})
    after 2000 ->
        exit(no_return_received)
    end,
    amqp_channel:unregister_return_handler(Channel),
    Publish = #'basic.publish'{exchange = X, routing_key = Key,
                               mandatory = true},
    amqp_channel:call(Channel, Publish, #amqp_msg{payload = Payload}),
    ok = receive
             {_BasicReturn = #'basic.return'{}, _Content} ->
                 unexpected_return;
             WhatsThis2 ->
                 exit({bad_message, WhatsThis2})
         after 2000 ->
                 ok
         end,
    amqp_channel:call(Channel, #'exchange.delete'{exchange = X}),
    teardown(Connection, Channel).

channel_repeat_open_close_test() ->
    {ok, Connection} = new_connection(),
    lists:foreach(
        fun(_) ->
            {ok, Ch} = amqp_connection:open_channel(Connection),
            ok = amqp_channel:close(Ch)
        end, lists:seq(1, 50)),
    amqp_connection:close(Connection),
    wait_for_death(Connection).

channel_multi_open_close_test() ->
    {ok, Connection} = new_connection(),
    [spawn_link(
        fun() ->
            try amqp_connection:open_channel(Connection) of
                {ok, Ch}           -> try amqp_channel:close(Ch) of
                                          ok                 -> ok;
                                          closing            -> ok
                                      catch
                                          exit:{noproc, _} -> ok;
                                          exit:{normal, _} -> ok
                                      end;
                closing            -> ok
            catch
                exit:{noproc, _} -> ok;
                exit:{normal, _} -> ok
            end
        end) || _ <- lists:seq(1, 50)],
    erlang:yield(),
    amqp_connection:close(Connection),
    wait_for_death(Connection).

basic_ack_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    {ok, Q} = setup_publish(Channel),
    {#'basic.get_ok'{delivery_tag = Tag}, _}
        = amqp_channel:call(Channel, #'basic.get'{queue = Q, no_ack = false}),
    amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
    teardown(Connection, Channel).

basic_ack_call_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    {ok, Q} = setup_publish(Channel),
    {#'basic.get_ok'{delivery_tag = Tag}, _}
        = amqp_channel:call(Channel, #'basic.get'{queue = Q, no_ack = false}),
    amqp_channel:call(Channel, #'basic.ack'{delivery_tag = Tag}),
    teardown(Connection, Channel).

basic_consume_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    X = <<"test">>,
    amqp_channel:call(Channel, #'exchange.declare'{exchange = X}),
    RoutingKey = <<"key">>,
    Parent = self(),
    [spawn_link(fun () ->
                        consume_loop(Channel, X, RoutingKey, Parent, <<Tag:32>>)
                end) || Tag <- lists:seq(1, ?Latch)],
    timer:sleep(?Latch * 20),
    Publish = #'basic.publish'{exchange = X, routing_key = RoutingKey},
    amqp_channel:call(Channel, Publish, #amqp_msg{payload = <<"foobar">>}),
    latch_loop(),
    amqp_channel:call(Channel, #'exchange.delete'{exchange = X}),
    teardown(Connection, Channel).

consume_loop(Channel, X, RoutingKey, Parent, Tag) ->
    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Channel, #'queue.declare'{}),
    #'queue.bind_ok'{} =
        amqp_channel:call(Channel, #'queue.bind'{queue = Q,
                                                 exchange = X,
                                                 routing_key = RoutingKey}),
    #'basic.consume_ok'{} =
        amqp_channel:call(Channel,
                          #'basic.consume'{queue = Q, consumer_tag = Tag}),
    receive #'basic.consume_ok'{consumer_tag = Tag} -> ok end,
    receive {#'basic.deliver'{}, _} -> ok end,
    #'basic.cancel_ok'{} =
        amqp_channel:call(Channel, #'basic.cancel'{consumer_tag = Tag}),
    receive #'basic.cancel_ok'{consumer_tag = Tag} -> ok end,
    Parent ! finished.

consume_notification_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Channel, #'queue.declare'{}),
    #'basic.consume_ok'{consumer_tag = CTag} = ConsumeOk =
        amqp_channel:call(Channel, #'basic.consume'{queue = Q}),
    receive ConsumeOk -> ok end,
    #'queue.delete_ok'{} =
        amqp_channel:call(Channel, #'queue.delete'{queue = Q}),
    receive #'basic.cancel'{consumer_tag = CTag} -> ok end,
    amqp_channel:close(Channel),
    ok.

basic_recover_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(
                        Connection, {amqp_direct_consumer, [self()]}),
    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Channel, #'queue.declare'{}),
    #'basic.consume_ok'{consumer_tag = Tag} =
        amqp_channel:call(Channel, #'basic.consume'{queue = Q}),
    receive #'basic.consume_ok'{consumer_tag = Tag} -> ok end,
    Publish = #'basic.publish'{exchange = <<>>, routing_key = Q},
    amqp_channel:call(Channel, Publish, #amqp_msg{payload = <<"foobar">>}),
    receive
        {#'basic.deliver'{consumer_tag = Tag}, _} ->
            %% no_ack set to false, but don't send ack
            ok
    end,
    BasicRecover = #'basic.recover'{requeue = true},
    amqp_channel:cast(Channel, BasicRecover),
    receive
        {#'basic.deliver'{consumer_tag = Tag,
                          delivery_tag = DeliveryTag2}, _} ->
            amqp_channel:cast(Channel,
                              #'basic.ack'{delivery_tag = DeliveryTag2})
    end,
    teardown(Connection, Channel).

simultaneous_close_test() ->
    {ok, Connection} = new_connection(),
    ChannelNumber = 5,
    {ok, Channel1} = amqp_connection:open_channel(Connection, ChannelNumber),

    %% Publish to non-existent exchange and immediately close channel
    amqp_channel:cast(Channel1, #'basic.publish'{exchange = <<"does-not-exist">>,
                                                 routing_key = <<"a">>},
                               #amqp_msg{payload = <<"foobar">>}),
    try amqp_channel:close(Channel1) of
        ok      -> wait_for_death(Channel1);
        closing -> wait_for_death(Channel1)
    catch
        exit:{noproc, _}                                              -> ok;
        exit:{{shutdown, {server_initiated_close, ?NOT_FOUND, _}}, _} -> ok
    end,

    %% Channel2 (opened with the exact same number as Channel1)
    %% should not receive a close_ok (which is intended for Channel1)
    {ok, Channel2} = amqp_connection:open_channel(Connection, ChannelNumber),

    %% Make sure Channel2 functions normally
    #'exchange.declare_ok'{} =
        amqp_channel:call(Channel2, #'exchange.declare'{exchange = <<"test">>}),
    #'exchange.delete_ok'{} =
        amqp_channel:call(Channel2, #'exchange.delete'{exchange = <<"test">>}),

    teardown(Connection, Channel2).

channel_tune_negotiation_test() ->
    {ok, Connection} = new_connection([{channel_max, 10}]),
    amqp_connection:close(Connection).

basic_qos_test() ->
    [NoQos, Qos] = [basic_qos_test(Prefetch) || Prefetch <- [0,1]],
    ExpectedRatio = (1+1) / (1+50/5),
    FudgeFactor = 2, %% account for timing variations
    ?assertMatch(true, Qos / NoQos < ExpectedRatio * FudgeFactor).

basic_qos_test(Prefetch) ->
    {ok, Connection} = new_connection(),
    Messages = 100,
    Workers = [5, 50],
    Parent = self(),
    {ok, Chan} = amqp_connection:open_channel(Connection),
    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Chan, #'queue.declare'{}),
    Kids = [spawn(
            fun() ->
                {ok, Channel} = amqp_connection:open_channel(Connection),
                amqp_channel:call(Channel,
                                  #'basic.qos'{prefetch_count = Prefetch}),
                amqp_channel:call(Channel,
                                  #'basic.consume'{queue = Q}),
                Parent ! finished,
                sleeping_consumer(Channel, Sleep, Parent)
            end) || Sleep <- Workers],
    latch_loop(length(Kids)),
    spawn(fun() -> {ok, Channel} = amqp_connection:open_channel(Connection),
                   producer_loop(Channel, Q, Messages)
          end),
    {Res, _} = timer:tc(erlang, apply, [fun latch_loop/1, [Messages]]),
    [Kid ! stop || Kid <- Kids],
    latch_loop(length(Kids)),
    teardown(Connection, Chan),
    Res.

sleeping_consumer(Channel, Sleep, Parent) ->
    receive
        stop ->
            do_stop(Channel, Parent);
        #'basic.consume_ok'{} ->
            sleeping_consumer(Channel, Sleep, Parent);
        #'basic.cancel_ok'{}  ->
            exit(unexpected_cancel_ok);
        {#'basic.deliver'{delivery_tag = DeliveryTag}, _Content} ->
            Parent ! finished,
            receive stop -> do_stop(Channel, Parent)
            after Sleep -> ok
            end,
            amqp_channel:cast(Channel,
                              #'basic.ack'{delivery_tag = DeliveryTag}),
            sleeping_consumer(Channel, Sleep, Parent)
    end.

do_stop(Channel, Parent) ->
    Parent ! finished,
    amqp_channel:close(Channel),
    wait_for_death(Channel),
    exit(normal).

producer_loop(Channel, _RoutingKey, 0) ->
    amqp_channel:close(Channel),
    wait_for_death(Channel),
    ok;

producer_loop(Channel, RoutingKey, N) ->
    Publish = #'basic.publish'{exchange = <<>>, routing_key = RoutingKey},
    amqp_channel:call(Channel, Publish, #amqp_msg{payload = <<>>}),
    producer_loop(Channel, RoutingKey, N - 1).

confirm_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'confirm.select_ok'{} = amqp_channel:call(Channel, #'confirm.select'{}),
    amqp_channel:register_confirm_handler(Channel, self()),
    {ok, Q} = setup_publish(Channel),
    {#'basic.get_ok'{}, _}
        = amqp_channel:call(Channel, #'basic.get'{queue = Q, no_ack = false}),
    ok = receive
             #'basic.ack'{}  -> ok;
             #'basic.nack'{} -> fail
         after 2000 ->
                 exit(did_not_receive_pub_ack)
         end,
    teardown(Connection, Channel).

confirm_barrier_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'confirm.select_ok'{} = amqp_channel:call(Channel, #'confirm.select'{}),
    [amqp_channel:call(Channel, #'basic.publish'{routing_key = <<"whoosh">>},
                       #amqp_msg{payload = <<"foo">>})
     || _ <- lists:seq(1, 1000)], %% Hopefully enough to get a multi-ack
    true = amqp_channel:wait_for_confirms(Channel),
    teardown(Connection, Channel).

confirm_select_before_wait_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    try amqp_channel:wait_for_confirms(Channel) of
        _ -> exit(success_despite_lack_of_confirm_mode)
    catch
        not_in_confirm_mode -> ok
    end,
    teardown(Connection, Channel).

confirm_barrier_timeout_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'confirm.select_ok'{} = amqp_channel:call(Channel, #'confirm.select'{}),
    [amqp_channel:call(Channel, #'basic.publish'{routing_key = <<"whoosh">>},
                       #amqp_msg{payload = <<"foo">>})
     || _ <- lists:seq(1, 1000)],
    case amqp_channel:wait_for_confirms(Channel, 0) of
        true    -> ok;
        timeout -> ok
    end,
    teardown(Connection, Channel).

confirm_barrier_die_timeout_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'confirm.select_ok'{} = amqp_channel:call(Channel, #'confirm.select'{}),
    [amqp_channel:call(Channel, #'basic.publish'{routing_key = <<"whoosh">>},
                       #amqp_msg{payload = <<"foo">>})
     || _ <- lists:seq(1, 1000)],
    try amqp_channel:wait_for_confirms_or_die(Channel, 0) of
        true    -> ok
    catch
        exit:timeout -> ok
    end,
    amqp_connection:close(Connection),
    wait_for_death(Connection).

default_consumer_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_selective_consumer:register_default_consumer(Channel, self()),

    #'queue.declare_ok'{queue = Q}
        = amqp_channel:call(Channel, #'queue.declare'{}),
    Pid = spawn(fun () -> receive
                          after 10000 -> ok
                          end
                end),
    #'basic.consume_ok'{} =
        amqp_channel:subscribe(Channel, #'basic.consume'{queue = Q}, Pid),
    erlang:monitor(process, Pid),
    exit(Pid, shutdown),
    receive
        {'DOWN', _, process, _, _} ->
            io:format("little consumer died out~n")
    end,
    Payload = <<"for the default consumer">>,
    amqp_channel:call(Channel,
                      #'basic.publish'{exchange = <<>>, routing_key = Q},
                      #amqp_msg{payload = Payload}),

    receive
        {#'basic.deliver'{}, #'amqp_msg'{payload = Payload}} ->
            ok
    after 1000 ->
            exit('default_consumer_didnt_work')
    end,
    teardown(Connection, Channel).

subscribe_nowait_test() ->
    {ok, Conn} = new_connection(),
    {ok, Ch} = amqp_connection:open_channel(Conn),
    {ok, Q} = setup_publish(Ch),
    CTag = <<"ctag">>,
    amqp_selective_consumer:register_default_consumer(Ch, self()),
    ok = amqp_channel:call(Ch, #'basic.consume'{queue        = Q,
                                                consumer_tag = CTag,
                                                nowait       = true}),
    ok = amqp_channel:call(Ch, #'basic.cancel' {consumer_tag = CTag,
                                                nowait       = true}),
    ok = amqp_channel:call(Ch, #'basic.consume'{queue        = Q,
                                                consumer_tag = CTag,
                                                nowait       = true}),
    receive
        #'basic.consume_ok'{} ->
            exit(unexpected_consume_ok);
        {#'basic.deliver'{delivery_tag = DTag}, _Content} ->
            amqp_channel:cast(Ch, #'basic.ack'{delivery_tag = DTag})
    end,
    teardown(Conn, Ch).

basic_nack_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'queue.declare_ok'{queue = Q}
        = amqp_channel:call(Channel, #'queue.declare'{}),

    Payload = <<"m1">>,

    amqp_channel:call(Channel,
                      #'basic.publish'{exchange = <<>>, routing_key = Q},
                      #amqp_msg{payload = Payload}),

    #'basic.get_ok'{delivery_tag = Tag} =
        get_and_assert_equals(Channel, Q, Payload, false),

    amqp_channel:call(Channel, #'basic.nack'{delivery_tag = Tag,
                                             multiple     = false,
                                             requeue      = false}),

    get_and_assert_empty(Channel, Q),
    teardown(Connection, Channel).

large_content_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    #'queue.declare_ok'{queue = Q}
        = amqp_channel:call(Channel, #'queue.declare'{}),
    random:seed(erlang:phash2([node()]),
                time_compat:monotonic_time(),
                time_compat:unique_integer()),
    F = list_to_binary([random:uniform(256)-1 || _ <- lists:seq(1, 1000)]),
    Payload = list_to_binary([[F || _ <- lists:seq(1, 1000)]]),
    Publish = #'basic.publish'{exchange = <<>>, routing_key = Q},
    amqp_channel:call(Channel, Publish, #amqp_msg{payload = Payload}),
    get_and_assert_equals(Channel, Q, Payload),
    teardown(Connection, Channel).

%% ----------------------------------------------------------------------------
%% Test for the network client
%% Sends a bunch of messages and immediatly closes the connection without
%% closing the channel. Then gets the messages back from the queue and expects
%% all of them to have been sent.
pub_and_close_test() ->
    {ok, Connection1} = new_connection(just_network),
    Payload = <<"eggs">>,
    NMessages = 50000,
    {ok, Channel1} = amqp_connection:open_channel(Connection1),
    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Channel1, #'queue.declare'{}),
    %% Send messages
    pc_producer_loop(Channel1, <<>>, Q, Payload, NMessages),
    %% Close connection without closing channels
    amqp_connection:close(Connection1),
    %% Get sent messages back and count them
    {ok, Connection2} = new_connection(just_network),
    {ok, Channel2} = amqp_connection:open_channel(
                         Connection2, {amqp_direct_consumer, [self()]}),
    amqp_channel:call(Channel2, #'basic.consume'{queue = Q, no_ack = true}),
    receive #'basic.consume_ok'{} -> ok end,
    ?assert(pc_consumer_loop(Channel2, Payload, 0) == NMessages),
    %% Make sure queue is empty
    #'queue.declare_ok'{queue = Q, message_count = NRemaining} =
        amqp_channel:call(Channel2, #'queue.declare'{queue   = Q,
                                                     passive = true}),
    ?assert(NRemaining == 0),
    amqp_channel:call(Channel2, #'queue.delete'{queue = Q}),
    teardown(Connection2, Channel2),
    ok.

pc_producer_loop(_, _, _, _, 0) -> ok;
pc_producer_loop(Channel, X, Key, Payload, NRemaining) ->
    Publish = #'basic.publish'{exchange = X, routing_key = Key},
    ok = amqp_channel:call(Channel, Publish, #amqp_msg{payload = Payload}),
    pc_producer_loop(Channel, X, Key, Payload, NRemaining - 1).

pc_consumer_loop(Channel, Payload, NReceived) ->
    receive
        {#'basic.deliver'{},
         #amqp_msg{payload = DeliveredPayload}} ->
            case DeliveredPayload of
                Payload ->
                    pc_consumer_loop(Channel, Payload, NReceived + 1);
                _ ->
                    exit(received_unexpected_content)
            end
    after 1000 ->
        NReceived
    end.

%%---------------------------------------------------------------------------
%% This tests whether RPC over AMQP produces the same result as invoking the
%% same argument against the same underlying gen_server instance.
rpc_test() ->
    {ok, Connection} = new_connection(),
    Fun = fun(X) -> X + 1 end,
    RPCHandler = fun(X) -> term_to_binary(Fun(binary_to_term(X))) end,
    Q = <<"rpc-test">>,
    Server = amqp_rpc_server:start(Connection, Q, RPCHandler),
    Client = amqp_rpc_client:start(Connection, Q),
    Input = 1,
    Reply = amqp_rpc_client:call(Client, term_to_binary(Input)),
    Expected = Fun(Input),
    DecodedReply = binary_to_term(Reply),
    ?assertMatch(Expected, DecodedReply),
    amqp_rpc_client:stop(Client),
    amqp_rpc_server:stop(Server),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'queue.delete'{queue = Q}),
    amqp_connection:close(Connection),
    wait_for_death(Connection),
    ok.

%% This tests if the RPC continues to generate valid correlation ids
%% over a series of requests.
rpc_client_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    Q = <<"rpc-test">>,
    Latch = 255, % enough requests to tickle bad correlation ids
    %% Start a server to return correlation ids to the client.
    Server = spawn_link(fun() ->
                                rpc_correlation_server(Channel, Q)
                        end),
    %% Generate a series of RPC requests on the same client.
    Client = amqp_rpc_client:start(Connection, Q),
    Parent = self(),
    [spawn(fun() ->
                   Reply = amqp_rpc_client:call(Client, <<>>),
                   Parent ! {finished, Reply}
           end) || _ <- lists:seq(1, Latch)],
    %% Verify that the correlation ids are valid UTF-8 strings.
    CorrelationIds = latch_loop(Latch),
    [?assertMatch(<<_/binary>>, DecodedId)
     || DecodedId <- [unicode:characters_to_binary(Id, utf8)
                      || Id <- CorrelationIds]],
    %% Cleanup.
    Server ! stop,
    amqp_rpc_client:stop(Client),
    amqp_channel:call(Channel, #'queue.delete'{queue = Q}),
    teardown(Connection, Channel),
    ok.

%% Consumer of RPC requests that replies with the CorrelationId.
rpc_correlation_server(Channel, Q) ->
    amqp_channel:register_return_handler(Channel, self()),
    amqp_channel:call(Channel, #'queue.declare'{queue = Q}),
    amqp_channel:call(Channel, #'basic.consume'{queue = Q,
                                                consumer_tag = <<"server">>}),
    rpc_client_consume_loop(Channel),
    amqp_channel:call(Channel, #'basic.cancel'{consumer_tag = <<"server">>}),
    amqp_channel:unregister_return_handler(Channel).

rpc_client_consume_loop(Channel) ->
    receive
        stop ->
            ok;
        {#'basic.deliver'{delivery_tag = DeliveryTag},
         #amqp_msg{props = Props}} ->
            #'P_basic'{correlation_id = CorrelationId,
                       reply_to = Q} = Props,
            Properties = #'P_basic'{correlation_id = CorrelationId},
            Publish = #'basic.publish'{exchange = <<>>,
                                       routing_key = Q,
                                       mandatory = true},
            amqp_channel:call(
              Channel, Publish, #amqp_msg{props = Properties,
                                          payload = CorrelationId}),
            amqp_channel:call(
              Channel, #'basic.ack'{delivery_tag = DeliveryTag}),
            rpc_client_consume_loop(Channel);
        _ ->
            rpc_client_consume_loop(Channel)
    after 3000 ->
            exit(no_request_received)
    end.

%%---------------------------------------------------------------------------

%% connection.blocked, connection.unblocked

connection_blocked_network_test() ->
    {ok, Connection} = new_connection(just_network),
    X = <<"amq.direct">>,
    K = Payload = <<"x">>,
    clear_resource_alarm(memory),
    timer:sleep(1000),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    Parent = self(),
    Child = spawn_link(
              fun() ->
                      receive
                          #'connection.blocked'{} -> ok
                      end,
                      clear_resource_alarm(memory),
                      receive
                          #'connection.unblocked'{} -> ok
                      end,
                      Parent ! ok
              end),
    amqp_connection:register_blocked_handler(Connection, Child),
    set_resource_alarm(memory),
    Publish = #'basic.publish'{exchange = X,
                               routing_key = K},
    amqp_channel:call(Channel, Publish,
                      #amqp_msg{payload = Payload}),
    timer:sleep(1000),
    receive
        ok ->
            clear_resource_alarm(memory),
            clear_resource_alarm(disk),
            ok
    after 10000 ->
        clear_resource_alarm(memory),
        clear_resource_alarm(disk),
        exit(did_not_receive_connection_blocked)
    end.

%%---------------------------------------------------------------------------

setup_publish(Channel) ->
    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Channel, #'queue.declare'{exclusive = true}),
    ok = amqp_channel:call(Channel, #'basic.publish'{exchange    = <<>>,
                                                     routing_key = Q},
                           #amqp_msg{payload = <<"foobar">>}),
    {ok, Q}.

teardown(Connection, Channel) ->
    amqp_channel:close(Channel),
    wait_for_death(Channel),
    amqp_connection:close(Connection),
    wait_for_death(Connection).

teardown_test() ->
    {ok, Connection} = new_connection(),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    ?assertMatch(true, is_process_alive(Channel)),
    ?assertMatch(true, is_process_alive(Connection)),
    teardown(Connection, Channel),
    ?assertMatch(false, is_process_alive(Channel)),
    ?assertMatch(false, is_process_alive(Connection)).

wait_for_death(Pid) ->
    Ref = erlang:monitor(process, Pid),
    receive {'DOWN', Ref, process, Pid, _Reason} -> ok
    after ?DeathWait -> exit({timed_out_waiting_for_process_death, Pid})
    end.

latch_loop() ->
    latch_loop(?Latch, []).

latch_loop(Latch) ->
    latch_loop(Latch, []).

latch_loop(0, Acc) ->
    Acc;
latch_loop(Latch, Acc) ->
    receive
        finished        -> latch_loop(Latch - 1, Acc);
        {finished, Ret} -> latch_loop(Latch - 1, [Ret | Acc])
    after ?Latch * ?Wait -> exit(waited_too_long)
    end.

new_connection() ->
    new_connection(both, []).

new_connection(AllowedConnectionTypes) when is_atom(AllowedConnectionTypes) ->
    new_connection(AllowedConnectionTypes, []);
new_connection(Params) when is_list(Params) ->
    new_connection(both, Params).

new_connection(AllowedConnectionTypes, Params) ->
    Params1 =
        case {AllowedConnectionTypes,
              os:getenv("AMQP_CLIENT_TEST_CONNECTION_TYPE")} of
            {just_direct, "network"} ->
                exit(normal);
            {just_direct, "network_ssl"} ->
                exit(normal);
            {just_network, "direct"} ->
                exit(normal);
            {_, "network"} ->
                make_network_params(Params);
            {_, "network_ssl"} ->
                {ok, [[CertsDir]]} = init:get_argument(erlang_client_ssl_dir),
                make_network_params(
                  [{ssl_options, [{cacertfile,
                                   CertsDir ++ "/testca/cacert.pem"},
                                  {certfile, CertsDir ++ "/client/cert.pem"},
                                  {keyfile, CertsDir ++ "/client/key.pem"},
                                  {verify, verify_peer},
                                  {fail_if_no_peer_cert, true}]}] ++ Params);
            {_, "direct"} ->
                make_direct_params([{node, rabbit_nodes:make(rabbit)}] ++
                                       Params)
        end,
    amqp_connection:start(Params1).

%% Note: not all amqp_params_network fields supported.
make_network_params(Props) ->
    Pgv = fun (Key, Default) ->
                  proplists:get_value(Key, Props, Default)
          end,
    #amqp_params_network{username     = Pgv(username, <<"guest">>),
                         password     = Pgv(password, <<"guest">>),
                         virtual_host = Pgv(virtual_host, <<"/">>),
                         channel_max  = Pgv(channel_max, 0),
                         ssl_options  = Pgv(ssl_options, none),
                         host         = Pgv(host, "localhost")}.

%% Note: not all amqp_params_direct fields supported.
make_direct_params(Props) ->
    Pgv = fun (Key, Default) ->
                  proplists:get_value(Key, Props, Default)
          end,
    #amqp_params_direct{username     = Pgv(username, <<"guest">>),
                        password     = Pgv(password, <<"guest">>),
                        virtual_host = Pgv(virtual_host, <<"/">>),
                        node         = Pgv(node, node())}.

set_resource_alarm(memory) ->
    os:cmd("cd ../rabbitmq-test; make set-resource-alarm SOURCE=memory");
set_resource_alarm(disk) ->
    os:cmd("cd ../rabbitmq-test; make set-resource-alarm SOURCE=disk").


clear_resource_alarm(memory) ->
    os:cmd("cd ../rabbitmq-test; make clear-resource-alarm SOURCE=memory");
clear_resource_alarm(disk) ->
    os:cmd("cd ../rabbitmq-test; make clear-resource-alarm SOURCE=disk").

fmt(Fmt, Args) -> list_to_binary(rabbit_misc:format(Fmt, Args)).
