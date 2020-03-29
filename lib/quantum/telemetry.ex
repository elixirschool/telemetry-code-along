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
        tags: [:request_path]
      ),

      counter(
        "phoenix.request.count",
        tags: [:request_path]
      )
    ]
  end
end
