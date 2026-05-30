import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { addDelegateKey, createAccount, generateDelegateKey, removeDelegateKey } from '@mysten-incubation/memwal/account';
import { delegateKeyToPublicKey, MemWal } from '@mysten-incubation/memwal';
import { bcs } from '@mysten/sui/bcs';
import { Transaction } from '@mysten/sui/transactions';

import {
  CONTRACTS,
  createClients,
  executeTransaction,
  getDynamicFieldObject,
  getEventBySuffix,
  getObjectFields,
  loadAccountsFromEnv,
  normalizeHexAddress,
  writeJson,
} from './paperproof-mainnet-common.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const OUTPUT_DIR = path.join(__dirname, 'artifacts', 'memory-registry');

const MEMORY_REGISTRY_PACKAGE_ID = '0xbe9527ee927c4a6dcb91d5503758cd731d311813cd70d93914f2bf58a36db3d1';
const MEMORY_REGISTRY_OBJECT_ID = '0x9a5beeb6610b33c06771c4152c039314784437e802e200afd2ce80fb88bdf9e2';
const MEMWAL_PACKAGE_ID = '0xcee7a6fd8de52ce645c38332bde23d4a30fd9426bc4681409733dd50958a24c6';
const MEMWAL_REGISTRY_ID = '0x0da982cefa26864ae834a8a0504b904233d49e20fcc17c373c8bed99c75a7edd';
const MEMWAL_RELAYER = 'https://relayer.memwal.ai';
const TEST_OWNER = '0x8fdd4a2185cc81bc0fef20e56cabe29803ea4afc63d20550ad88cbcafb85dbb6';
const OFFICIAL_APP_ID = 'paperproof-app';
const MEMORY_ID = 'copilot/profile';
const NAMESPACE_ROOT = 'paperproof/copilot';
const PROVIDER = 'memwal';
const DESCRIPTOR_ARTIFACT_CODE = 'PaperProof-generic_file-memory-descriptor';
const DESCRIPTOR_SERIES_ID = '0xd378b519436dcfe34b36f716b528b0b12350d08911ee294cd0248f1cd3dada9b';

function objectIdField(value) {
  if (typeof value === 'string') return normalizeHexAddress(value);
  if (value?.fields?.id?.id) return normalizeHexAddress(value.fields.id.id);
  if (value?.fields?.id) return normalizeHexAddress(value.fields.id);
  if (value?.fields?.bytes) return normalizeHexAddress(Buffer.from(value.fields.bytes).toString('hex'));
  if (value?.id?.id) return normalizeHexAddress(value.id.id);
  if (value?.id) return normalizeHexAddress(value.id);
  return null;
}

function dynamicFieldValueId(response) {
  const value = response?.data?.content?.fields?.value;
  return objectIdField(value);
}

function tableIdField(value) {
  return value?.fields?.id?.id ?? value?.fields?.id ?? value?.id?.id ?? value?.id ?? null;
}

function makeWalletSigner(signer, rpcClient) {
  return {
    address: normalizeHexAddress(signer.toSuiAddress()),
    async signAndExecuteTransaction({ transaction }) {
      const result = await rpcClient.signAndExecuteTransaction({
        signer,
        transaction,
        options: { showEffects: true, showObjectChanges: true },
      });
      await rpcClient.waitForTransaction({ digest: result.digest });
      return { digest: result.digest };
    },
    async signPersonalMessage({ message }) {
      return signer.signPersonalMessage(message);
    },
  };
}

function makeMemWalSuiClient(rpcClient) {
  return {
    ...rpcClient,
    waitForTransaction({ digest, options }) {
      return rpcClient.waitForTransaction({ digest, options });
    },
  };
}

async function loadActiveEntryId(rpcClient, owner, appId) {
  const registry = (await getObjectFields(rpcClient, MEMORY_REGISTRY_OBJECT_ID)).fields;
  const activeEntriesTableId = tableIdField(registry.active_entries);
  if (!activeEntriesTableId) throw new Error('Cannot resolve MemoryRegistry.active_entries table id.');
  const ownerTableField = await getDynamicFieldObject(rpcClient, activeEntriesTableId, {
    type: 'address',
    value: normalizeHexAddress(owner),
  });
  if (ownerTableField.error || !ownerTableField.data) return null;
  const ownerEntriesTableId = dynamicFieldValueId(ownerTableField);
  if (!ownerEntriesTableId) return null;
  const entryField = await getDynamicFieldObject(rpcClient, ownerEntriesTableId, {
    type: '0x1::string::String',
    value: appId,
    bcs: bcs.string().serialize(appId).toBytes(),
  });
  if (entryField.error || !entryField.data) return null;
  return dynamicFieldValueId(entryField);
}

