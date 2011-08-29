-module(run_common_test).
-export([ct/0]).

-define(CT_DIR, filename:join([".", "tests"])).
-define(CT_REPORT, filename:join([".", "ct_report"])).
-define(CT_CONFIG, filename:join([".", "test.config"])).

ct() ->
    ct:run_test([
        {config, [?CT_CONFIG]},
        {dir, ?CT_DIR},
        {logdir, ?CT_REPORT}
    ]),
    init:stop(0).
