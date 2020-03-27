# Instrumenting Phoenix with Telemetry + StatsD Part 1: Telemetry Under The Hood

In this series, we'll be instrumenting a Phoenix app and sending metrics to StatsD with the help of Elixir and Erlang's Telemetry offerings

First, we'll discuss why observability matters and how Telemetry helps us treat observability like a first class citizen in Elixir projects. Then, we'll hand-roll our own instrumentation pipeline using Telemetry and StatsD. We'll wrap up with a look under the hood of the Telemetry library and set ourselves for Part 2 of this series, in which we leverage the Telemetry.Metrics library for even easier instrumentation and reporting.

## Observability Matters

In the immortal words of [Charity Majors](https://charity.wtf/), observability means:

> can you understand what is happening inside the system — can you understand ANY internal state the system may get itself into, simply by asking questions from the outside?

Anyone who has spent hours (days?) debugging a production issue that they can't replicate locally, relying mostly on guesswork and institutional knowledge knows what it costs to lack this ability. The hours we spend each week debugging, hampered by poor visibility into the state of complex production systems, are hours we're _not_ spending adding value to our business, shipping shiny new code that solves interesting problems for our users, or playing with our adorable dogs (okay that last one might be just me?).

Why is this? Many of us have come to treat this like the natural state of things, have come to accept this frustration as part of the job of being a software engineer. We treat observability like something this is out of our hands, or an afterthought--a "nice to have" after the main target of building that new feature or shipping the MVP are hit.

The traditional split between "web developers" and "dev-ops engineers" has lulled us into believing that observability is not the responsibility of the web dev. In the past, it may have been the case that ensuring system observability required a specialized set of skills.

This is increasingly not true of the world we live in. With third-party tools like Datadog, Splunk and Honeycomb, and libraries like Telemetry, web developers are empowered to treat observability like the first class citizen it is. To paraphrase Charity Majors (again), we can instrument our code, watch it deploy, and ask and answer the question: "is it doing what I expect?". In this way, we can build systems that are "both understandable and well understood".

## Telemetry Gives Us Visibility

[Telemetry](https://www.erlang-solutions.com/blog/introducing-telemetry.html) is an open source suite of libraries which aims to to unify and standardize how the libraries and applications on the BEAM are instrumented and monitored. How does it work?

> At the core of Telemetry lies the event. The event indicates that something has happened: an HTTP request was accepted, a database query returned a result, or the user has signed in. Each event can have many handlers attached to it, each performing a specific action when the event is published. For example, an event handler might update a metric, log some data, or enrich a context of distributed trace.

Telemetry is already included in both Ecto and Phoenix, emitting events that we can opt-in to receiving and acting on accordingly. We can also emit our own custom Telemetry events from our application code and define handlers to respond to them.

The Telemetry events emitted for free from Ecto and Phoenix mean standardized instrumentation for _all_ apps using these libraries. At the same time, the interface that Telemetry provides for handling such events and emitting additional custom events empowers every Elixir developer to foreground observability by writing and shipping fully instrumented code with ease.

Now that we understand why observability matters and how Telemetry supports observability, let's dive into the Telemetry library!

## Using Telemetry in Elixir

First, we'll take a look at how to set up a simple reporting pipeline for custom Telemetry events in our Phoenix app. Then, we'll take a look under the hood at the Telemetry library to understand how our pipeline works.

### Getting Started

You can follow along with this tutorial by cloning down the repo [here](https://github.com/SophieDeBenedetto/quantum/tree/part-1-start). Our Phoenix app, Quantum (get it?), is pretty simple--users can sign up, log in and click some buttons. Awesome, right? Really this dummy app just exists to be instrumented so it doesn't do much, sorry.

### What We're Instrumenting

We'll start by picking a workflow to instrument. In order for us to truly have observability, we need _more_ that visibility into predefined metrics. Metrics are useful for creating static dashboards, monitoring trends over time and establishing alerting thresholds against those trends. Metrics are necessary for us to monitor our system, but since they are pre-aggregated and pre-defined, they _don't_ achieve true observability. For true observability, we need to be able to ask and answer _any_ question of our running system. So, we want to track and emit events with rich context. Instead of establishing a metric for a specific web request and tracking its count and duration, for example, we want to be able to emit information describing _any_ web request and include rich descriptors of the context of that request--its duration, the endpoint to which it was sent, etc.

Although we want to emit an event for every web request, we'll start by picking just one endpoint to instrument. We'll emit a Telemetry event for the `/signup` action.

### The Telemetry Event

First, we'll install Telemetry and run `mix deps.get`:

```elixir
# add the following to the `deps` function of your mix.exs file
{:telemetry, "~> 0.4.1"}
```

Now we're ready to emit an event!

To emit a Telemetry event, we call [`:telemetry.execute`](https://hexdocs.pm/telemetry/index.html#execute). Yep, that's right, we call on the Erlang `:telemetry` module directly from our Elixir code. Elixir/Erlang inter-op FTW.

The `execute/3` function takes in three arguments--the name of the event, the measurements we're using to describe that event and any metadata that describes the event context.

We'll emit the following event from the `new` function of our `UserController`.

Our event:

```elixir
defmodule QuantumWeb.UserController do
  use QuantumWeb, :controller

  alias Quantum.Accounts
  alias Quantum.Accounts.User

  def new(conn, _params) do
    start = System.monotonic_time()
    changeset = Accounts.change_user(%User{})

    :telemetry.execute([:phoenix, :request], %{duration: System.monotonic_time() - start}, conn)

    render(conn, "new.html", changeset: changeset)
  end
end
```

Here, we're emitting an event that includes the duration measurement, tracking the duration of the web request, along with the context of the web request, described by the `conn` struct.


### Defining and Attaching The Telemetry Handler

We need to define a handler that implements a `handle_event/4` callback. Our `handle_event/4` function will match the specific event we're emitting using [function arity pattern matching](https://medium.com/flatiron-labs/how-functions-pattern-match-in-elixir-12a44a51c6ad).

Let's define a module, `Quantum.Telemetry.Metrics`, that implements this function:

```elixir
# lib/quantum/telemetry/metrics.ex
defmodule Quantum.Telemetry.Metrics do
  require Logger
  alias Quantum.Telemetry.StatsdReporter

  def handle_event([:phoenix, :request], %{duration: dur}, metadata, _config) do
    # do some stuff!
  end
end
```

In order for this module's `handle_event/4` function to be called when our `[:phoenix, :request]` event is emitted, we need to "attach" the handler to the event.

We do that with the help of Telemetry's [`attach/4`](https://hexdocs.pm/telemetry/index.html#attach) function.

The `attach/4` function takes in four arguments:

* A unique "handler ID" that will be used to look up the handler for the event later
* The event name
* The handler module and callback function
* Any handler config (which we don't need to take advantage of for the purposes of our example)

We'll call this function in our application's `start/2` function:

```elixir
# lib/quantum/application.ex

def start(_, _) do
  :ok = :telemetry.attach(
  # unique handler id
  "quantum-telemetry-metrics",
  [:phoenix, :request],
  &Quantum.Telemetry.Metrics.handle_event/4,
  nil
  )
  ...
end
```
Now that we've defined and emitted our event, and attached a handler to that event, let's take a look under the hood of the Telemetry library to understand how emitting our event results in the invocation of our handler.

### Telemetry Under The Hood

#### Attaching Handlers to Events

The `attach/4` function stores the handler and its associated events in an ETS table, under the unique handler ID we provide.

If we peek at the `attach/4` source code, we can see the call to insert into ETS [here](https://github.com/beam-telemetry/telemetry/blob/master/src/telemetry.erl#L89)

```erlang
# telemetry/src/telemetry.erl
telemetry_handler_table:insert(HandlerId, EventNames, Function, Config).
```

Looking at the [`telemetry_handler_table` source code](https://github.com/beam-telemetry/telemetry/blob/master/src/telemetry_handler_table.erl#L65), we can see that the handler is stored in the ETS table like this:

```erlang
# telemetry/src/telemetry_handler_table.erl

Objects = [#handler{id=HandlerId,
            event_name=EventName,
            function=Function,
            config=Config} || EventName <- EventNames],
            ets:insert(?MODULE, Objects)
```

So, each handler is stored in ETS with the format:

```erlang
{
  id=HandlerId,
  event_name=EventName,
  function=HandlerFunction,
  config=Config
}
```

Where the `HandlerId` `EventName`, `HandlerFunction` and `Config` are set to whatever we passed into our call to `:telemetry/attach/4`.

#### Executing Events

When we call `execute/3`, Telemetry will look up the handler  by the event name and invoke its callback function. Let's take a look at the source code for `execute/3` [here](https://github.com/beam-telemetry/telemetry/blob/master/src/telemetry.erl#L108):

```erlang
# telemetry/src/telemetry.erl

-spec execute(EventName, Measurements, Metadata) -> ok when
     EventName :: event_name(),
     Measurements :: event_measurements() | event_value(),
     Metadata :: event_metadata().
execute(EventName, Value, Metadata) when is_number(Value) ->
   ?LOG_WARNING("Using execute/3 with a single event value is deprecated. "
                "Use a measurement map instead.", []),
   execute(EventName, #{value => Value}, Metadata);
execute(EventName, Measurements, Metadata) when is_map(Measurements) and is_map(Metadata) ->
   Handlers = telemetry_handler_table:list_for_event(EventName),
   ApplyFun =
       fun(#handler{id=HandlerId,
                    function=HandlerFunction,
                    config=Config}) ->
           try
               HandlerFunction(EventName, Measurements, Metadata, Config)
           catch
               ?WITH_STACKTRACE(Class, Reason, Stacktrace)
                   detach(HandlerId),
                   ?LOG_ERROR("Handler ~p has failed and has been detached. "
                              "Class=~p~nReason=~p~nStacktrace=~p~n",
                              [HandlerId, Class, Reason, Stacktrace])
           end
       end,
   lists:foreach(ApplyFun, Handlers).
```

Let's break down this process:

* First, look up the handlers for the event in ETS:

```erlang
# telemetry/src/telemetry.erl

Handlers = telemetry_handler_table:list_for_event(EventName)
```

Looking at the [`telemetry_handler_table` source code](https://github.com/beam-telemetry/telemetry/blob/master/src/telemetry_handler_table.erl#L45), we can see that the handler is looked up in ETS by the given event name like this:

```erlang
# telemetry/src/telemetry_handler_table.erl

ets:lookup(?MODULE, EventName)
```

This will return the list of stored handlers for the event, where each handler will know its handle ID, handle function and any config:

```erlang
{
  id=HandlerId,
  function=HandlerFunction,
  config=Config
}
```

* Then, establish an `ApplyFun` to be called for each handler. The `ApplyFun` will invoke the given handler's `HandleFunction` with the event, measurements, metadata and config passed in via the call to `:telemetry.execute/4`

```erlang
# telemetry/src/telemetry.erl

ApplyFun =
  fun(#handler{id=HandlerId,
               function=HandlerFunction,
               config=Config}) ->
      try
          HandlerFunction(EventName, Measurements, Metadata, Config)
      catch
          ?WITH_STACKTRACE(Class, Reason, Stacktrace)
              detach(HandlerId),
              ?LOG_ERROR("Handler ~p has failed and has been detached. "
                         "Class=~p~nReason=~p~nStacktrace=~p~n",
                         [HandlerId, Class, Reason, Stacktrace])
      end
  end
```

* Lastly, terate over the `Handlers` and invoke the `ApplyFun` for each handler:

```elixir
lists:foreach(ApplyFun, Handlers).
```

And that's it! To summarize, when we "attach" an event to a handler, we are storing the handler and its callback function in ETS under that event name. Later, when an event is "executed", Telemetry looks up the handler for the event and execute the callback function. Pretty simple.

Now that we understand how our Telemetry pipeline works, we're ready to consider the last piece of the puzzle: event reporting.

### Reporting Events to StatsD

What you do with your event is up to you, but one common strategy is to report metrics to StatsD. In this example, we'll use the [`Statix`](https://github.com/lexmag/statix) to report metrics describing our event to StatsD.

First, we'll install Statix and run `mix deps.get`

```elixir
# add the following to the `deps` function of your mix.exs file
{:statix, ">= 0.0.0"}
```

Next up, we define a module that uses `Statix`:

```elixir
# lib/quantum/telemetry/statsd_reporter.ex
defmodule Quantum.Telemetry.StatsdReporter do
  use Statix
end
```

Now we can call on our `Quantum.Telemetry.StatsdReporter` in our event handler to emit metrics to StatsD:

```elixir
# lib/quantum/telemetry/metrics.ex
defmodule Quantum.Telemetry.Metrics do
  require Logger
  alias Quantum.Telemetry.StatsdReporter

  def handle_event([:phoenix, :request], %{duration: dur}, metadata, _config) do
    StatsdReporter.increment("phoenix.request.success", 1)
    StatsdReporter.timing("phoenix.request.success", dur)
  end
end
```

Here, we're reporting a counter metric that tracks the number of such request events, as well as a timing metric that tracks the duration of web requests.

Now, if we run our app and visit the `/signup` route a few times, we should see the following emitted to StatsD:

```
{
  counters: {
    'quantum.phoenix.request': 7
  },
  timers: {
    'quantum.phoenix.request': [
      18000, 18000,
      19000, 19000,
      20000, 22000,
      24000
    ]
  },
  timer_data: {
    'quantum.phoenix.request': {
      count_90: 6,
      mean_90: 19333.333333333332,
      upper_90: 22000,
      sum_90: 116000,
      sum_squares_90: 2254000000,
      std: 2070.1966780270627,
      upper: 24000,
      lower: 18000,
      count: 7,
      count_ps: 0.7,
      sum: 140000,
      sum_squares: 2830000000,
      mean: 20000,
      median: 19000
    }
  },
  counter_rates: {
    'quantum.phoenix.request': 0.7
  }
}
```

*NOTE: To install and run StatsD locally follow the simple guide [here](https://anomaly.io/statsd-install-and-config/index.html).*

This reporting leaves something to be desired. We're not currently taking advantage of the request context, passed into the `handle_event/4` function as the `metadata` argument. This metric alone is not very helpful from an observability standpoint.

We have two options here. We can either emit a more specific event from our controller, something like:

```elixir
:telemetry.execute([:phoenix, :request, :signup], %{duration: System.monotonic_time() - start}, conn)
```

This leaves us on the hook for defining and emitting custom events _from every controller action_. Soon it will be hard to keep track of and standardize all of these events.

We could instead add some tags to the metric we are sending to StatsD in the event handler:

```elixir
StatsdReporter.increment("phoenix.request.success", 1, tags: [metadata.request_path])
StatsdReporter.timing("phoenix.request.success", dur, tags: [metadata.request_path])
```

The standard StatsD agent does not support tagging, and will error if we use tags here. However, if you are reporting to the DogStatsD agent with the goal of sending metrics to Datadog, your tags will be successfully applied like this:

```
quantum.phoenix.request:1|c|#/register/new
quantum.phoenix.request:21000|ms|#/register/new
```

We won't dig into solving this problem now. Instead, we're highlighting the fact that metrics reporting is complex. It's a hard problem to solve and we could easily throw many hours and lots of code at it.

### Event Emitting + Reporting Pitfalls

Telemetry provides a simple interface for instrumentation, but our barebones example leaves a lot to be desired. Although we've identified a need to instrument and report on _all_ of the web requests received by our app, we've left ourselves on the hook for manually emitting Telemetry events for _every_ request, from _every endpoint_.

Our reporting mechanism, currently set up to send metrics to StatsD, is also a little problematic. Not only did we have to do the work to setup our own reporter, with the help of the `Statix` library, we're not properly taking advantage of tagging or rich event event context. We'll have to do additional work to utilize our event context, either through tagging with a DogStatsD reporter (even more work to set up a whole new reporter!) or by updating the name of the event itself.

"Wait a minute", you might be thinking, "I thought Telemetry was supposed to standardize instrumentation events and make it fast and easy to operate on and report those events. Why do I _still_ have to emit _all_ my own events and be on the hook for _all_ of my reporting needs?"

### Up Next...

Well the answer is, you _don't_ have to emit all of your own events _or_ be responsible for all of your reporting! Now that we understand _how_ to set up a Telemetry pipeline, and how it works under the hood to store and execute callbacks for events using ETS, we're ready to rely on some handy abstractions that additional Telemetry libraries provide.

Surprise! Phoenix and Ecto are *already* emitting common events from source code, including request counts and duration. The Telemetry Metrics library will make it super easy for us to hook into these events without defining and attaching our own handler.

Further, Telemetry provides a number of reporting clients, including a StatsD reporter, that we can plug into our Telemetry Metrics module for free metrics reporting to StatsD _or_ DogStatsD, allowing us to take advantage of event metadata with tagging.

In the next post, we'll leverage Telemetry Metrics and the Telemetry Statsd Reporter to listen for and report a number of useful VM, Phoenix and Ecto "Out Of The Box" metrics. In doing so, we'll abstract away the need for our custom `:telemetry.execute/3` calls, our custom handler _and_ our custom StatsD reporter.

See you soon!
























































d
