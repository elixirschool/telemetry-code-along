# Instrumenting Elixir with Telemetry + LiveView
## Resources
https://blog.smartlogic.io/instrumenting-with-telemetry/
https://github.com/beam-telemetry/telemetry
https://hexdocs.pm/plug/Plug.Telemetry.html

## Outline
* Telemetry plug instruments request duration
* Attach request `[:my, :app, :start/:stop]` to a handler
* That handler sends messages to async reporters, this case LiveView - could also be StatsD, Prometheus, log statement, etc. This is where we talk about async processes.
* LiveView handles the event and updates something in the UI
* Add another point of instrumentation, maybe a metric for successful/failed external API requests
* Attach a handler for that event, report to LV, etc.
* Instrumenting Ecto query times?

## UI with Chartkick
https://github.com/buren/chartkick-ex
https://jacobburenstam.com/chartkick-ex/
https://github.com/buren/chartkick-phoenix-example

## Implementation Plan

* Simple Phoenix app with endpoints:
  - [X] Landing page
  - [] Simple auth flow (sign up/sign in)
    - [X] User schema and module, account context
    - [X] Log in, sign up, log out, user show
    - [ ] Set up Telemetry + handler
    - [ ] Set up LiveView to receive messages from Telemetry handler, display simple count for num logins
    * Metric increment for num logins -> chart, count
    * Metric increment success/failure for logins -> chart
    * Query duration for find and create queries -> chart
    * Telemetry plug for landing page load time (add a random sleep between 1 and 5 seconds) -> chart


# Instrumenting LiveView w Telemetry
We know how to take advantage of the telemetry plug to measure request times. But what about client/server interaction that does not occur over HTTP? As we use LV for more and more real-time features, how can we instrument WS communication duration in a sane and scalable manner?

* We have a telemetry plug to automatically get request duration but no such thing for instrumentin LV traffic
* Build something that gets LV message -> render duration
* Using telemetry to report to 3rd party or another LV with charting lib
* Use an approach like this to define a macro that will execute any telemetry calls and then execute defined function body https://carlo-colombo.github.io/2017/06/10/Track-functions-call-in-Elixir-applications-with-Google-Analytics/

Inspired by: https://github.com/elixir-plug/plug/blob/master/lib/plug/telemetry.ex#L76

```ruby
defmeasured handle_event(event, payload, socket) do
  # should do the equivalent of:
  start_time = System.monotonic_time()
  prefix     = #{String.downcase(__MODULE__}).#{event}
  opts       = [] # any tags?
  telemetry
    .execute("#{prefix}.start", %{time: start_time},%{socket: socket, options: opts})
  socket = assign(socket, %{telemetry_event_prefix: prefix})
  # execute body with new socket
end

defmeasured render(assigns) do
  # should do the equivalent of:
  duration = System.monotonic_time() - start_time
  prefix   = assigns.telemetry_event_prefix
  opts     = [] # any tags?
  :telemetry
    .execute("#{prefix}.stop", %{duration: duration}, %{conn: conn, options: opts})
  socket = assigns(socket, :telemetry_event_prefix, nil)
  # execute body with assigns
end

def execute_before_render_callbacks(assigns) do
  assigns.before_render()
  # |> invoke function body with updated assigns
end
```

