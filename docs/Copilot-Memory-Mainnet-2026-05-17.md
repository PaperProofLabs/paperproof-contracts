# Copilot Memory Registry Mainnet Record

This note records the current mainnet deployment of the PaperProof Copilot
memory registry. The first deployment on 2026-05-17 was superseded before the
project's public release because the finalized registry model added an
active-entry index for one-active-memory-per-wallet-and-app discovery.

The memory registry is a lightweight PaperProof ecosystem extension. It does
not store private memory bodies. Private memory content remains in MemWal and
Walrus under the user's own MemWal account and delegate-key model. The
PaperProof registry stores only governed discovery metadata: provider policy,
per-entry MemWal pointers, descriptor artifact references, version policy, and
official Copilot availability.

## Mainnet Objects

- Memory registry package:
  `0x816684a152fdee1e7f15f65d18873ed7ee48540e8bd4205b3197a5ec0feda2c6`
- Memory registry shared object:
  `0x9a5beeb6610b33c06771c4152c039314784437e802e200afd2ce80fb88bdf9e2`
- Upgrade capability:
  `0xaab4745558cbde7703ea682eea3ceeb4d26d4e25749eb74c3cb6c94adcf74a0c`

## Mainnet Transactions

- Publish memory registry package:
  `C8pHX6fa4kN58XAo7Fnox59RpSKuuVqHRW9PvoEkfAa5`
- Create `MemoryRegistry`:
  `GF9iaJatdhXP56KUuGNHeH19dBeTTy22vrBYSChMTjcE`
- Enable MemWal provider policy:
  `H3WKZz3fuG6PfkZE8XGe1yoBgmoEw3sHSfwp1JSDivwy`

## Governance Binding

The memory registry binds to the existing official `GovernanceVault`.

- `MemoryRegistry.root_id`:
  `0x7dc6c78b276825499a2204b060394e80b81196eb1f77d2036b503a2cca15dd78`
- `MemoryRegistry.governance_vault_id`:
  `0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875`

Operator-managed calls check:

- `governance::assert_current_vault(governance_vault)`
- `governance::registry_id(governance_vault) == registry.root_id`
- `governance::active_operator(governance_vault) == tx_context::sender(ctx)`

This mirrors the native prompt registry's governance relationship. It does not
require per-memory PPRF voting and does not upgrade the existing publishing,
comments, or governance packages.

## Initialized Provider Policy

The `memwal` provider is enabled with schema version range `1..1`.

```text
provider = memwal
enabled = true
min_schema_version = 1
max_schema_version = 1
```

Provider policy is stored under `MemoryRegistry.provider_policies`, whose table
size is `1` after initialization.

## Entry Model

Each user memory registration creates a separate shared `MemoryEntry` object.
This avoids forcing all users through one large mutable table for entry updates.
The latest source also maintains an active-entry index so each owner wallet can
have at most one active entry for the same app id. A chain-level delete releases
that slot, so the user can create a replacement entry later.

Each entry records:

- owner wallet
- app id and memory id
- provider, currently `memwal`
- MemWal account id and namespace root
- descriptor artifact code and descriptor artifact series id
- latest-or-pinned descriptor version policy
- `available`, controlled by the active operator
- `owner_enabled` and `owner_deleted`, controlled by the entry owner

Official Copilot should treat an entry as usable only when:

- the entry belongs to the configured memory registry;
- the entry is `available`;
- `owner_enabled` is true;
- `owner_deleted` is false;
- the provider policy is enabled; and
- the entry schema version is inside the allowed provider-policy range.

Deleting an entry is a chain-level tombstone only. It disables the official
Copilot entry and emits `MemoryEntryDeletedEvent`; it does not delete MemWal
records or Walrus blobs.

## Superseded Deployment

The first mainnet deployment is intentionally no longer used by the official
app or SDK:

- Superseded package:
  `0x7cdd38ea428f87867704c87ba7660ab049cc07c8dd055c9f0ef7d2c88d99f8a3`
- Superseded registry object:
  `0x889c974eed4422af55a227ba2bc5a3e6bd8aad940e6c1e9d88aedb22e63166f8`
- Superseded upgrade capability:
  `0x10ab74a56ef611aec472d806361c89fcaf40d23123cbfeba72c918c0f8929aee`

The superseded registry object does not contain `active_entries`. The current
official deployment above should be used for Copilot memory creation, discovery,
deletion, and frontend integration.

## App and SDK Integration

The TypeScript SDK mainnet deployment now includes:

- `packages.memoryRegistry`
- `objects.memoryRegistry`

The official app uses these IDs by default and allows a user to:

- configure MemWal account, delegate key, relayer, and namespace root;
- save explicit Copilot memories to MemWal;
- create a chain `MemoryEntry` for official Copilot discovery;
- delete/tombstone a chain `MemoryEntry` without touching MemWal/Walrus data.

## Verification

Local and mainnet verification completed:

- latest source `sui move test` for `memory_registry`: 7/7 passed, including
  the one-active-entry-per-owner-and-app case
- memory registry package published on mainnet
- `MemoryRegistry` shared object created on mainnet
- `memwal` provider policy enabled on mainnet
- chain reads confirmed `active_entries.size == 0` and
  `provider_policies.size == 1`
- chain reads confirmed `MemoryRegistry.root_id` and
  `MemoryRegistry.governance_vault_id`
- chain reads confirmed the native prompt registry remains initialized and
  bound to the same root/vault
- TypeScript SDK tests and app build were run after integration
