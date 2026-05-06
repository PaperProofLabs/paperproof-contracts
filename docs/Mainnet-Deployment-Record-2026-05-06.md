# PaperProof Contracts Mainnet Deployment Record

Date:

- 2026-05-06

Operator:

- address: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`

Environment:

- network: `mainnet`
- RPC: `https://fullnode.mainnet.sui.io:443`

Official PPRF references:

- package: `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da`
- type: `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da::pprf::PPRF`

Initial role plan:

- governance authority: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- initial operator: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- fee recipient: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- upgrade authority: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`

Upgrade custody plan:

- place all three package `UpgradeCap` objects into governed `ManagedUpgradeCap`
- current upgrade authority remains the same operator-controlled address above

Pre-deployment notes:

- `governance` depends on the already-published `PPRF` package through the local
  `PPRF-token-contracts` repository and its `Published.toml`
- `comments` depends on `governance`
- `publishing` depends on `governance` and `comments`
- `publishing::init` will create:
  - `PaperRegistry`
  - `GovernanceVault`
  - initial `OperatorPermit`
- governance voting still requires a later explicit creation of:
  - `GovernanceConfig`

Live deployment log:

1. `governance` package published successfully
   - package: `0x5e9624d571464b0edd55bbef88f7d603079f1b5e336873ec853eeaafc76b0ba6`
   - tx digest: `CJ7AgJn9z8fhhpZqKLErdjiDKMSGhNRqGjVM7rX45BHV`
   - `UpgradeCap`: `0x96df4e47862c2babcadb77fbbfc7930bc150e8f0e16a4ce3374fd13076999188`
   - publish gas spent: `122688480` MIST
   - notes:
     - resolved official `PPRF` dependency from the already-published mainnet package
     - published modules include `paperproof_governance::governance` and `paperproof_governance::governance_voting`
2. `comments` package published successfully
   - package: `0x4957dc41c3f5ada9fec450681d6447334d59d21983183cbe1b876287be722097`
   - tx digest: `2mDPWTmz6fHL9VKcLkGx8sEbyEuTLRxN2TsqY3jpep1d`
   - `UpgradeCap`: `0x304d39dc925746d6cd5beaa124b6c3f92ed16731a81ef36b0f745815ac452a71`
   - publish gas spent: `49806280` MIST
   - notes:
     - resolved `paperproof_governance` from the freshly published mainnet governance package
     - resolved `PPRF` from the official mainnet package
3. `publishing` package published successfully
   - package: `0x58f1038ed42a7585a55b860174ec70a96f80625cf2102ff167797454f3ddbd63`
   - tx digest: `GZud6PugkDDwKruMvihQBzBXAAexkGmeVszvwS8k43xS`
   - `UpgradeCap`: `0x90260c112aec857dda4308f23b84a369488810f25dc1279f4e82716e2800c167`
   - publish gas spent: `72663480` MIST
   - notes:
     - `publishing::init` ran automatically during publish
     - created and shared the canonical `PaperRegistry`
     - created and shared the canonical `GovernanceVault`
     - created the initial owned `OperatorPermit`
4. Canonical protocol root objects created and confirmed
   - `PaperRegistry`: `0x7f18b6355da8684918d0d2669261cd04b4796e365c10221151d25318db0a7815`
   - `GovernanceVault`: `0x6073595f4e1bdaa6732fc25818e793bed341c4fb888b562eadaeff8db222f43c`
   - initial `OperatorPermit`: `0xe872f3e9e8048b628c6bf761db6f41baa9b5f6a59e00589d46499254bc3599fe`
   - `publishing::init` roles:
     - governance authority: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
     - active operator: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
     - fee recipient: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
     - upgrade authority: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
5. `GovernanceConfig` created and shared successfully
   - object: `0xb34b875ddf89abdf7253efaa68644e8abd17790ddf097915a72912d12fc89dd9`
   - tx digest: `GNWZcCtXX2j3qDddczHmeECRVAXszjxaVcDAdrWg8p4L`
   - gas spent: `2420280` MIST
   - initialized values:
     - `registry_id`: `0x7f18b6355da8684918d0d2669261cd04b4796e365c10221151d25318db0a7815`
     - `pprf_total_supply`: `10000000000000000000`
     - `proposal_creation_paused`: `false`
     - `proposal_duration_epochs`: `1`
     - `proposer_threshold`: `10000000000000000`
     - `next_proposal_id`: `1`
6. Managed upgrade custody enabled for the `comments` package
   - tx digest: `GeASRAuuYorQBXrGRiDZNSXGjSkCvFM1cfpEDyDbmDmA`
   - `ManagedUpgradeCap`: `0x3a76b2234a4fbc286e62c9b76bc13f80f6f9ab1a7a1c678f084a4e2bc73aac6a`
   - underlying package: `0x4957dc41c3f5ada9fec450681d6447334d59d21983183cbe1b876287be722097`
   - wrapped former `UpgradeCap`: `0x304d39dc925746d6cd5beaa124b6c3f92ed16731a81ef36b0f745815ac452a71`
7. Managed upgrade custody enabled for the `publishing` package
   - tx digest: `HZGaw5M5GVF6Qm6D9Wyx9oDCcReRTvuQswoNZQysfYFL`
   - `ManagedUpgradeCap`: `0x2162225050d58d5e1400a43388c2816006a4f2e831bf719022637c0408e758a2`
   - underlying package: `0x58f1038ed42a7585a55b860174ec70a96f80625cf2102ff167797454f3ddbd63`
   - wrapped former `UpgradeCap`: `0x90260c112aec857dda4308f23b84a369488810f25dc1279f4e82716e2800c167`
8. Managed upgrade custody enabled for the `governance` package
   - tx digest: `3gW2G8QgKktDifHKRCUHmwwWn5n4zpybNUm7ZRC7btvY`
   - `ManagedUpgradeCap`: `0x23d2dd4a798a875ddfacd1b3a9aacd3e65d1c4d1a393f2ccb1f0df6732e8edbe`
   - underlying package: `0x5e9624d571464b0edd55bbef88f7d603079f1b5e336873ec853eeaafc76b0ba6`
   - wrapped former `UpgradeCap`: `0x96df4e47862c2babcadb77fbbfc7930bc150e8f0e16a4ce3374fd13076999188`

Deployment result:

- canonical deployment complete
- canonical governance root objects created
- governed upgrade custody established for all three packages

Frontend/runtime configuration references:

- `PPRF` package: `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da`
- `PPRF` type: `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da::pprf::PPRF`
- `paperproof_governance` package: `0x5e9624d571464b0edd55bbef88f7d603079f1b5e336873ec853eeaafc76b0ba6`
- `paperproof_comments` package: `0x4957dc41c3f5ada9fec450681d6447334d59d21983183cbe1b876287be722097`
- `paperproof_publishing` package: `0x58f1038ed42a7585a55b860174ec70a96f80625cf2102ff167797454f3ddbd63`
- canonical `PaperRegistry`: `0x7f18b6355da8684918d0d2669261cd04b4796e365c10221151d25318db0a7815`
- canonical `GovernanceVault`: `0x6073595f4e1bdaa6732fc25818e793bed341c4fb888b562eadaeff8db222f43c`
- canonical `GovernanceConfig`: `0xb34b875ddf89abdf7253efaa68644e8abd17790ddf097915a72912d12fc89dd9`

Deployment notes for later upgrades:

- all three package `UpgradeCap` objects are now governed via shared `ManagedUpgradeCap` wrappers
- the current `upgrade_authority` remains `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- later package upgrades should follow the governed path:
  - `authorize_managed_upgrade`
  - publish upgraded package with the returned ticket
  - `commit_managed_upgrade`
  - run the appropriate `migrate_*` entry points when needed

End-of-session status:

- remaining gas balance after deployment: approximately `1.38 SUI`
