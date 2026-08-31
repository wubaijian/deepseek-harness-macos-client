# Security

## API keys

Never commit API keys, `.env` files, `~/.dsh/.credentials.yaml`, session data, or private workspace files. This client does not need API keys at build time and does not read or store them at runtime.

Configure providers inside DeepSeek Harness after the local service has started. If a key is accidentally committed, revoke it at the provider immediately and remove it from Git history.

## Local access

The client binds DeepSeek Harness to `127.0.0.1:3080`. Do not change it to a public network interface without understanding the access and authentication consequences.

## Reporting

Please open a GitHub issue for non-sensitive security hardening suggestions. Do not include active credentials, private logs, or personal data in an issue.
