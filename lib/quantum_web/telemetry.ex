defmodule QuantumWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      # {:telemetry_poller,
      #  measurements: periodic_measurements(),
      #  period: 10_000},
      # Or TelemetryMetricsPrometheus or TelemetryMetricsFooBar
      # {TelemetryMetricsStatsd, metrics: metrics()}
      {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp metrics do
    [
      # VM Metrics
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),

      last_value("quantum.worker.memory", unit: :byte),
      last_value("quantum.worker.message_queue_len"),

      # Database Time Metrics
      summary("quantum.repo.query.total_time", unit: {:native, :millisecond}),
      summary("quantum.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("quantum.repo.query.query_time", unit: {:native, :millisecond}),
      summary("quantum.repo.query.queue_time", unit: {:native, :millisecond}),
      counter("quantum.repo.query.count", tags: [:source, :command]),
      # counter("quantum.repo.query.total", tags: [:source, :command]),

      # Phoenix Time Metrics
      summary("phoenix.endpoint.stop.duration",
              unit: {:native, :millisecond}),
      summary(
        "phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tags: [:plug]
      ),

      counter(
        "http.request.count",
        tags: [:controller, :action]
      )
    ]
  end

  # defp periodic_measurements do
  #   [
  #     {:process_info,
  #      event: [:my_app, :worker],
  #      name: Rumbl.Worker,
  #      keys: [:message_queue_len, :memory]}
  #   ]
  # end
end
