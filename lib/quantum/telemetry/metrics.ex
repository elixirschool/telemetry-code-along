defmodule Quantum.Telemetry.Metrics do
  require Logger

  @spec handle_event([:browser | :request | :stop, ...], any, any, any) :: :ok | {:error, any}
  def handle_event([:browser, :request, :stop], measurements, metadata, _config) do
    Logger.info("[TELEMETRY][#{metadata.conn.request_path}] #{metadata.conn.status} sent in #{measurements.duration}")
  end
end
