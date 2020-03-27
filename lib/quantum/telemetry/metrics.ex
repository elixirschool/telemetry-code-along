defmodule Quantum.Telemetry.Metrics do
  require Logger
  alias Quantum.Telemetry.StatsdReporter

  @spec handle_event([:phoenix | :request | :success, ...], any, any, any) :: :ok | {:error, any}
  def handle_event([:phoenix, :request, :success], %{duration: dur}, metadata, _config) do
    StatsdReporter.increment("phoenix.request.success", 1, [request_path: metadata.request_path])
    StatsdReporter.timing("phoenix.request.success", dur, [request_path: metadata.request_path])
  end

  def handle_event([:phoenix, :request, :failure], %{duration: dur}, metadata, _config) do
    StatsdReporter.increment("phoenix.request.failure", 1, [request_path: metadata.request_path])
    StatsdReporter.timing("phoenix.request.failure", dur, [request_path: metadata.request_path])
  end

  # 
  #   counters: {
  #     'statsd.bad_lines_seen': 0,
  #     'statsd.packets_received': 14,
  #     'statsd.metrics_received': 14,
  #     'quantum.phoenix.request.success': 7
  #   },
  #   timers: {
  #     'quantum.phoenix.request.success': [
  #       18000, 18000,
  #       19000, 19000,
  #       20000, 22000,
  #       24000
  #     ]
  #   },
  #   gauges: { 'statsd.timestamp_lag': 0 },
  #   timer_data: {
  #     'quantum.phoenix.request.success': {
  #       count_90: 6,
  #       mean_90: 19333.333333333332,
  #       upper_90: 22000,
  #       sum_90: 116000,
  #       sum_squares_90: 2254000000,
  #       std: 2070.1966780270627,
  #       upper: 24000,
  #       lower: 18000,
  #       count: 7,
  #       count_ps: 0.7,
  #       sum: 140000,
  #       sum_squares: 2830000000,
  #       mean: 20000,
  #       median: 19000
  #     }
  #   },
  #   counter_rates: {
  #     'statsd.bad_lines_seen': 0,
  #     'statsd.packets_received': 1.4,
  #     'statsd.metrics_received': 1.4,
  #     'quantum.phoenix.request.success': 0.7
  #   },
  #   sets: {},
  #   pctThreshold: [ 90 ]
  # }

end
