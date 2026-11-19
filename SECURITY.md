# Security policy

## Supported versions

Security fixes are made in the latest minor release of the current major version (see
[COMPATIBILITY.md](COMPATIBILITY.md)). Older versions are not patched; upgrading within a major
version never needs code changes.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private reporting instead: open
the repository's **Security** tab, choose **Report a vulnerability**, and describe what you found and
how to reproduce it. You can expect a first reply within a week.

termui reads keyboard input and writes escape sequences to a terminal, and starts `stty` and `sh`
processes to configure it. Reports about terminal escape-sequence injection (for example, text a program
prints that is interpreted as a command by the terminal) and about how those processes are started are
in scope.
