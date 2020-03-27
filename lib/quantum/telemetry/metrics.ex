defmodule Quantum.Telemetry.Metrics do
  require Logger
  alias Quantum.Telemetry.StatsdReporter

  @spec handle_event([:phoenix | :request | :success, ...], any, any, any) :: :ok | {:error, any}
  def handle_event([:phoenix, :request, :success], %{duration: dur}, metadata, _config) do
    Logger.info("Received [:phoenix, :request] event. Request duration: #{dur}, Route: #{metadata.request_path}")
    StatsdReporter.increment("phoenix.request.success", 1, tags: [metadata.request_path])
    StatsdReporter.timing("phoenix.request.success", dur, tags: [metadata.request_path])
  end

  def handle_event([:phoenix, :request, :failure], %{duration: dur}, metadata, _config) do
    StatsdReporter.increment("phoenix.request.failure", 1, [metadata.request_path])
    StatsdReporter.timing("phoenix.request.failure", dur, [metadata.request_path])
  end
end
