local grafana = import 'grafonnet/grafana.libsonnet';
local utils = import 'mixin-utils/utils.libsonnet';

(import 'dashboard-utils.libsonnet') {
  grafanaDashboards+: {
    local dashboards = self,
    local labelsSelector = 'cluster="$cluster", job="$namespace/ingester"',
    'loki-chunks.json': {
                          local cfg = self,
                        } +
                        $.dashboard('Loki / Chunks', uid='chunks')
                        .addCluster()
                        .addNamespace()
                        .addTag()
                        .addRow(
                          $.row('Active Series / Chunks')
                          .addPanel(
                            $.panel('Series') +
                            $.queryPanel('sum(loki_ingester_memory_chunks{%s})' % labelsSelector, 'series'),
                          )
                          .addPanel(
                            $.panel('Chunks per series') +
                            $.queryPanel(
                              'sum(loki_ingester_memory_chunks{%s}) / sum(loki_ingester_memory_streams{%s})' % [
                                labelsSelector,
                                labelsSelector,
                              ],
                              'chunks'
                            ),
                          )
                        )
                        .addRow(
                          $.row('Flush Stats')
                          .addPanel(
                            $.panel('Utilization') +
                            $.latencyPanel('loki_ingester_chunk_utilization', '{%s}' % labelsSelector, multiplier='1') +
                            { yaxes: $.yaxes('percentunit') },
                          )
                          .addPanel(
                            $.panel('Age') +
                            $.latencyPanel('loki_ingester_chunk_age_seconds', '{%s}' % labelsSelector),
                          ),
                        )
                        .addRow(
                          $.row('Flush Stats')
                          .addPanel(
                            $.panel('Size') +
                            $.latencyPanel('loki_ingester_chunk_entries', '{%s}' % labelsSelector, multiplier='1') +
                            { yaxes: $.yaxes('short') },
                          )
                          .addPanel(
                            $.panel('Entries') +
                            $.queryPanel(
                              'sum(rate(loki_chunk_store_index_entries_per_chunk_sum{%s}[5m])) / sum(rate(loki_chunk_store_index_entries_per_chunk_count{%s}[5m]))' % [
                                labelsSelector,
                                labelsSelector,
                              ],
                              'entries'
                            ),
                          ),
                        )
                        .addRow(
                          $.row('Flush Stats')
                          .addPanel(
                            $.panel('Queue Length') +
                            $.queryPanel('cortex_ingester_flush_queue_length{%s}' % labelsSelector, '{{pod}}'),
                          )
                          .addPanel(
                            $.panel('Flush Rate') +
                            $.qpsPanel('loki_ingester_chunk_age_seconds_count{%s}' % labelsSelector,),
                          ),
                        )
                        .addRow(
                          $.row('Flush Stats')
                          .addPanel(
                            $.panel('Chunks Flushed/Second') +
                            $.queryPanel('sum(rate(loki_ingester_chunks_flushed_total{%s}[$__rate_interval]))' % labelsSelector, '{{pod}}'),
                          )
                          .addPanel(
                            $.panel('Chunk Flush Reason') +
                            $.queryPanel('sum by (reason) (rate(loki_ingester_chunks_flushed_total{%s}[$__rate_interval])) / ignoring(reason) group_left sum(rate(loki_ingester_chunks_flushed_total{%s}[$__rate_interval]))' % [labelsSelector, labelsSelector], '{{reason}}') + {
                              stack: true,
                              yaxes: [
                                { format: 'short', label: null, logBase: 1, max: 1, min: 0, show: true },
                                { format: 'short', label: null, logBase: 1, max: 1, min: null, show: false },
                              ],
                            },
                          ),
                        )
                        .addRow(
                          $.row('Utiliziation')
                          .addPanel(
                            grafana.heatmapPanel.new(
                              'Chunk Utilization',
                              datasource='$datasource',
                              yAxis_format='percentunit',
                              tooltip_showHistogram=true,
                              color_colorScheme='interpolateSpectral',
                              dataFormat='tsbuckets',
                              yAxis_decimals=0,
                              legend_show=true,
                            ).addTargets(
                              [
                                grafana.prometheus.target(
                                  'sum by (le) (rate(loki_ingester_chunk_utilization_bucket{cluster="$cluster", job="$namespace/ingester"}[$__rate_interval]))',
                                  legendFormat='{{le}}',
                                  format='heatmap',
                                ),
                              ],
                            )
                          )
                        )
                        .addRow(
                          $.row('Utilization')
                          .addPanel(
                            grafana.heatmapPanel.new(
                              'Chunk Size Bytes',
                              datasource='$datasource',
                              yAxis_format='bytes',
                              tooltip_showHistogram=true,
                              color_colorScheme='interpolateSpectral',
                              dataFormat='tsbuckets',
                              yAxis_decimals=0,
                              // tooltipDecimals=3,
                              // span=3,
                              legend_show=true,
                            ).addTargets(
                              [
                                grafana.prometheus.target(
                                  'sum(rate(loki_ingester_chunk_size_bytes_bucket{%s}[$__rate_interval])) by (le)' % labelsSelector,
                                  legendFormat='{{le}}',
                                  format='heatmap',
                                ),
                              ],
                            )
                          )
                        )
                        .addRow(
                          $.row('Utilization')
                          .addPanel(
                            $.panel('Chunk Size Quantiles') +
                            $.queryPanel(
                              [
                                'histogram_quantile(0.99, sum(rate(loki_ingester_chunk_size_bytes_bucket{%s}[1m])) by (le))' % labelsSelector,
                                'histogram_quantile(0.90, sum(rate(loki_ingester_chunk_size_bytes_bucket{%s}[1m])) by (le))' % labelsSelector,
                                'histogram_quantile(0.50, sum(rate(loki_ingester_chunk_size_bytes_bucket{%s}[1m])) by (le))' % labelsSelector,
                              ],
                              [
                                'p99',
                                'p90',
                                'p50',
                              ],
                            ) + {
                              yaxes: $.yaxes('bytes'),
                            },
                          )
                        )
                        .addRow(
                          $.row('Duration')
                          .addPanel(
                            $.panel('Chunk Duration hours (end-start)') +
                            $.queryPanel(
                              [
                                'histogram_quantile(0.5, sum(rate(loki_ingester_chunk_bounds_hours_bucket{%s}[5m])) by (le))' % labelsSelector,
                                'histogram_quantile(0.99, sum(rate(loki_ingester_chunk_bounds_hours_bucket{%s}[5m])) by (le))' % labelsSelector,
                                'sum(rate(loki_ingester_chunk_bounds_hours_sum{%s}[5m])) / sum(rate(loki_ingester_chunk_bounds_hours_count{%s}[5m]))' % [
                                  labelsSelector,
                                  labelsSelector,
                                ],
                              ],
                              [
                                'p50',
                                'p99',
                                'avg',
                              ],
                            ),
                          )
                        ),
  },
}
