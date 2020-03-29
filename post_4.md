# Instrumenting Phoenix with Telemetry Part IV: `telemetry_poller` + Erlang VM Metrics

In the previous post we taught `Telemetry.Metrics` to define metrics for a number of out-of-the-box Phoenix and Ecto Telemetry events and used `TelemetryMetricsStatsd` to handle and report those events to StasD.

In this post, we'll incorporate Erlang's `telemetry_poller` library into our Phoenix app so that we can observe and report on Erlang VM Telemetry events.

## Getting Started

First, we'll include the `telemetry_poller` dependency in our app and run `mix deps.get`

```elixir
# mix.exs
def deps do
  {:telemetry_poller, "~> 0.4"}
end
```

## `telemetry_poller` Telemetry Events

Now, when our app starts up, the `telemetry_poller` app will also start running. This app will poll the Erlang VM to take the following measurements and execute these measurements at Telemetry events:

* Memory - Measurement of the memory used by the Erlang VM
* Total run queue lengths - Measurement of the queue of tasks to be scheduled by the Erlang scheduler. This event will be executed with a measurement map describing:
  * `total` - a sum of all run queue lengths
  * `cpu` - a sum of CPU schedulers' run queue lengths, including dirty CPU run queue length on Erlang version 20 and greater
  * `io` - length of dirty IO run queue. It's always 0 if running on Erlang versions prior to 20.

* System count - Measurement of number of processes currently existing at the local node, the number of atoms currently existing at the local node and the number of ports currently existing at the local node
* Process info - A measurement with information about a given process, for example a worker in your application

Let's define metrics for some of these events in our `Quantum.Telemetry` module.

## Defining Metrics for `telemetry_poller` Events

The `Telemetry.Metrics.last_value/2` function defines a metric that holds the value of the selected measurement from the most recent event. The `TelemetryMetricsStatsd` reporter will send such a metric to StatsD as a "gauge" metric. Let's define a set of gauge metrics for some of the Telemetry events mentioned above:

```elixir
defp metrics do
  [
    # VM Metrics - gauge
    last_value("vm.memory.total", unit: :byte),
    last_value("vm.total_run_queue_lengths.total"),
    last_value("vm.total_run_queue_lengths.cpu")
  ]
end
```

This will establish and send the following metrics to StatsD:

```
gauges: {
  'vm.memory.total': 49670008,
  'vm.total_run_queue_lengths.total': 0,
  'vm.total_run_queue_lengths.cpu': 0,
}
```

## Polling for Custom Measurements

You can also use the `telemetry_poller` library to emit measurements describing processes or workers running in your app, or to emit custom measurements. See the docs [here](https://hexdocs.pm/telemetry_metrics/Telemetry.Metrics.html#module-vm-metrics) for more info.  

## Conclusion

Once again we've seen that Erlang and Elixir's family of Telemetry libraries make it easy for us to achieve fairly comprehensive instrumentation with very little hand-rolled code. By adding the `telemetry_poller` library to our dependencies, we're ensuring our application will execute a set of Telemetry events describing Erlang VM measurements at regular intervals. We're observing these events, formatting them and sending them to StatsD with the help of `Telemetry.Metrics` and `TelemetryMetricsStatsd`, allowing us to paint an even fuller picture of the state of our Phoenix app at any given time.
