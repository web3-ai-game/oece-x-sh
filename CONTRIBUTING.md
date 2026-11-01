# Contributing

## Before you open a pull request

1. Keep the tool one file: `oece-x.sh`.
2. Run `shellcheck -S warning oece-x.sh`. The result must be zero warnings.
3. Run `bash -n oece-x.sh`.
4. Run both sandboxes:
   - `bash oece-x.sh --lang en --demo --audit --json`
   - `bash oece-x.sh --lang zh-Hant --demo --audit`
5. Search the diff for production addresses, account names, key paths, and deploy notes. Use `192.0.2.x`, `198.51.100.x`, or `203.0.113.x` in examples.

## Language

User-facing strings go through `t()`. Add both the Traditional Chinese default and the English string. `zh_CN` and every other `zh*` locale stay on Traditional Chinese.

## Scope

Inspection, benchmarks, and read-only security baseline checks belong here. Hardening with rollback belongs in [oece-x-blue-sh](https://github.com/web3-ai-game/oece-x-blue-sh). Do not add a downloader for that panel, and do not add proxy, tunnel, or traffic-circumvention features.

## Commits

Write the subject in English. Explain operator-visible behavior in the body when the menu changes.
