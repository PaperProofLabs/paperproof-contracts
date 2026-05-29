import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { SuiGrpcClient } from '@mysten/sui/grpc';
import { Transaction } from '@mysten/sui/transactions';
import { walrus } from '@mysten/walrus';

import {
  CONTRACTS,
  MAINNET,
  contractTarget,
  createClients,
  executeTransaction,
  getEventBySuffix,
  getObjectFields,
  loadAccountsFromEnv,
  metadataVector,
  noneSuiPayment,
  sha256Hex,
  writeJson,
} from './paperproof-mainnet-common.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const WORKSPACE_DIR = path.resolve(__dirname, '..', '..');
const APP_PROMPTS_PATH = path.join(WORKSPACE_DIR, 'paperproof-app', 'src', 'copilot', 'prompts.ts');
const OUTPUT_DIR = path.join(__dirname, 'artifacts', 'native-prompts');

const PROMPT_REGISTRY_PACKAGE_ID = '0x10b9c6e90a896dc3244d047e32724d80de0dc697b5ea12c5fdd8925131ed4c59';
const PROMPT_REGISTRY_OBJECT_ID = '0x14ec45eb83bb1b0eb22c7e885c7c71ea05b1e22dd05e3e1107dcef528600b0da';
const PROMPT_CONTENT_TYPE = 'application/vnd.paperproof.prompt+json';
const PROMPT_ROUTE_ID = 'copilot/global';
const PROMPT_APP_ID = 'paperproof-app';

function extractCopilotGlobalPrompt(source) {
  const marker = 'export const copilotGlobalPrompt = `';
  const start = source.indexOf(marker);
  if (start < 0) throw new Error('copilotGlobalPrompt declaration not found.');
  let i = start + marker.length;
  let output = '';
  while (i < source.length) {
    const ch = source[i];
    if (ch === '`' && source[i - 1] !== '\\') return output;
    output += ch;
    i += 1;
  }
  throw new Error('copilotGlobalPrompt template literal was not closed.');
}

function promptPackage(prompt) {
  return {
    schema_version: 1,
    app_id: PROMPT_APP_ID,
    route_id: PROMPT_ROUTE_ID,
    role: 'global',
    prompt,
    created_at: new Date().toISOString(),
  };
}

async function uploadWalrus(bytes, signer) {
  const suiClient = new SuiGrpcClient({
    network: MAINNET.suiNetwork,
    baseUrl: MAINNET.suiRpcUrl,
  }).$extend(
    walrus({
      wasmUrl: 'https://unpkg.com/@mysten/walrus-wasm@latest/web/walrus_wasm_bg.wasm',
      uploadRelay: {
        host: 'https://upload-relay.mainnet.walrus.space',
        sendTip: { max: 3_000_000 },
      },
    }),
  );

  const flow = suiClient.walrus.writeBlobFlow({ blob: bytes });
  const encoded = await flow.encode();
  const registered = await flow.executeRegister({
    signer,
    epochs: 1,
    owner: signer.toSuiAddress(),
    deletable: false,
  });
  await flow.upload({ digest: registered.txDigest });
  const certified = await flow.executeCertify({ signer });
  return {
    blobId: certified.blobId || registered.blobId || encoded.blobId,
    blobObjectId: certified.blobObjectId || registered.blobObjectId,
    registerDigest: registered.txDigest,
  };
}

async function publishPromptGenericFile(rpcClient, signer, pkg, bytes, walrusInfo) {
  const hash = `sha256:${await sha256Hex(bytes)}`;
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'publish_generic_file'),
    arguments: [
      tx.object(CONTRACTS.rootId),
      tx.object(CONTRACTS.typeRegistryId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.object(CONTRACTS.feeManagerId),
      tx.pure.string('PaperProof native prompt: copilot/global'),
      tx.pure.string('Native PaperProof Copilot global prompt package for the official static app.'),
      tx.pure.string('paperproof-app-copilot-global.paperproof-prompt.json'),
      tx.pure.u64(String(bytes.byteLength)),
      tx.pure.string('PaperProof Interface Source-Available License'),
      tx.pure.string(hash),
      tx.pure.string(walrusInfo.blobId),
      tx.pure.string(walrusInfo.blobObjectId),
      tx.pure.string(PROMPT_CONTENT_TYPE),
      metadataVector(tx, [
        { key: 'app_kind', value: 'native_prompt' },
        { key: 'app_id', value: pkg.app_id },
        { key: 'route_id', value: pkg.route_id },
        { key: 'prompt_role', value: pkg.role },
      ]),
      metadataVector(tx, [{ key: 'schema_version', value: String(pkg.schema_version) }]),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, 'publish native copilot prompt generic_file', { gasBudget: 100_000_000 });
  const event = getEventBySuffix(executed.result, '::ArtifactPublishedEvent');
  if (!event?.parsedJson) throw new Error('ArtifactPublishedEvent not found for prompt generic_file.');
  return { ...event.parsedJson, raw: executed.result };
}

