#!/usr/bin/env python3
"""Runs the retention workload and reports what the JVM still holds after the timed consumes finished.

usage: python3 retention.py <strategy> [operations=100000] [same|fresh] [jar=target/bin/blocking_queue_eval.jar]

"same" pushes one pre-built message every time; "fresh" creates a new record for every message.

The workload does `operations` successful timed consumes, prints RETENTION_DONE and waits. This script then asks the
JVM for a full-GC class histogram (jcmd GC.class_histogram, which counts live objects only) and prints one RESULT line
with the heap in use and the number of live pipe observer/timer objects.
"""
import re
import subprocess
import sys

strategy = sys.argv[1]
operations = sys.argv[2] if len(sys.argv) > 2 else "100000"
shape = sys.argv[3] if len(sys.argv) > 3 else "same"
jar = sys.argv[4] if len(sys.argv) > 4 else "target/bin/blocking_queue_eval.jar"

proc = subprocess.Popen(["java", "-jar", jar, "retention", strategy, operations, "90"] + (["fresh"] if shape == "fresh" else []),
                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
for line in proc.stdout:
    if line.startswith("RESULT"):
        print(line.strip())
    if "RETENTION_DONE" in line:
        break
else:
    sys.exit("the workload ended without RETENTION_DONE")

histogram = subprocess.run(["jcmd", str(proc.pid), "GC.class_histogram"], capture_output=True, text=True).stdout
heap = subprocess.run(["jcmd", str(proc.pid), "GC.heap_info"], capture_output=True, text=True).stdout
proc.kill()

def count(pattern):
    for row in histogram.splitlines():
        if re.search(pattern, row):
            fields = row.split()
            return int(fields[1]), int(fields[2])
    return 0, 0

used = re.search(r"used (\d+)K", heap)
total_bytes = re.search(r"Total\s+(\d+)\s+(\d+)", histogram)
fields = {
    "operations": operations,
    "shape": shape,
    "heapUsedKB": used.group(1) if used else "?",
    "liveObjectBytes": total_bytes.group(2) if total_bytes else "?",
}
for name, pattern in [("callbacks", r"pipe\.observer\.Callback$"), ("observables", r"pipe\.observer\.Observable$"),
                      ("timerTasks", r"java\.util\.TimerTask$|pipe\.observer\.\S*Task"),
                      ("numberedOrKeyMaps", r"values\.MapValueImpl$")]:
    n, size = count(pattern)
    fields[name] = str(n)
    fields[name + "Bytes"] = str(size)
print("RESULT workload=retentionJvm strategy=" + strategy + " " + " ".join(f"{k}={v}" for k, v in fields.items()))
