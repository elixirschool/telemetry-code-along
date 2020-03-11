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
    - [ ] Set up Telemetry module
    * Metric increment for num logins
    * Metric increment success/failure for logins
    * Query duration for find and create queries
    * Telemetry plug for landing page load time (add a random sleep between 1 and 5 seconds)


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