async function loadMemWalAccountId(rpcClient, owner) {
  const registry = (await getObjectFields(rpcClient, MEMWAL_REGISTRY_ID)).fields;
  const accountsTableId = tableIdField(registry.accounts);
  if (!accountsTableId) throw new Error('Cannot resolve MemWal registry accounts table id.');
  const accountField = await getDynamicFieldObject(rpcClient, accountsTableId, {
    type: 'address',
    value: normalizeHexAddress(owner),
  });
  if (accountField.error || !accountField.data) return null;
  return dynamicFieldValueId(accountField);
}

async function createMemoryEntry(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${MEMORY_REGISTRY_PACKAGE_ID}::memory_registry::create_memory_entry`,
    arguments: [
      tx.object(MEMORY_REGISTRY_OBJECT_ID),
      tx.pure.string(input.appId),
      tx.pure.string(MEMORY_ID),
      tx.pure.string(PROVIDER),
      tx.pure.id(input.accountId),
      tx.pure.string(NAMESPACE_ROOT),
      tx.pure.string(DESCRIPTOR_ARTIFACT_CODE),
      tx.pure.id(DESCRIPTOR_SERIES_ID),
      tx.pure.option('address', null),
      tx.pure.bool(true),
      tx.pure.u64(1),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `create memory entry for ${input.appId}`, { gasBudget: 100_000_000 });
  const event = getEventBySuffix(executed.result, '::MemoryEntryCreatedEvent');
  if (!event?.parsedJson) throw new Error('MemoryEntryCreatedEvent not found.');
  return { event: event.parsedJson, digest: executed.result.digest };
}

async function deleteMemoryEntry(rpcClient, signer, entryId) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${MEMORY_REGISTRY_PACKAGE_ID}::memory_registry::delete_own_memory_entry`,
    arguments: [
      tx.object(MEMORY_REGISTRY_OBJECT_ID),
      tx.object(entryId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `delete memory entry ${entryId}`, { gasBudget: 100_000_000 });
  const event = getEventBySuffix(executed.result, '::MemoryEntryDeletedEvent');
  if (!event?.parsedJson) throw new Error('MemoryEntryDeletedEvent not found.');
  return { event: event.parsedJson, digest: executed.result.digest };
}

async function main() {
  const accounts = loadAccountsFromEnv();
  const target = accounts.find((account) => normalizeHexAddress(account.address) === normalizeHexAddress(TEST_OWNER));
  if (!target) throw new Error(`Test owner ${TEST_OWNER} not found in configured accounts.`);
  const signer = target.signer;
  const owner = normalizeHexAddress(signer.toSuiAddress());
  const { rpcClient } = createClients();
  const runId = `agent-memory-e2e-${new Date().toISOString().replace(/[:.]/g, '-')}`;
  const memoryText = `PaperProof Agent Memory E2E marker ${runId}: user prefers concise Chinese answers for memory tests.`;

  const summary = {
    runId,
    owner,
    packageId: MEMORY_REGISTRY_PACKAGE_ID,
    registryObjectId: MEMORY_REGISTRY_OBJECT_ID,
    officialAppId: OFFICIAL_APP_ID,
    steps: {},
  };

  const registryFields = (await getObjectFields(rpcClient, MEMORY_REGISTRY_OBJECT_ID)).fields;
  summary.steps.registryLoaded = {
    version: registryFields.version,
    rootId: registryFields.root_id,
    governanceVaultId: registryFields.governance_vault_id,
    providerPoliciesSize: registryFields.provider_policies?.fields?.size,
    activeEntriesSize: registryFields.active_entries?.fields?.size,
  };

  const officialEntryId = await loadActiveEntryId(rpcClient, owner, OFFICIAL_APP_ID);
  summary.steps.officialActiveEntryBefore = { entryId: officialEntryId };
  const appId = officialEntryId ? `${OFFICIAL_APP_ID}-e2e-${Date.now()}` : OFFICIAL_APP_ID;
  summary.testAppId = appId;
  summary.usedOfficialSlot = appId === OFFICIAL_APP_ID;

  let accountId = await loadMemWalAccountId(rpcClient, owner);
  summary.steps.memwalAccountBefore = { accountId };
  const walletSigner = makeWalletSigner(signer, rpcClient);
  const memwalSuiClient = makeMemWalSuiClient(rpcClient);
  if (!accountId) {
    const created = await createAccount({
      packageId: MEMWAL_PACKAGE_ID,
      registryId: MEMWAL_REGISTRY_ID,
      walletSigner,
      suiClient: memwalSuiClient,
      suiNetwork: 'mainnet',
    });
    accountId = normalizeHexAddress(created.accountId);
    summary.steps.memwalCreateAccount = { digest: created.digest, accountId };
  } else {
    summary.steps.memwalCreateAccount = { skipped: true, reason: 'existing-account' };
  }

  const delegate = await generateDelegateKey();
  const addDelegate = await addDelegateKey({
    packageId: MEMWAL_PACKAGE_ID,
    accountId,
    publicKey: delegate.publicKey,
    label: `PaperProof E2E ${runId}`,
    walletSigner,
    suiClient: memwalSuiClient,
    suiNetwork: 'mainnet',
  });
  summary.steps.memwalAddDelegate = {
    digest: addDelegate.digest,
    publicKey: addDelegate.publicKey,
    suiAddress: addDelegate.suiAddress,
  };

  const memwal = MemWal.create({
    key: delegate.privateKey,
    accountId,
    serverUrl: MEMWAL_RELAYER,
    namespace: `${NAMESPACE_ROOT}/focus`,
  });
  const rememberResult = await memwal.rememberAndWait(memoryText, undefined, { pollIntervalMs: 2_000, timeoutMs: 180_000 });
  summary.steps.memwalRemember = {
    id: rememberResult.id,
    blobId: rememberResult.blob_id,
    owner: rememberResult.owner,
    namespace: rememberResult.namespace,
  };
  const recallResult = await memwal.recall(`Find marker ${runId}`, 5);
  const matchingRecall = (recallResult.results ?? []).find((item) => item.text?.includes(runId));
  if (!matchingRecall) throw new Error('MemWal recall did not return the E2E marker.');
  summary.steps.memwalRecall = {
    total: recallResult.total,
    matched: true,
    matchBlobId: matchingRecall.blob_id,
    matchDistance: matchingRecall.distance,
  };

  const createdEntry = await createMemoryEntry(rpcClient, signer, { appId, accountId });
  const entryId = normalizeHexAddress(createdEntry.event.entry_id);
  summary.steps.createMemoryEntry = { digest: createdEntry.digest, entryId, event: createdEntry.event };
  const entryFields = (await getObjectFields(rpcClient, entryId)).fields;
  summary.steps.loadMemoryEntry = {
    owner: normalizeHexAddress(entryFields.owner),
    appId: entryFields.app_id,
    memoryId: entryFields.memory_id,
    provider: entryFields.provider,
    accountId: normalizeHexAddress(entryFields.account_id),
    namespaceRoot: entryFields.namespace_root,
    artifactCode: entryFields.artifact_code,
    seriesId: normalizeHexAddress(entryFields.series_id),
    useLatest: entryFields.use_latest,
    available: entryFields.available,
    ownerEnabled: entryFields.owner_enabled,
    ownerDeleted: entryFields.owner_deleted,
  };
  if (!entryFields.available || !entryFields.owner_enabled || entryFields.owner_deleted) {
    throw new Error('Created MemoryEntry is not officially usable.');
  }
  const resolvedEntryId = await loadActiveEntryId(rpcClient, owner, appId);
  if (normalizeHexAddress(resolvedEntryId) !== entryId) throw new Error('Active entry index did not resolve to created entry.');
  summary.steps.activeEntryIndexAfterCreate = { entryId: resolvedEntryId };

  const deleted = await deleteMemoryEntry(rpcClient, signer, entryId);
  summary.steps.deleteMemoryEntry = { digest: deleted.digest, event: deleted.event };
  const resolvedAfterDelete = await loadActiveEntryId(rpcClient, owner, appId);
  if (resolvedAfterDelete) throw new Error('Active entry index still exists after delete.');
  summary.steps.activeEntryIndexAfterDelete = { entryId: resolvedAfterDelete };

  const publicKey = await delegateKeyToPublicKey(delegate.privateKey);
  const removed = await removeDelegateKey({
    packageId: MEMWAL_PACKAGE_ID,
    accountId,
    publicKey,
    walletSigner,
    suiClient: memwalSuiClient,
    suiNetwork: 'mainnet',
  });
  summary.steps.memwalRemoveDelegate = { digest: removed.digest };

  summary.status = 'passed';
  const outputPath = path.join(OUTPUT_DIR, `${runId}.json`);
  await writeJson(outputPath, summary);
  console.log(`Agent Memory E2E passed for ${owner}`);
  console.log(`Test app id: ${appId}`);
  console.log(`MemWal account: ${accountId}`);
  console.log(`Remember blob: ${summary.steps.memwalRemember.blobId}`);
  console.log(`Create tx: ${summary.steps.createMemoryEntry.digest}`);
  console.log(`Delete tx: ${summary.steps.deleteMemoryEntry.digest}`);
  console.log(`Summary: ${outputPath}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
