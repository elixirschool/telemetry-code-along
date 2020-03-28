# Instrumenting Phoenix with Telemetry Part II: Telemetry Metrics + Reporters

In part I of this series, we learned why observability is important and introduced Erlang's Telemetry library. We used it to hand-roll some instrumentation for our Phoenix app, but it left us with some additional problems to solve. In this post, we'll use Elixir's `Telemetry.Metrics` and Telemetry reporting libraries define and send metrics to StatsD for a given set of out-of-the-box Telemetry events.

## Recap

In our previous post, we added some Telemetry instrumentation to our Phoenix app, Quantum. To recap, we established a Telemetry event, `[:phoenix, :request]`, that we attached to a handler module, `Quantum.Telemetry.Metrics`. We executed this event fromhe  just one controller action--the `new` action of the `UserController`.

From that controller action, we execute the Telemetry event with a measurement map that includes the duration of the web request, along with the request `conn`:

```elixir
# lib/quantum_web/controllers/user_controller.ex
def new(conn, _params) do
  start = System.monotonic_time()
  changeset = Accounts.change_user(%User{})
  :telemetry.execute([:phoenix, :request], %{duration: System.monotonic_time() - start}, conn)
  render(conn, "new.html", changeset: changeset)
end
```

We handle this event in `Quantum.Telemetry.Metrics.handle_event/4` by using the event data, including the duration and information in the `conn` to send a set of metrics to StatsD with help of the `Statix` Elixir StatsD client library.

## What's Wrong With This?

Telemetry made it easy for us to emit an event and operate on it, but our current usage of the Telemetry library leaves a lot to be desired.

One drawback of our current approach is that it leaves us on the hook for Telemetry event handling and metrics reporting. We had to define our own custom event handling module, manually attach that module to the given Telemetry event and define the handler's callback function.

In order for that callback function report metrics to StatsD for a given event, we had to create our own custom module that uses the `Statix` library _and_ write code that formats the metric to send to StatsD for a given Telemetry event. The mental overhead of translating Telemetry event data into the appropriate StatsD metric is costly, and that effort will have to be undertaken for every new Telemetry event we execute and handle.

## We Need Help

Wouldn't it be great if we _didn't_ have to define our own handler modules or metric reporting logic? If only there was some way to simply list the Telemetry events we care about and have them automatically reported to StatsD as the correctly formatted metric...

This is exactly where the `Telemetry.Metrics` and Telemetry reporting libraries come in!

## Introducing `Telemetry.Metrics` and Telemetry Reporters

The `Telemetry.Metrics` library allows us declare the set of Telemetry events that we want to handle and specify an out-of-the-box reporter with which to handle them. This means we _don't_ have to define our own handler modules and functions and we _don't_ have to write any code responsible for reporting metrics for events to common third-party tools StatsD.

In the previous post, we added code to execute the following Telemetry event from the `new` action of our `UserController`:

```elixir
:telemetry.execute([:phoenix, :request], %{duration: System.monotonic_time() - start}, conn)
```

Now, instead of handling this event with our custom handler and `Statix` reporter, will use `Telemetry.Metrics` and the `TelemetryMetricsStatsd` reporter to do all of the work for us!

## Getting Started

In the rest of this post, we'll cover how to use the `Telemetry.Metrics`  and `TelemetryMetricsStatsd` libraries to handle our event.

As we set up our Telemetry pipeline with these tools, we'll take peeks under the hood of source code to understand _how_ these libraries work together with Erlang's Telemetry library to attach and execute events.

To follow along with this tutorial, you can clone down the example app [here]().

## How It Works

Before we start writing code, let's walk through how `Telemetry.Metrics` and the `TelemetryMetricsStatsd` reporter work together with Erlang's Telemetry library to handle Telemetry events.

The `Telemetry.Metrics` library is responsible for specifying which Telemetry events we want to handle as metrics. It defines the list of events we care about and specifies which events should be sent to StatsD as which type of metric (for example, counter, timing, distrubtion etc.). It gives this list of events-as-metrics to the Telemetry reporting client, `TelemetryMetricsStatsd`.

