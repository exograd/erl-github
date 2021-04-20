-module(github_events).

-export([list_public_events/1, list_repository_events/3,
         validate/1, generate/1]).

-export_type([actor/0, event/0, event/1, repo/0]).

-type actor() ::
        #{id := integer(),
          login := binary(),
          display_login => binary(),
          gravatar_id => binary(),
          url := binary(),
          avatar_url := binary()}.

-type event() :: event(map()).

-type event(Payload) ::
        #{id := binary(),
          type := binary(),
          actor := actor(),
          repo := repo(),
          org => actor(),
          payload := Payload,
          public := boolean(),
          created_at => calendar:datetime()}.

-type repo() ::
        #{id := integer(),
          name := string(),
          url := string()}.

-type event_response() ::
        #{events := [event()],
          poll_interval := non_neg_integer(), % seconds
          etag := binary()}.

-type event_options() ::
        #{per_page => pos_integer(),
          if_none_match => binary()}.

-spec list_public_events(event_options()) -> github:result(event_response()).
list_public_events(Options) ->
  PerPage = maps:get(per_page, Options, 10),
  Target = #{path => <<"/events">>,
             query => [{<<"per_page">>, integer_to_binary(PerPage)}]},
  RequestOptions =
    maps:merge(maps:with([if_none_match], Options),
               #{response_body => {jsv, {ref, github, events}}}),
  github_http:send_request(get, Target, RequestOptions).

-spec list_repository_events(Owner :: binary(), Name :: binary(),
                             event_options()) ->
        github:result(event_response()).
list_repository_events(Owner, Name, Options) ->
  PerPage = maps:get(per_page, Options, 10),
  Path =
    ["/repos/", uri:encode_path(Owner), $/, uri:encode_path(Name), "/events"],
  Target = #{path => iolist_to_binary(Path),
             query => [{<<"per_page">>, integer_to_binary(PerPage)}]},
  RequestOptions =
    maps:merge(maps:with([if_none_match], Options),
               #{response_body => {jsv, {ref, github, events}}}),
  github_http:send_request(get, Target, RequestOptions).

-spec validate(map()) -> jsv:validation_result(event()).
validate(Event = #{type := Type, payload := Payload}) ->
  case payload_definition(Type) of
    {ok, Definition} ->
      Options = #{unknown_member_handling => keep,
                  null_member_handling => remove},
      case jsv:validate(Payload, Definition, Options) of
        {ok, Payload2} ->
          {ok, Event#{payload => Payload2}};
        {error, Errors} ->
          {error, {invalid_child, [<<"payload">>], Errors}}
      end;
    error ->
      {error, {invalid_value, Type, [<<"type">>],
               unknown_event_type,
               <<"unknown event type ", Type/binary>>}}
  end.

-spec generate(event()) ->
        {ok, term()} | {error, jsv:generation_error_reason()}.
generate(Event = #{type := Type, payload := Payload}) ->
  case payload_definition(Type) of
    {ok, Definition} ->
      case jsv:generate(Payload, Definition) of
        {ok, Value} ->
          {ok, Event#{payload => Value}};
        {error, Reason} ->
          {error, Reason}
      end;
    error ->
      {error, {invalid_event_type, Type}}
  end.

-spec payload_definition(Type :: binary()) -> {ok, jsv:definition()} | error.
payload_definition(<<"CommitCommentEvent">>) ->
  {ok, {ref, github, event_payload_commit_comment}};
payload_definition(<<"CreateEvent">>) ->
  {ok, {ref, github, event_payload_create}};
payload_definition(<<"DeleteEvent">>) ->
  {ok, {ref, github, event_payload_delete}};
payload_definition(<<"ForkEvent">>) ->
  {ok, {ref, github, event_payload_fork}};
payload_definition(<<"GollumEvent">>) ->
  {ok, {ref, github, event_payload_gollum}};
payload_definition(<<"IssueCommentEvent">>) ->
  {ok, {ref, github, event_payload_issue_comment}};
payload_definition(<<"IssuesEvent">>) ->
  {ok, {ref, github, event_payload_issues}};
payload_definition(<<"MemberEvent">>) ->
  {ok, {ref, github, event_payload_member}};
payload_definition(<<"PublicEvent">>) ->
  {ok, {ref, github, event_payload_public}};
payload_definition(<<"PullRequestEvent">>) ->
  {ok, {ref, github, event_payload_pull_request}};
payload_definition(<<"PullRequestReviewEvent">>) ->
  {ok, {ref, github, event_payload_pull_request_review}};
payload_definition(<<"PullRequestReviewCommentEvent">>) ->
  {ok, {ref, github, event_payload_pull_request_review_comment}};
payload_definition(<<"PushEvent">>) ->
  {ok, {ref, github, event_payload_push}};
payload_definition(<<"ReleaseEvent">>) ->
  {ok, {ref, github, event_payload_release}};
payload_definition(<<"SponsorshipEvent">>) ->
  {ok, {ref, github, event_payload_sponsorship}};
payload_definition(<<"WatchEvent">>) ->
  {ok, {ref, github, event_payload_watch}};
payload_definition(_) ->
  error.
