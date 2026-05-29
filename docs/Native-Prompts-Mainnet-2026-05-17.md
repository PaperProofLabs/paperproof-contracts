# Native Prompts Mainnet Record - 2026-05-17

This note records the first mainnet deployment of PaperProof native Copilot
prompts.

Native prompts are stored as PaperProof `generic_file` artifacts. A small
`prompt_registry` package records which artifact series an app route should use
and whether the app should follow the latest version or pin a specific version.
The official app currently uses this path for the global PaperProof Copilot
prompt.

## Mainnet Objects

- Prompt registry package:
  `0x10b9c6e90a896dc3244d047e32724d80de0dc697b5ea12c5fdd8925131ed4c59`
- Prompt registry shared object:
  `0x14ec45eb83bb1b0eb22c7e885c7c71ea05b1e22dd05e3e1107dcef528600b0da`
- `copilot/global` prompt series:
  `0x13c99b4811d9b89fd0decd8e9c713bafd639e6af3401a18043aed7e0270044fb`
- First prompt version:
  `0x8963dd3178bfe759c2301c921beca0aac88a8e1eb286685ff70e98c862b01e5e`
- Walrus blob:
  `DqfdB2FFn94EIeeXE9qXoNZdu7IzTYqoknjA-ZJsZDQ`

## Mainnet Transactions

- Publish prompt registry package:
  `5ET2F9jMnw8xBB3hCfa1wGyEj1x5CHYi1QhfaTZLbW8j`
- Create `PromptRegistry`:
  `J4fzBiF9ZFpg9QW7MeSDHekcPVj2K8R3Sfw36fN7EY7e`
- Publish prompt as PaperProof `generic_file`:
  `54JGtVwL5cVK7UeJw3TM9LXzGAjzWcVeih5eNTjLNJ7e`
- Register `paperproof-app/copilot/global`:
  `AdHgZjYc1S8yts7EixqV8ouaMhpfd7dYiyKWpYhCURM7`

## Version Model

Prompt content is the content of a normal PaperProof artifact version:

1. Encode the prompt as a JSON package with content type
   `application/vnd.paperproof.prompt+json`.
2. Store the JSON package in Walrus.
3. Publish it as a `generic_file` artifact, or add a new version to the same
   `generic_file` series.
4. Register the app route in `PromptRegistry`.

For ordinary prompt updates, keep the registry entry on `use_latest = true` and
add a new `generic_file` version to the existing prompt series. For a controlled
rollout or rollback, set `use_latest = false` and provide
`pinned_version_id`.

The current official app manifest entry is:

```json
{
  "route_id": "copilot/global",
  "series_id": "0x13c99b4811d9b89fd0decd8e9c713bafd639e6af3401a18043aed7e0270044fb",
  "use_latest": true,
  "pinned_version_id": null,
  "role": "global",
  "content_type": "application/vnd.paperproof.prompt+json"
}
```

## Authority Model

The deployed `prompt_registry` does not require a governance vote for each
prompt update. It binds itself to the existing official `GovernanceVault` and
checks that the transaction sender is `governance::active_operator(vault)` when
creating the registry or registering a prompt.

This means:

- the already deployed publishing and governance packages did not need to be
  upgraded;
- prompt updates are lightweight operator actions, not proposal execution
  flows;
- arbitrary addresses cannot write official prompt route bindings unless they
  are the active operator recorded by the official `GovernanceVault`.

## App Integration

The static app reads `public/prompts/manifest.json`, resolves the configured
series/latest-or-pinned version through Sui object reads, downloads the Walrus
prompt package, validates the prompt package schema, and injects it before the
embedded fallback prompt.

If the manifest, chain read, or Walrus read fails, the app keeps using the
bundled prompt from `src/copilot/prompts.ts`. This keeps the static app usable
even if a remote read path is temporarily unavailable.

## Verification

The mainnet integration was verified by reading the app manifest, resolving the
registered series and current version, downloading the Walrus blob, and decoding
the prompt JSON package. The decoded package used schema version `1`, content
type `application/vnd.paperproof.prompt+json`, and began with the expected
PaperProof Copilot system prompt.

Local verification also covered:

- `sui move test` for `prompt_registry`;
- TypeScript SDK typecheck and prompt/deployment tests;
- `paperproof-app` production build.