The `TelemetryMetricsStatsd` library is responsible for taking that list of events and attaching its own event handler module, `TelemetryMetricsStatsd.EventHandler` to each event via a call to `:telemetry.attach/4`. Recall from our first post that `:telemetry/attach/4` stores events and their associated handlers in an ETS table.

Later, when a Telemetry event is dispatched via a call to `:telemetry.execute/3`, Telemetry looks up the event handler, `TelemetryMetricsStatsd.EventHandler`, for the given event in the ETS table and invokes it. The event handler module will format the event, metadata and any associated tags as the appropriate StatsD metric and send the resulting metric to StatsD over UDP.

Most of this happens under the hood. We are only on the hook for defining a `Telemetry.Metrics` module and listing the Telemetry events we want to handle as which type of metric. That's it!

## Setting Up `Telemetry.Metrics`

First, we'll add the `Telemetry.Metrics` library and the `TelemetryMetricsStatsd` reporter library to our application's dependencies and run `mix deps.get`:

```elixir
# mix.exs
defp deps do
  [
    {:telemetry_metrics, "~> 0.4"},
    {:telemetry_metrics_statsd, "~> 0.3.0"}
  ]
end
```

Now we're ready to define a module that imports this library.

## Defining a Metrics Module

We'll define a module that imports the `Telemetry.Metrics` library and acts as a supervisor. Our supervisor will start up the child GenServer provided by the `TelemetryMetricsStatsd` reporter. It will start that GenServer along with an argument of the list of Telemetry events to listen for, via the `:metrics` option.

We'll place our metrics module in `lib/quantum/telemetry.ex`

```elixir
defmodule Quantum.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {TelemetryMetricsStatsd, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp metrics do
    # coming soon!
  end
end
```

We'll come back to the metrics list in a bit. First, let's teach our application to start this supervisor when the app starts up but adding it to our application's supervision tree in the `Quantum.Application.start/2` function:

```elixir
# lib/quantum/application.ex
def start(_type, _args) do
  children = [
    Quantum.Repo,
    QuantumWeb.Endpoint,
    Quantum.Telemetry
  ]

  opts = [strategy: :one_for_one, name: Quantum.Supervisor]
  Supervisor.start_link(children, opts)
end
```

Now we're ready to specify which Telemetry metrics to handle.

## Handling Telemetry Events

Our `Telemetry.Metrics` module, `Quantum.Telemetry`, is responsible for:

* Starting the `TelemetryMetricsStatsd` GenServer
* Telling `TelemetryMetricsStatsd` which Telemetry events to respond to and how to treat each event as a specific type of metric

We want to handle the `[:phoenix, :request]` event described above. First, let's consider what type of metrics we want to report for this event. Let's say we want to increment a counter for each such event, thereby keeping track of the number of requests our app receives to the endpoint. Let's also send a timing metric to report the duration of a given web request.

Now that we have a basic idea of what kind of metrics we want to construct and send to StatsD for our event, let's take a look at how `Telemetry.Metrics` allows us to define these metrics.

### Specifying Events As Metrics

