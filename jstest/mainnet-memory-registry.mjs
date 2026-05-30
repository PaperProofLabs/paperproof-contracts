import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { Transaction } from '@mysten/sui/transactions';

import {
  CONTRACTS,
  createClients,
  executeTransaction,
  getEventBySuffix,
  getObjectFields,
  loadAccountsFromEnv,
  writeJson,
} from './paperproof-mainnet-common.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const OUTPUT_DIR = path.join(__dirname, 'artifacts', 'memory-registry');

const MEMORY_REGISTRY_PACKAGE_ID = '0xbe9527ee927c4a6dcb91d5503758cd731d311813cd70d93914f2bf58a36db3d1';
const MEMORY_PROVIDER = 'memwal';

async function createMemoryRegistry(rpcClient, signer) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${MEMORY_REGISTRY_PACKAGE_ID}::memory_registry::create_registry`,
    arguments: [
      tx.pure.id(CONTRACTS.rootId),
      tx.object(CONTRACTS.governanceVaultId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, 'create memory registry', { gasBudget: 100_000_000 });
  const event = getEventBySuffix(executed.result, '::MemoryRegistryCreatedEvent');
  if (!event?.parsedJson) throw new Error('MemoryRegistryCreatedEvent not found.');
  return { ...event.parsedJson, raw: executed.result };
}

async function setProviderPolicy(rpcClient, signer, registryId) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${MEMORY_REGISTRY_PACKAGE_ID}::memory_registry::set_provider_policy`,
    arguments: [
      tx.object(registryId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.pure.string(MEMORY_PROVIDER),
      tx.pure.bool(true),
      tx.pure.u64('1'),
      tx.pure.u64('1'),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, 'set memwal provider policy', { gasBudget: 100_000_000 });
  const event = getEventBySuffix(executed.result, '::ProviderPolicySetEvent');
  if (!event?.parsedJson) throw new Error('ProviderPolicySetEvent not found.');
  return { ...event.parsedJson, raw: executed.result };
}

async function main() {
  const accounts = loadAccountsFromEnv();
  const signer = accounts[3].signer;
  const { rpcClient } = createClients();

  const created = await createMemoryRegistry(rpcClient, signer);
  const registryId = created.registry_id;
  console.log(`Memory registry object: ${registryId}`);

  const policy = await setProviderPolicy(rpcClient, signer, registryId);
  console.log(`Provider policy: ${policy.provider} enabled=${policy.enabled}`);

  const registryFields = (await getObjectFields(rpcClient, registryId)).fields;
  const summary = {
    memoryRegistryPackageId: MEMORY_REGISTRY_PACKAGE_ID,
    memoryRegistryObjectId: registryId,
    provider: MEMORY_PROVIDER,
    transactions: {
      createRegistry: created.raw.digest,
      setProviderPolicy: policy.raw.digest,
    },
    createdEvent: created,
    providerPolicyEvent: policy,
    registryFields,
  };
  const summaryPath = path.join(OUTPUT_DIR, 'mainnet-memory-registry-summary.json');
  await writeJson(summaryPath, summary);
  console.log(`Summary: ${summaryPath}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
