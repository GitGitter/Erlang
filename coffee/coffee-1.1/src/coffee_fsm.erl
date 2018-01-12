-module(coffee_fsm).
-behaviour(gen_fsm).
-vsn('1.1').
-export([start_link/0, init/1]).
-export([selection/2, payment/2, remove/2, service/2]).
-export([americano/0, cappuccino/0, tea/0, espresso/0,
         pay/1, cancel/0, cup_removed/0, open/0, close/0]).

-export([stop/0, selection/3, payment/3, remove/3, service/3]).
-export([terminate/3, code_change/4]).

start_link() ->
    gen_fsm:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    hw:reboot(),
    hw:display("Make Your Selection", []),
    {ok, selection, []}.

%% Client Functions for Drink Selections
tea() ->  gen_fsm:send_event(?MODULE,{selection,tea,100}).
espresso() ->gen_fsm:send_event(?MODULE,{selection,espresso,150}).
americano() -> gen_fsm:send_event(?MODULE,{selection,americano,100}).
cappuccino() -> gen_fsm:send_event(?MODULE,{selection,cappuccino,150}).


%% Client Functions for Actions
pay(Coin)     -> gen_fsm:send_event(?MODULE,{pay, Coin}).
cancel()      -> gen_fsm:send_event(?MODULE,cancel).
cup_removed() -> gen_fsm:send_event(?MODULE,cup_removed).
open()        -> gen_fsm:send_event(?MODULE, open).
close()       -> gen_fsm:send_event(?MODULE, close).



%% State: drink selection
selection({selection,Type,Price}, _LoopData) ->
    hw:display("Please pay:~w",[Price]),
    {next_state, payment, {Type, Price, 0}};
selection({pay, Coin}, LoopData) ->
    hw:return_change(Coin),
    {next_state, selection, LoopData};
selection(open, LoopData) ->
    hw:display("Open", [ ]),
    {next_state, service, LoopData};
selection(_Other, LoopData) ->
    {next_state, selection, LoopData}.

%% State: service machine
service(close, LoopData) ->
    hw:reboot(),
    hw:display("Make Your Selection", []),
    {next_state, selection, LoopData};
service({pay, Coin}, LoopData) ->
    hw:return_change(Coin),
    {next_state, service, LoopData};
service(_Other, LoopData) ->
    {next_state, service, LoopData}.

payment({pay, Coin}, {Type,Price,Paid})
  when Coin+Paid >= Price ->
    NewPaid = Coin + Paid,
    hw:display("Preparing Drink.",[]),
    hw:return_change(NewPaid - Price),
    hw:drop_cup(), hw:prepare(Type),
    hw:display("Remove Drink.", []),
    {next_state, remove, []};
payment({pay, Coin}, {Type,Price,Paid})
  when Coin+Paid < Price ->
    NewPaid = Coin + Paid,
    hw:display("Please pay:~w",[Price - NewPaid]),
    {next_state, payment, {Type, Price, NewPaid}};
payment(cancel, {_Type, _Price, Paid}) ->
    hw:display("Make Your Selection", []),
    hw:return_change(Paid),
    {next_state, selection, []};
payment(_Other, LoopData) ->
    {next_state, payment, LoopData}.


%% State: remove cup 
remove(cup_removed, LoopData) ->
    hw:display("Make Your Selection", []),
    {next_state, selection, LoopData};
remove({pay, Coin}, LoopData) ->
    hw:return_change(Coin),
    {next_state, remove, LoopData};
remove(_Other, LoopData) ->
    {next_state, remove, LoopData}.


stop() -> gen_fsm:sync_send_event(?MODULE, stop).

selection(stop, _From, LoopData) ->
    {stop, normal, ok, LoopData}.
service(stop, _From, LoopData) ->
    {stop, normal, ok, LoopData}.
payment(stop, _From, Paid) ->
    hw:return_change(Paid),
    {stop, normal, ok, 0}.
remove(stop, _From, LoopData) ->
    {stop, normal, ok, LoopData}.


terminate(_Reason, _StateName, _LoopData) ->
    ok.

code_change('1.0', payment, {_Type, _Price, Paid}, _Extra) ->
    io:format("code_change('1.0', payment, ~p, ~p).",[{_Type, _Price, Paid}, _Extra]),
    hw:return_change(Paid),
    hw:display("Make Your Selection", []),
    {ok, selection, {}};
code_change('1.0', State, LoopData, _Extra) ->
    io:format("code_change('1.0', ~p, ~p, ~p).",[State, LoopData, _Extra]),
    {ok, State, LoopData};
code_change({down, '1.0'}, service, LoopData, _Extra) ->
    io:format("code_change({down, '1.0'}, service, ~p, ~p).",[LoopData, _Extra]),
    hw:reboot(),
    hw:display("Make Your Selection", []),
    {ok, selection, LoopData};
code_change({down, '1.0'}, payment, {_Type, _Price, Paid}, _Extra) ->
    io:format("code_change({down, '1.0'}, payment, ~p, ~p).",[{_Type, _Price, Paid}, _Extra]),
    hw:return_change(Paid),
    hw:display("Make Your Selection", []),
    {ok, selection, {}};
code_change({down, '1.0'}, State, LoopData, _Extra) ->
    io:format("code_change({down, '1.0'}, ~p, ~p, ~p).",[State, LoopData, _Extra]),
    {ok, State, LoopData};
code_change(Other, State, LoopData, _Extra) ->
    io:format("Other: code_change(~p, ~p, ~p, ~p).",[Other, State, LoopData, _Extra]),
    {ok, State, LoopData}.