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
      # {TelemetryMetricsStatsd, metrics: metrics(), formatter: :datadog} # for datadog, add prefix: "quantum", global_tags: [env: Mix.env()] but global tags prob. best handled by DD agent conf
      {TelemetryMetricsStatsd, metrics: metrics()}
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp metrics do
    [
      # VM Metrics - gauge
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),

      # Custom Polled Metrics
      # last_value("quantum.worker.memory", unit: :byte),
      # last_value("quantum.worker.message_queue_len"),

      # Database Time Metrics - timing
      summary("quantum.repo.query.total_time", unit: {:native, :millisecond}, tag_values: &__MODULE__.query_metatdata/1, tags: [:source, :command]),
      summary("quantum.repo.query.decode_time", unit: {:native, :millisecond}),
      summary("quantum.repo.query.query_time", unit: {:native, :millisecond}),
      summary("quantum.repo.query.queue_time", unit: {:native, :millisecond}),

      # Database Count Metrics - count
      counter("quantum.repo.query.count", tag_values: &__MODULE__.query_metatdata/1, tags: [:source, :command]),

      # Phoenix Time Metrics - timing
      # summary("phoenix.endpoint.stop.duration",
              # unit: {:native, :millisecond}, tag_values: &__MODULE__.endpoint_metadata/1),
      summary(
        "phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tags: [:plug, :plug_opts] # for datadog, add :route and view metric over route
      ),

      # Phoenix Count Metrics - count
      counter(
        "phoenix.router_dispatch.stop.count",
        tag_values: &__MODULE__.endpoint_metadata/1,
        tags: [:plug, :plug_opts, :status] # for datadog, add :route and view metric over route
      ),

      # :telemetry.execute([:phoenix, :error_rendered], %{duration: duration}, metadata)
      # make sure you set debug error to false in dev.exs b/c otherwise you see helpful routes pager, this way it renders your error view
      counter(
        "phoenix.error_rendered.duration",
        tag_values: &__MODULE__.error_request_metadata/1,
        tags: [:status, :request_path]
      ),

      # LiveView metrics
      summary(
        "live.handle_event.button_click.duration"
      ),
      counter(
        "live.handle_event.button_click.count",
        tag_values: &__MODULE__.live_view_metadata/1,
        tags: [:button]
      )
    ]
  end

  def error_request_metadata(%{conn: %{request_path: request_path}, status: status}) do
    %{status: status, request_path: request_path}
  end

  def query_metatdata(%{source: source, result: {_, %{command: command}}}) do
    %{source: source, command: command}
  end

  def endpoint_metadata(%{conn: %{status: status}, plug: plug, plug_opts: plug_opts}) do
    %{status: status, plug: plug, plug_opts: plug_opts}
  end

  def live_view_metadata(%{assigns: %{selected_button: button}}) do
    %{button: button}
  end

  # custom polling for worker metrics
  # defp periodic_measurements do
  #   [
  #     {:process_info,
  #      event: [:my_app, :worker],
  #      name: Rumbl.Worker,
  #      keys: [:message_queue_len, :memory]}
  #   ]
  # end
end
