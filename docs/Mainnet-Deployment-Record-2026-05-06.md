# PaperProof Contracts Mainnet Deployment Record

This file is the canonical mainnet deployment record for the current
PaperProof contract system. It intentionally overwrites the earlier blank
record for this date.

## Release

- Deployment date: 2026-05-07 23:40-23:49 Asia/Shanghai
- Release tag: untagged working tree deployment
- Source commit before deployment: `ab7781d0ffaf4666b6679dce5fb35c46b46f2d79`
- Deployer address: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- Network: Sui mainnet
- RPC endpoint: active Sui CLI mainnet environment
- PPRF policy: reused existing mainnet PPRF package; PPRF was not republished

## Package IDs

- `PPRF` package: `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da`
- `PPRF` type: `0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da::pprf::PPRF`
- `paperproof_governance` original package: `0x75923624e354789e995537e88afaab698bd405a61f91926e3f8837fb7cc6b5cf`
- `paperproof_governance` latest package: `0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e`
- `paperproof_comments` package: `0xaef346fc40bf20af62f4bbbc1608ba2272e80e4ba3d716634026baa589e9aeba`
- `paperproof_publishing` package: `0xe67a6956f37c3182354189d9b77ca14058694aad82522da0c6cb91cfddee4782`

## Deployment Transactions

- Governance publish tx: `Cu2svZHd8vURahtpfJ7a7AxWEyXTmcnxkLn9VzJz3mQp`
- Comments publish tx: `F4ytUL3rytWuf75ALU8gEfAcfFmXzn3G3cdAWEXZJGBU`
- Publishing publish and root initialization tx: `GSgK9mHjsWdwmVTfDfdWLwrVeBHXKn43HTa92D42tDNR`
- GovernanceConfig creation and vault binding tx: `DXoa8uRy7vEu1dTJzzgVNYLc8WKLN5ksADjVSPidtBaV`
- Governance v2 upgrade tx: `8TpVmJuCMYwpesBdQmazK4fgfcweihL6vcRZumcjX8Cv`
- GovernanceConfig v2 action migration tx: `9PxfYxXzNkwHqpAgPAkDrhr8pr6DweZZUSpnLRSNiBU6`

## Governance v2 Upgrade

The governance package was upgraded on 2026-05-08 to add
`set_governance_authority`, `GovernanceAuthorityChangedEvent`, and executable
proposal action `ACTION_SET_GOVERNANCE_AUTHORITY`.

- Original package ID: `0x75923624e354789e995537e88afaab698bd405a61f91926e3f8837fb7cc6b5cf`
- Latest package ID: `0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e`
- UpgradeCap version after upgrade: `2`
- GovernanceConfig migration: completed
- Enabled governance actions table size after migration: `17`
- New governance action constant: `15`
- Raw upgrade output: `governance/upgrade-mainnet-v2-2026-05-08.json`
- Raw config migration output: `governance/migrate-config-mainnet-v2-2026-05-08.json`

## UpgradeCap Custody

The real package `UpgradeCap` objects were left owned by the deployer address
after deployment, as requested.

- PPRF existing UpgradeCap: `0xf8b768b6ed2c953a6afd716ddbe5a8b3b2710d4f14610381dd2d4474ede6526b`
- `paperproof_governance` UpgradeCap: `0x2bd93f4408133a7f739d6b73f5bc7d03d9e221aa22a9e4c576b1b6ec916ea658`
- `paperproof_comments` UpgradeCap: `0x3e989e7954a01f93d16aa4d93d8283c4dcb4e7a4976d90c5833c7fcf16b753b3`
- `paperproof_publishing` UpgradeCap: `0x8b3c6058f7d0e7641c958d02b3bb84b98a9c1b45304fc06f67c492b3f19ed143`

## Canonical Publishing Objects

