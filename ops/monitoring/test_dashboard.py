"""Execute the dashboard's actual PromQL with promtool, without any live service.

Usage: python ops/monitoring/test_dashboard.py /path/to/promtool
Requires Python 3 and Prometheus promtool (3.15.0 used in CI).
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def main():
    dashboard = json.loads(Path(__file__).with_name("formypet-dashboard.json").read_text(encoding="utf-8"))
    panels = {panel["id"]: panel for panel in dashboard["panels"]}

    def query(panel_id, target=0):
        expr = panels[panel_id]["targets"][target]["expr"]
        for key, value in {"${service:regex}": "formypet", "${environment:regex}": "production",
                           "${job:regex}": "formypet-production", "$__range": "5m"}.items():
            expr = expr.replace(key, value)
        assert "$" not in expr, expr
        return expr

    labels = 'service="formypet",environment="production",job="formypet-production"'
    http_labels = labels + ',uri="/api/v1/pets",method="GET",status="200",outcome="SUCCESS",exception="none"'
    heartbeat = {"series": "process_uptime_seconds{" + labels + "}", "values": "0+60x20"}
    counter = {"series": "http_server_requests_seconds_count{" + http_labels + "}", "values": "0+60x20"}

    def check(panel, value, at="5m"):
        # Ignore insignificant floating point cancellation (e.g. 1 - 0.95).
        return {"expr": "round((" + query(panel) + "), 0.000000001)", "eval_time": at,
                "exp_samples": [] if value is None else [{"labels": "{}", "value": value}]}

    # Every panel query is parsed/evaluated, including JVM/pool queries without matching fixtures.
    checks = [check(panel_id, 0 if panel_id == 30 else None)
              for panel_id, panel in panels.items() if panel.get("targets")]
    checks.extend({"expr": query(panel_id, index), "eval_time": "5m", "exp_samples": []}
                  for panel_id, panel in panels.items() for index in range(1, len(panel.get("targets", []))))
    tests = [{"name": "no data never looks healthy", "interval": "1m", "input_series": [],
              "promql_expr_test": checks}]
    tests.append({"name": "traffic with no error series is zero percent", "interval": "1m",
                  "input_series": [heartbeat, counter],
                  "promql_expr_test": [check(2, 1), check(3, 0), check(4, 0), check(30, 1)]})
    tests.append({"name": "idle service has no ratios", "interval": "1m",
                  "input_series": [heartbeat, {**counter, "values": "0+0x20"}],
                  "promql_expr_test": [check(2, 0), check(3, None), check(4, None)]})
    tests.append({"name": "counter resets are handled before aggregation", "interval": "1m",
                  "input_series": [heartbeat, {**counter, "values": "0 60 120 0 60 120"}],
                  "promql_expr_test": [check(2, 0.75)]})
    tests.append({"name": "old samples do not masquerade as current traffic", "interval": "1m",
                  "input_series": [{**heartbeat, "values": "0 60 120 _ _ _"},
                                   {**counter, "values": "0 60 120 _ _ _"}],
                  "promql_expr_test": [check(2, None), check(3, None), check(30, 0)]})
    errors = {"series": counter["series"].replace('status="200"', 'status="500"')
              .replace('outcome="SUCCESS"', 'outcome="SERVER_ERROR"'), "values": "0+20x20"}
    tests.append({"name": "status based error share", "interval": "1m",
                  "input_series": [heartbeat, counter, errors],
                  "promql_expr_test": [check(4, 0.25)]})
    buckets = [{"series": "http_server_requests_seconds_bucket{" + http_labels + ',le="' + bound + '"}',
                "values": values} for bound, values in [("1.0", "0+45x20"), ("30.0", "0+57x20"), ("+Inf", "0+60x20")]]
    tests.append({"name": "slow request boundaries", "interval": "1m",
                  "input_series": [heartbeat, counter, *buckets],
                  "promql_expr_test": [check(6, 0.25), check(7, 0.05), check(11, 30), check(12, 30)]})
    normalized_buckets = [{**bucket, "series": bucket["series"].replace('le="1.0"', 'le="1"')
                          .replace('le="30.0"', 'le="30"')} for bucket in buckets]
    tests.append({"name": "canonical numeric bucket labels", "interval": "1m",
                  "input_series": [heartbeat, counter, *normalized_buckets],
                  "promql_expr_test": [check(6, 0.25), check(7, 0.05)]})
    tests.append({"name": "mean latency and percentile sample size", "interval": "1m",
                  "input_series": [heartbeat, counter,
                      {"series": "http_server_requests_seconds_sum{" + http_labels + "}", "values": "0+30x20"}],
                  "promql_expr_test": [check(5, 0.5), check(13, 900, "15m")]})
    with tempfile.TemporaryDirectory(prefix="formypet-promql-") as temp:
        fixture = Path(temp) / "dashboard-tests.yml"
        fixture.write_text(json.dumps({"rule_files": [], "evaluation_interval": "1m", "fuzzy_compare": True,
                                       "tests": tests}), encoding="utf-8")
        subprocess.run([sys.argv[1] if len(sys.argv) > 1 else "promtool", "test", "rules", str(fixture)], check=True)


if __name__ == "__main__":
    main()
