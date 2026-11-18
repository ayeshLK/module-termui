# Agent demo

A small agent-style program built on `ayesha/termui`: it streams text, shows a spinner and a status line
in the live region, asks for approval before "running a tool", and prints its result on standard
output. It runs interactively, with its output piped, and with no terminal at all.

## Build and run

The example depends on the package from your local Ballerina repository:

```sh
(cd ../../ballerina && bal pack && bal push --repository=local)
bal build
java -jar target/bin/agent_demo.jar                 # interactive: answer the question with y or n
java -jar target/bin/agent_demo.jar > result.txt    # the interface stays on the terminal; result.txt holds the result
java -jar target/bin/agent_demo.jar < /dev/null     # headless: plain output, the question is denied by default
```

`verify.py` checks all of this end to end under a pseudo-terminal, including that SIGTERM, SIGINT and
SIGHUP leave the terminal restored: `JAVA=$(which java) python3 verify.py`.
