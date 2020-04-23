# Quantum

Quantum is a dummy Phoenix app used to illustrate instrumentation with Telemetry.

## Up and Running

* Clone down this repo
* `cd` into the repo and run `mix deps.get`
* Then, run `npm install --prefix ./assets`
* Start the Phoenix server: `mix phx.server`

To run with StatsD so that you can see your metrics processed, follow the StatsD installation instructions [here](https://anomaly.io/statsd-install-and-config/index.html).

## Learn More

Check out the blog series, Instrumenting Phoenix with Telemetry, here:

* Part I: Telemetry Under The Hood
* Part II: Handling Telemetry Events with `TelemetryMetrics` + `TelemetryMetricsStatsd`
* Part III: Observing Phoenix + Ecto Telemetry Events
* Part IV: Erlang VM Measurements with `telemetry_poller`, `TelemetryMetrics` + `TelemetryMetricsStatsd`

### Follow Along With The Code

* [Part I starting state branch](https://github.com/elixirschool/telemetry-code-along/tree/part-1-start)
* [Part I solution branch](https://github.com/elixirschool/telemetry-code-along/tree/part-1-solution)
* [Part II starting state branch](https://github.com/elixirschool/telemetry-code-along/tree/part-2-start)
* [Part II solution branch](https://github.com/elixirschool/telemetry-code-along/tree/part-2-solution)
* [Part III starting state branch](https://github.com/elixirschool/telemetry-code-along/tree/part-3-start)
* [Part III solution branch](https://github.com/elixirschool/telemetry-code-along/tree/part-3-solution)
* [Part IV starting state branch](https://github.com/elixirschool/telemetry-code-along/tree/part-4-start)
* [Part IV solution branch](https://github.com/elixirschool/telemetry-code-along/tree/part-4-solution)
* [Adding LiveDashboard](https://github.com/elixirschool/telemetry-code-along/tree/live-dashboard)
