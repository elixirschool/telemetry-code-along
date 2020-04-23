defmodule Quantum.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      {TelemetryMetricsStatsd, metrics: metrics(), formatter: :datadog}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Erlang VM Metrics - Formats `gauge` StatsD metric type
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.system_counts.process_count"),

      # Database Time Metrics - Formats `timing` StatsD metric type
      summary(
        "quantum.repo.query.total_time",
        unit: {:native, :millisecond},
        tag_values: &__MODULE__.query_metatdata/1,
        tags: [:source, :command]
      ),

      # Database Count Metrics - Formats `count` StatsD metric type
      counter(
        "quantum.repo.query.count",
        tag_values: &__MODULE__.query_metatdata/1,
        tags: [:source, :command]
      ),

      # Phoenix Time Metrics - Formats `timing` StatsD metric type
      summary(
        "phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tags: [:plug, :plug_opts]
      ),

      # Phoenix Count Metrics - Formats `count` StatsD metric type
      counter(
        "phoenix.router_dispatch.stop.count",
        tag_values: &__MODULE__.endpoint_metadata/1,
        tags: [:plug, :plug_opts, :status]
      ),

      counter(
        "phoenix.error_rendered.count",
        tag_values: &__MODULE__.error_request_metadata/1,
        tags: [:status, :request_path]
      ),

      # LiveView metrics - Instrumentation for a custom Telemetry event executed in `ButtonLive`
      summary(
        "live.handle_event.button_click.duration"
      ),
      counter(
        "live.handle_event.button_click.count",
        tag_values: &__MODULE__.live_view_metadata/1,
        tags: [:button]
      ),
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
end
