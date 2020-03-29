defmodule Quantum.Telemetry.Metrics do
  require Logger
  alias Quantum.Telemetry.StatsdReporter

  @spec handle_event([:phoenix | :request, ...], any, any, any) :: :ok | {:error, any}
  def handle_event([:phoenix, :request], %{duration: dur}, metadata, _config) do
    Logger.info("Received [:phoenix, :request] event. Request duration: #{dur}, Route: #{metadata.request_path}")
    StatsdReporter.increment("phoenix.request", 1, tags: [metadata.request_path])
    StatsdReporter.timing("phoenix.request", dur, tags: [metadata.request_path])
  end
end