async function registerPrompt(rpcClient, signer, seriesId, versionId) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PROMPT_REGISTRY_PACKAGE_ID}::prompt_registry::register_prompt`,
    arguments: [
      tx.object(PROMPT_REGISTRY_OBJECT_ID),
      tx.object(CONTRACTS.governanceVaultId),
      tx.pure.string(PROMPT_APP_ID),
      tx.pure.string(PROMPT_ROUTE_ID),
      tx.pure.id(seriesId),
      tx.pure.option('address', versionId),
      tx.pure.bool(true),
      tx.pure.u64('1'),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, 'register native copilot prompt', { gasBudget: 100_000_000 });
  const event = getEventBySuffix(executed.result, '::PromptRegisteredEvent');
  if (!event?.parsedJson) throw new Error('PromptRegisteredEvent not found.');
  return { ...event.parsedJson, raw: executed.result };
}

async function main() {
  await fs.mkdir(OUTPUT_DIR, { recursive: true });
  const accounts = loadAccountsFromEnv();
  const signer = accounts[3].signer;
  const { rpcClient } = createClients();

  const source = await fs.readFile(APP_PROMPTS_PATH, 'utf8');
  const pkg = promptPackage(extractCopilotGlobalPrompt(source));
  const bytes = new TextEncoder().encode(`${JSON.stringify(pkg, null, 2)}\n`);
  const localPath = path.join(OUTPUT_DIR, 'paperproof-app-copilot-global.paperproof-prompt.json');
  await fs.writeFile(localPath, bytes);

  console.log(`Prompt package bytes: ${bytes.byteLength}`);
  console.log(`Prompt package sha256: ${crypto.createHash('sha256').update(bytes).digest('hex')}`);
  const walrusInfo = await uploadWalrus(bytes, signer);
  console.log(`Walrus blob: ${walrusInfo.blobId}`);
  console.log(`Walrus object: ${walrusInfo.blobObjectId}`);

  const published = await publishPromptGenericFile(rpcClient, signer, pkg, bytes, walrusInfo);
  console.log(`Prompt series: ${published.series_id}`);
  console.log(`Prompt version: ${published.version_id}`);

  const registered = await registerPrompt(rpcClient, signer, published.series_id, published.version_id);
  console.log(`Registered route: ${registered.route_id}`);

  const registryFields = (await getObjectFields(rpcClient, PROMPT_REGISTRY_OBJECT_ID)).fields;
  const seriesFields = (await getObjectFields(rpcClient, published.series_id)).fields;
  const versionFields = (await getObjectFields(rpcClient, published.version_id)).fields;

  const summary = {
    promptRegistryPackageId: PROMPT_REGISTRY_PACKAGE_ID,
    promptRegistryObjectId: PROMPT_REGISTRY_OBJECT_ID,
    routeId: PROMPT_ROUTE_ID,
    seriesId: published.series_id,
    versionId: published.version_id,
    walrusBlobId: walrusInfo.blobId,
    walrusBlobObjectId: walrusInfo.blobObjectId,
    contentHash: `sha256:${crypto.createHash('sha256').update(bytes).digest('hex')}`,
    localPromptPackage: localPath,
    transactions: {
      walrusRegister: walrusInfo.registerDigest,
      publishGenericFile: published.raw.digest,
      registerPrompt: registered.raw.digest,
    },
    registryFields,
    seriesCurrentVersionId: seriesFields.current_version_id,
    versionHeader: versionFields.header?.fields ?? versionFields.header,
  };
  const summaryPath = path.join(OUTPUT_DIR, 'mainnet-native-prompts-summary.json');
  await writeJson(summaryPath, summary);
  console.log(`Summary: ${summaryPath}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
