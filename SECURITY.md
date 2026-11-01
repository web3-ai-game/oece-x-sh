# Security

oece-x.sh is a local audit and benchmark tool. It is not a remote-access product.

## What this repository must never contain

- Production hostnames, origin addresses, SSH aliases, or account names
- Private keys, passwords, password hashes, or automation key paths
- Nginx maps, deploy scripts, or notes about a live machine
- Hidden menu entries that download or run operator-only tooling

Example addresses in docs and demo output use the [RFC 5737](https://datatracker.ietf.org/doc/html/rfc5737) documentation ranges: `192.0.2.0/24`, `198.51.100.0/24`, and `203.0.113.0/24`.

## How to run it safely

- Read `oece-x.sh` before you run it. It is one file on purpose.
- Prefer a clone over `curl | bash`.
- Live checks need Linux root. `--demo` never writes disk and never needs root.
- `--audit` is read-only. Mutating menu items ask for an explicit `yes`.
- The sister panel is a separate repository: [oece-x-blue-sh](https://github.com/web3-ai-game/oece-x-blue-sh). This script only prints that URL. It does not fetch it.

## Reporting

Open a GitHub Security Advisory, or a private issue, on [web3-ai-game/oece-x-sh](https://github.com/web3-ai-game/oece-x-sh). Do not paste live host details into a public issue. Replace them with RFC 5737 addresses first.