- `PaperProofRoot`: `0x7dc6c78b276825499a2204b060394e80b81196eb1f77d2036b503a2cca15dd78`
- `TypeRegistry`: `0x966ffa24d0a96b34267b62c628f39c830afc9de25438b6502835fa8a3815d6b5`
- `FeeManager`: `0x7bb8360ea1fa50f923628c929b8726b00eb8968c6a678acde71f97ae146e9249`
- Comments tree factory capability: embedded in `PaperProofRoot`
- Governance action executor cap: embedded in `PaperProofRoot`
- `TypeIndex` for `preprint`: `0xcbc3da7cf963765028ee0aec969338b81dbd3fb43b30b768f20e97b1921aea7e`
- `TypeIndex` for `blog_post`: `0x3dc638b61be5cca767712825f3580c54df57ef68f5b1c34d1d01c535a63f8a40`
- `TypeIndex` for `technical_report`: `0x283d86e93cb24d69bdfd803b3db24aa23257943acb79b9980b5dfcf68c54c593`
- `TypeIndex` for `dataset`: `0x83e6c80c35e6a47e6ba48399025f447c0cda44f4bd5106266f2e750c4d60a4d2`
- `TypeIndex` for `software_release`: `0x8d7f183623a68f6651d92c8207e69df3859aaf3523bc324c7bc8fc6056dbaaee`
- `TypeIndex` for `generic_file`: `0xbea92cca6ab20d7a0bea6a69868eb346ff5383197aae11d4d3e45220570a1d15`

## Governance Objects

- `GovernanceVault`: `0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875`
- `GovernanceConfig`: `0x7ed018db6b2cd7c32692a1c33543fb90d9c36add1226f93cbeb2a8fb10955dfa`
- Initial `OperatorPermit` recipient: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- Initial `OperatorPermit` object: `0xbfc867a7a95f6808a42c448fc80f31952752d7faf32bdcd9b7ee8ff86489c634`
- Governance authority: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- Upgrade authority: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`
- Fee recipient: `0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9`

## Governance Configuration

- Proposal creation paused: `false`
- Proposer threshold: `10000000000000000`
- Proposal duration epochs: `1`
- Active proposal ID: none
- Captured `PPRF` total supply: `10000000000000000000`
- Enabled governance actions table size: `17`

## Fee Configuration

- Comments fee level: implicit default `free`
- Artifact fee level for `preprint`: implicit default `free`
- Artifact fee level for `blog_post`: implicit default `free`
- Artifact fee level for `technical_report`: implicit default `free`
- Artifact fee level for `dataset`: implicit default `free`
- Artifact fee level for `software_release`: implicit default `free`
- Artifact fee level for `generic_file`: implicit default `free`

## Binding Verification

- [x] `GovernanceVault.registry_id` equals `PaperProofRoot`
- [x] `GovernanceConfig.registry_id` equals `PaperProofRoot`
- [x] `FeeManager.registry_id` equals `PaperProofRoot`
- [x] root comments tree factory registry getter equals `PaperProofRoot`
- [x] `TypeRegistry.registry_id` equals `PaperProofRoot`
- [x] every `TypeInfo.index_object_id` was emitted for the expected initial `TypeIndex`
- [x] governance executor cap is embedded in `PaperProofRoot`
- [x] `GovernanceVault.governance_config_id` equals `GovernanceConfig`
- [x] published series will record both official `comments_tree_id` and `likes_book_id`

## Smoke Test Transactions

Smoke tests were intentionally deferred until after deployment.

- Publish artifact:
- Verify root-embedded comments tree factory capability used:
- Verify official `CommentsTree` and `LikesBook` bound:
- Add artifact version:
- Add on-chain comment:
- Add blob-backed comment:
- Like and unlike through official `LikesBook`:
- Create proposal:
- Vote yes:
- Finalize proposal:
- Execute proposal:
- Claim locked voting funds:

## Frontend And Indexer Configuration

Clients and indexers should use `PaperProofRoot` as the canonical entry point
for publishing, comments-tree discovery, official `FeeManager`, and official
`GovernanceVault`. Governance indexers should additionally trust only the
`GovernanceConfig` object listed above and its `proposal_id_to_object` table for
official proposal mapping.

- Frontend config commit:
- Indexer config commit:
- Official hostname:
- Walrus site:
- Package/object configuration reviewed by:

## Local Deployment Artifacts

The raw publish/init command outputs were saved locally:

- `governance/publish-mainnet-2026-05-07.json`
- `comments/publish-mainnet-2026-05-07.json`
- `publishing/publish-mainnet-2026-05-07.json`
- `governance/init-governance-config-mainnet-2026-05-07.json`
- `governance/upgrade-mainnet-v2-2026-05-08.json`
- `governance/migrate-config-mainnet-v2-2026-05-08.json`

Previous package publication records were preserved as:

- `governance/Published.previous-mainnet.toml`
- `comments/Published.previous-mainnet.toml`
- `publishing/Published.previous-mainnet.toml`