The `Telemetry.Metrics` module provides a set of [five metrics functions](https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html#module-metrics). These functions are responsible for formatting Telemetry event data as a given metric.

<!-- Let's say that we want to send two metrics to StatsD any time a `[:phoenix, :router_dispatch, :stop]` Telemetry event is executed:

* Count of such events, tagged with the endpoint
* Duration of such an event, i.e. web request duration, tagged with the endpoint -->

We'll use the `Telemetry.Metrics.counter/2` and the `Telemetry.Metrics.summary/2` functions to define our metrics for the given event.

In our `Quantum.Telemetry` module, which imports `Telemetry.Metrics`, we'll add the following to the `metrics` function:

```elixir
# lib/quantum/telemetry.ex
defp metrics do
  [
    summary(
      "phoenix.request.duration",
      unit: {:native, :millisecond},
      tags: [:plug, :plug_opts]
    ),

    counter(
      "phoenix.request.count",
      tags: [:plug, :plug_opts]
    )
  ]
end
```

Each metric function returns a struct that contains the data and logic for the given metric type. This list of structs is what get's passed to the `TelemetryMetricsStatsd` GenServer when it gets started up:

```elixir
defmodule Quantum.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {TelemetryMetricsStatsd, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp metrics do
    [
      summary(
        "phoenix.request.duration",
        unit: {:native, :millisecond},
        tags: [:plug, :plug_opts]
      ),

      counter(
        "phoenix.request.count",
        tags: [:plug, :plug_opts]
      )
    ]
  end
end
```

Each metric function takes in two arguments:

* The event name
* A list of options

Here, we're using the `:tag` option key to specify which tags will be applied to the metric when it gets sent to StatsD. The `TelemetryMetricsStatsD` reporter will, when it receives a given Telemetry event, grab any values for the tag keys present in the event metadata and use them to construct the metric.

So, when we execute our Telemetry with the `conn` passed in as the metadata argument:

```elixir
:telemetry.execute([:phoenix, :request], %{duration: System.monotonic_time() - start}, conn)
```

The `TelemetryMetricsStatsD` will format a counter and summary metric tagged with the values of the `:plug` and `:plug_opts` keys found in the `conn` argument.

Now, if we run our app and send some web requests, we'll see the following metrics reported to StatsD:

```
{
  counters: {
    'phoenix.request.count.Elixir.QuantumWeb.UserController.new': 2,
  },
  timers: {
    'phoenix.request.count.Elixir.QuantumWeb.UserController.new': [ 0, 0 ],
  },
  timer_data: {
    'phoenix.request.duration.Elixir.QuantumWeb.UserController.new': {
      count_90: 2,
      mean_90: 0,
      upper_90: 0,
      sum_90: 0,
      sum_squares_90: 0,
      std: 0,
      upper: 0,
      lower: 0,
      count: 2,
      count_ps: 0.2,
      sum: 0,
      sum_squares: 0,
      mean: 0,
      median: 0
    }
  }
}
```

Note that the `TelemetryMetricsStatsd` reporter took the tags and appended them to the metric name. Where it received an event `"phoenix.request"`, it looked up the values of the `:plug` and `:plug_opts` keys in the event metadata and appended those values to the metric name.

## Putting It All Together

The `Quantum.Telemetry` module is, believe it or not, the _only_ code we have to write in order to send these metrics to StatsD for the `"phoenix.router_dispatch.stop"` event. The Telemetry libraries take care of everything else for us under the hood.

Let's take a closer look at how it all works.

1. The `Telemetry.Metrics` supervisor that we defined in `Quantum.Telemetry` defines a list of metrics that we want to emit to StatsD for a given Telemetry event.
2. When the supervisor starts, it starts the `TelemetryMetricsStatsd` GenServer and gives it this list
3. When the `TelemetryMetricsStatsd` GenServer starts, it calls `:telemetry.attach/4` for each listed event, storing it in an ETS table along with the metric definition and handler module. The handler module it gives to `:telemetry.attach/4` is its own `TelemetryMetricsStatsd.EventHandler` module.
4. Later, when a Telemetry event is executed via a call to `:telemetry.execute/3`, Telemetry looks up the handler module and metric definition for the given event in ETS and calls the `handle_event/4` callback function on the handler module, `TelemetryMetricsStatsd.EventHandler`.
5. `TelemetryMetricsStatsd.EventHandler.handle_event/4` is called with the event name, measurement map, metadata and metric info that `:telemetry.execute/3` passes to it. It then formats the appropriate metric using all of this information and sends it to StatsD over UDP

Phew!

Let's take a deper dive into this process by taking a look at some source code.

When our supervisor starts the `TelemetryMetricsStatsd` GenServer, the GenServer's `init/1` function calls on `TelemetryMetricsStatsd.EventHandler.attach/7` with an argument of the metrics list:

```elixir
def attach(metrics, reporter, mtu, prefix, formatter, global_tags) do
  metrics_by_event = Enum.group_by(metrics, & &1.event_name)

  for {event_name, metrics} <- metrics_by_event do
    handler_id = handler_id(event_name, reporter)

    :ok =
      :telemetry.attach(handler_id, event_name, &__MODULE__.handle_event/4, %{
        reporter: reporter,
        metrics: metrics,
        mtu: mtu,
        prefix: prefix,
        formatter: formatter,
        global_tags: global_tags
      })
  end
end
```

The call to `:telemetry.attach/4` will create an ETS entry that stores the event name along with the handler module's callback function,`&TelemetryMetricsStatsd.EventHandler.handle_event/4`, and a config map that contains the metrics definitions for the event.

Later, the `[:phoenix, :request]` event is executed in our `UserController`:

```elixir
:telemetry.execute([:phoenix, :request], %{duration: System.monotonic_time() - start}, conn)
```

At this time, Erlang's Telemetry module will look up the event in ETS. It will fetch the handler callback function, along with the config that was stored for that event, including the list of metric definitions.

Telemetry will then call the callback function, `TelemetryMetricsStatsd.EventHandler.handle_event/4`, with the event measurement map, metadata and stored config.

`TelemetryMetricsStatsd.EventHandler.handle_event/4` will format the metric according to the metrics definitions stored in ETS for the event and send the resulting metric to StatsD.

Here we can see that the `TelemetryMetricsStatsd.EventHandler.handle_event/4` iterates over the metric definitions for the event, fetched from ETS and constructs the appropriate metric from the given event data including the measurement map, metadata map and tagging rules. It then publishes the metric to StatsD over UDP via the call to `publish_metrics/2`

```elixir
def handle_event(_event, measurements, metadata, %{
      reporter: reporter,
      metrics: metrics,
      mtu: mtu,
      prefix: prefix,
      formatter: formatter_mod,
      global_tags: global_tags
    }) do
  packets =
    # iterate over the stored metric definitions
    for metric <- metrics do
      case fetch_measurement(metric, measurements) do
        {:ok, value} ->
          # format the metric according to the specific tag
          tag_values =
            global_tags
            |> Map.new()
            |> Map.merge(metric.tag_values.(metadata))
          tags = Enum.map(metric.tags, &{&1, Map.fetch!(tag_values, &1)})
          Formatter.format(formatter_mod, metric, prefix, value, tags)

        :error ->
          :nopublish
      end
    end
    |> Enum.filter(fn l -> l != :nopublish end)

  case packets do
    [] ->
      :ok

    packets ->
      # publish metrics to StatsD
      publish_metrics(reporter, Packet.build_packets(packets, mtu, "\n"))
  end
end
```

## Wrapping Up

The `Telemetry.Metrics` and `TelemetryMetricsStatsd` libraries make it even easier for us to handle Telemetry events and report metrics based on those events. All we have to do is define a Supervisor that uses `Telemetry.Metrics` and tell that Supervisor to start the `TelemetryMetricsStatsd` GenServer with a list of metrics.

That's it! The `TelemetryMetricsStatsd` library will take care of calling `:telemetry.attach/3` to store events in ETS along with a handler callback function, `TelemetryMetricsStatsd.EventHandler.handle_event/4`, and the metrics list. Later, when a Telemetry event is executed, Telemetry will lookup the event and its associated handler callback function and metrics list and invoke the the callback function with this data. The callback function, `TelemetryMetricsStatsd.EventHandler.handle_event/4`, will iterate over the list of metrics and construct the appropriate metric given the metric type and tags and the event measurement and metadata. All for free!


## Next Steps

In this post, we saw how the `Telemetry.Metrics` and `TelemetryMetricsStatsd` abstracted away the need to define custom handlers and callback functions, attach those handlers to events and implement our own metric reporting logic. But our Telemetry pipeline still needs a little work.

We're still on the hook for emitting all of our own Telemetry events.

In order to really be able to observe the state of our production Phoenix app, we need to be reporting on much more than just one endpoint's request duration and count. We want to be able to handle information-rich events describing web requests across the app, database queries, the behavior and state of the Erlang VM, the behavior and state of any workers in our app, and more.

Instrumenting all of that by hand, by executing custom Telemetry events wherever we need them and defining custom handler, will be tedious and time-consuming. On top of that, it will be a challenge to standardize event naming conventions and payloads across the app.

In the next post, we'll examine Phoenix and Ecto's out-of-the-box Telemetry events and use `Telemetry.Metrics` to observe a wide-range of such events.