* Macro needs to switch on function type -> `handle_event` or `render`. Should just call to function if any other type.
* Don't need to register per-event b/c LV process will only work on one event at a time. So we are sure that render is for the event that we just registered a process for. But we should track event name, only for reporting, otherwise how do we know which event it is that we just checked and reported duration for.
* No need to clear prefix from socket assigns before rendering b/c it will update as soon as next event is received? What about `handle_info` tho? Assume we will measure that too. Either you're using telemetry to measure duration of _all_ incoming messages or you're not. No way to enforce this tho :( Better to clear prefix though and not assume that every message is instrumented.
* Have to manually attach Telemetry event handler for each telemetry event. Either we attach once for the LV module start/stop and use tags to be more granular about event type or user is on the hook for attaching handler for each event's start/stop. I'm leaning towards option 1 but have to play around with tags more first.


## Implementation Plan

* Simple live view with three events--three buttons that you click to change color and each one has a sleep for a diff amount of time.
* Instrument duration of "request/response" for each event type, register LV telemetry handler to receive telemetry events, that handler can send to our dashboard LV. Question: Same telemetry event handler for all events or separate for LV vs. application? I.e. separation of concerns with telemetry event handling modules or just one giant one?
* prob. want to play around with metric label names and tags

## Instrumenting Phoenix with Telemetry + StatsD

### Resources

* https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html
* https://hexdocs.pm/telemetry_metrics_statsd/TelemetryMetricsStatsd.html
* https://github.com/beam-telemetry/telemetry_metrics_statsd/issues/15

### Next Steps

* Can the reporter support Dogstatsd events? Can we hack it?
- [X] Which telemetry events is Phoenix/Ecto/etc emitted for us for free?

- [X] Run statsd to view output for each of the mapped metrics
  * [Installing statsd for mac](https://anomaly.io/statsd-install-and-config/index.html)

* Verify how to report the "free" metrics you can hook into:
(remember summary == timing/duration)
  * [List all](https://til.hashrocket.com/posts/o17nfvwzbo--list-all-telemetry-event-handlers)
  * HTTP request duration by route
    * [Source](https://github.com/phoenixframework/phoenix/blob/d4596650df21e7e0603debcb5f2ad25eb9ac082d/lib/phoenix/router.ex)
  * [HTTP request count by route](https://app.datadoghq.com/dashboard/dmk-qzr-9sf/sophies-timeboard-22-mar-2020-1214?from_ts=1584882280954&fullscreen_section=overview&fullscreen_widget=4612552948460480&live=true&tile_size=m&to_ts=1584896680954&fullscreen_start_ts=1584882486335&fullscreen_end_ts=1584896886335&fullscreen_paused=false)
  * [Ecto query duration by query](https://app.datadoghq.com/metric/explorer?live=true&page=0&is_auto=false&from_ts=1584889953332&to_ts=1584893553332&tile_size=m&exp_metric=quantum.repo.query.total_time.count&exp_scope=command%3Aselect%2Csource%3Ausers&exp_agg=avg&exp_row_type=metric&fullscreen=1011)
  * [Ecto query count by query](https://app.datadoghq.com/metric/summary?filter=quantum.repo.query&metric=quantum.repo.query.count)
  * VM metrics (last_count == gauge) (need polling)
  * Live View?
    * [Channel joined](https://github.com/phoenixframework/phoenix/blob/8a4aa4eed0de69f94ab09eca157c87d9bd204168/lib/phoenix/channel/server.ex#L319)
    * [Channel handle_in](https://github.com/phoenixframework/phoenix/blob/8a4aa4eed0de69f94ab09eca157c87d9bd204168/lib/phoenix/channel/server.ex#L319)
* Reporting custom metrics to StatsD
  * Emit telemetry event and define corresponding metric in Telemetry module
  * Extending Telemetry to support Datadog events
    * Hook into Telemetry event with custom handler
* Configuring global tags and + prefixes: https://hexdocs.pm/telemetry_metrics_statsd/TelemetryMetricsStatsd.html#module-global-tags
* Benefits:
  * Abstract away common instrumentation needs and automatically send such events to your reporter of choice.
  * Can still define custom handlers for events and do more stuff with them

### Metrics Report

```bash
Flushing stats at  Sun Mar 22 2020 13:36:41 GMT-0400 (Eastern Daylight Time)
{
  counters: {
    'statsd.bad_lines_seen': 0,
    'statsd.packets_received': 11,
    'statsd.metrics_received': 40,
    'quantum.repo.query.count.users.select': 6,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.PageController.index': 0,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.UserController.show': 1,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.delete': 1,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.new': 2,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.create': 1
  },
  timers: {
    'quantum.phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.UserController.show': [],
    'quantum.phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.PageController.index': [],
    'quantum.repo.query.total_time.users.select': [ 0, 0, 0, 0, 1, 1 ],
    'quantum.repo.query.decode_time': [ 0, 0, 0, 0, 0, 0 ],
    'quantum.repo.query.query_time': [ 0, 0, 0, 0, 0, 0 ],
    'quantum.repo.query.queue_time': [ 0, 0, 0, 0, 0, 1 ],
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.UserController.show': [ 4 ],
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.PageController.index': [],
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.delete': [ 3 ],
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.new': [ 1, 8 ],
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.create': [ 245 ]
  },
  gauges: { 'statsd.timestamp_lag': 0 },
  timer_data: {
    'quantum.phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.UserController.show': { count_ps: 0, count: 0 },
    'quantum.phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.PageController.index': { count_ps: 0, count: 0 },
    'quantum.repo.query.total_time.users.select': {
      count_90: 5,
      mean_90: 0.2,
      upper_90: 1,
      sum_90: 1,
      sum_squares_90: 1,
      std: 0.4714045207910317,
      upper: 1,
      lower: 0,
      count: 6,
      count_ps: 0.6,
      sum: 2,
      sum_squares: 2,
      mean: 0.3333333333333333,
      median: 0
    },
    'quantum.repo.query.decode_time': {
      count_90: 5,
      mean_90: 0,
      upper_90: 0,
      sum_90: 0,
      sum_squares_90: 0,
      std: 0,
      upper: 0,
      lower: 0,
      count: 6,
      count_ps: 0.6,
      sum: 0,
      sum_squares: 0,
      mean: 0,
      median: 0
    },
    'quantum.repo.query.query_time': {
      count_90: 5,
      mean_90: 0,
      upper_90: 0,
      sum_90: 0,
      sum_squares_90: 0,
      std: 0,
      upper: 0,
      lower: 0,
      count: 6,
      count_ps: 0.6,
      sum: 0,
      sum_squares: 0,
      mean: 0,
      median: 0
    },
    'quantum.repo.query.queue_time': {
      count_90: 5,
      mean_90: 0,
      upper_90: 0,
      sum_90: 0,
      sum_squares_90: 0,
      std: 0.372677996249965,
      upper: 1,
      lower: 0,
      count: 6,
      count_ps: 0.6,
      sum: 1,
      sum_squares: 1,
      mean: 0.16666666666666666,
      median: 0
    },
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.UserController.show': {
      count_90: 1,
      mean_90: 4,
      upper_90: 4,
      sum_90: 4,
      sum_squares_90: 16,
      std: 0,
      upper: 4,
      lower: 4,
      count: 1,
      count_ps: 0.1,
      sum: 4,
      sum_squares: 16,
      mean: 4,
      median: 4
    },
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.PageController.index': { count_ps: 0, count: 0 },
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.delete': {
      count_90: 1,
      mean_90: 3,
      upper_90: 3,
      sum_90: 3,
      sum_squares_90: 9,
      std: 0,
      upper: 3,
      lower: 3,
      count: 1,
      count_ps: 0.1,
      sum: 3,
      sum_squares: 9,
      mean: 3,
      median: 3
    },
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.new': {
      count_90: 2,
      mean_90: 4.5,
      upper_90: 8,
      sum_90: 9,
      sum_squares_90: 65,
      std: 3.5,
      upper: 8,
      lower: 1,
      count: 2,
      count_ps: 0.2,
      sum: 9,
      sum_squares: 65,
      mean: 4.5,
      median: 4.5
    },
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.create': {
      count_90: 1,
      mean_90: 245,
      upper_90: 245,
      sum_90: 245,
      sum_squares_90: 60025,
      std: 0,
      upper: 245,
      lower: 245,
      count: 1,
      count_ps: 0.1,
      sum: 245,
      sum_squares: 60025,
      mean: 245,
      median: 245
    }
  },
  counter_rates: {
    'statsd.bad_lines_seen': 0,
    'statsd.packets_received': 1.1,
    'statsd.metrics_received': 4,
    'quantum.repo.query.count.users.select': 0.6,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.PageController.index': 0,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.UserController.show': 0.1,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.delete': 0.1,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.new': 0.2,
    'phoenix.router_dispatch.stop.duration.Elixir.QuantumWeb.SessionController.create': 0.1
  },
  sets: {},
  pctThreshold: [ 90 ]
}
```

## TODO

* Success/failure web request response instrumentation
* LiveView metrics with channel joined and channel handled_in
* VM metrics with polling
* Visualize DD reporting by using DD formatter but running regular statsd, grab log statement from error message

## Notes
* We're instrumenting for free:
  * Database query duration and counts
  * HTTP request duration and counts

## Blog Post
* What is observability? What is instrumentation?
* Common needs: web requests, database queries
* OOTB instrumentation with Elixir Telemetry
  * We'll get web requests, database queries, VM monitoring
  * Implementation
    * Use Telemetry package
    * Establish module that defines which events you are listening to--this attaches them to the default handler.
      * Look at source code in Phoenix that emits those telemetry events.
      * Tagging - slice up HTTP requests by contoller + action; DB queries by source and command. Tags become part of metric name in standard statsd formatting. Custom tag values functions
      * Note on Datadog formatter
        * Tags translate into metric tags (show the mapping)
        * Can leverage prefix, global tags, HTTP route tag now more usefully
* Custom instrumentation
  * Define telemetry handler
  * Attach in telemetry module (?)
  * Good candidate--custom interaction error count - log in failure/success?
* Instrumentating LiveView with Phoenix's OOTB Telemetry events
* Telemetry under the hood - trace the flow of PHoenix/Ecto/app code emitting event and telemtry looking up event handle and calling it. Look at tags, etc.

### Questions
* How to instrument success/failure of web requests?
* Is this a good use case for Telemetry plug or does we get it OOTB?
  * Maybe use render errors event? https://github.com/phoenixframework/phoenix/blob/00a022fbbf25a9d0845329161b1bc1a192c2d407/lib/phoenix/endpoint/render_errors.ex

### Ecto Telemetry Event Source Code
* https://github.com/elixir-ecto/ecto/blob/2aca7b28eef486188be66592055c7336a80befe9/lib/ecto/repo.ex#L95