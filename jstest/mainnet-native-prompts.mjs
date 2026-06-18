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
const PROMPT_APP_ID = 'paperproof-app';
const PROMPT_ROUTES = {
  'copilot/global': {
    promptNames: ['copilotGlobalPrompt'],
    role: 'global',
    title: 'PaperProof native prompt: copilot/global',
    description: 'Native PaperProof Copilot global prompt package for the official static app.',
    fileName: 'paperproof-app-copilot-global.paperproof-prompt.json',
  },
  'copilot/memory': {
    promptNames: ['copilotMemoryDescriptorPrompt'],
    role: 'memory_descriptor',
    title: 'PaperProof native prompt: copilot/memory',
    description: 'Native PaperProof Copilot memory descriptor prompt package for the official static app.',
    fileName: 'paperproof-app-copilot-memory.paperproof-prompt.json',
  },
  explore: pagePrompt('explorePrompt', 'explore', 'Explore'),
  type: pagePrompt('typePrompt', 'type', 'Type detail'),
  artifact: pagePrompt('artifactPrompt', 'artifact', 'Artifact detail'),
  'add-version': pagePrompt('addVersionPrompt', 'add-version', 'Add Version'),
  publish: pagePrompt('publishPrompt', 'publish', 'Publish'),
  'publish/preprints': publishPrompt('publishPreprintPrompt', 'preprints', 'Preprint'),
  'publish/blog-posts': publishPrompt('publishBlogPostPrompt', 'blog-posts', 'Blog Post'),
  'publish/technical-reports': publishPrompt('publishTechnicalReportPrompt', 'technical-reports', 'Technical Report'),
  'publish/datasets': publishPrompt('publishDatasetPrompt', 'datasets', 'Dataset'),
  'publish/software-releases': publishPrompt('publishSoftwareReleasePrompt', 'software-releases', 'Software Release'),
  'publish/generic-files': publishPrompt('publishGenericFilePrompt', 'generic-files', 'Generic File'),
  governance: pagePrompt('governancePrompt', 'governance', 'Governance'),
  'create-proposal': pagePrompt('createProposalPrompt', 'create-proposal', 'Create Proposal'),
  proposal: pagePrompt('proposalPrompt', 'proposal', 'Proposal detail'),
  space: pagePrompt('spacePrompt', 'space', 'My Space'),
  docs: pagePrompt('docsPrompt', 'docs', 'Docs'),
  blog: pagePrompt('blogPrompt', 'blog', 'Blog'),
  'blog-post': pagePrompt('blogPrompt', 'blog-post', 'Blog post'),
  forum: pagePrompt('forumPrompt', 'forum', 'Forum'),
  'forum-topic': pagePrompt('forumPrompt', 'forum-topic', 'Forum topic'),
};

const CURRENT_PROMPT_SERIES = {
  'copilot/global': '0x13c99b4811d9b89fd0decd8e9c713bafd639e6af3401a18043aed7e0270044fb',
  'copilot/memory': '0xd378b519436dcfe34b36f716b528b0b12350d08911ee294cd0248f1cd3dada9b',
};

const APP_PROMPT_MANIFEST_PATH = path.join(WORKSPACE_DIR, 'paperproof-app', 'public', 'prompts', 'manifest.json');

function pagePrompt(promptName, routeSlug, label) {
  return {
    promptNames: [promptName],
    role: 'page',
    title: `PaperProof native prompt: ${routeSlug}`,
    description: `Native PaperProof Copilot page prompt package for ${label}.`,
    fileName: `paperproof-app-${routeSlug.replaceAll('/', '-')}.paperproof-prompt.json`,
  };
}

function publishPrompt(promptName, routeSlug, label) {
  return {
    promptNames: ['publishPrompt', promptName],
    role: 'publish_subtype',
    title: `PaperProof native prompt: publish/${routeSlug}`,
    description: `Native PaperProof Copilot publish subtype prompt package for ${label}.`,
    fileName: `paperproof-app-publish-${routeSlug}.paperproof-prompt.json`,
  };
}

function selectedRouteId() {
  const routeArg = process.argv.find((arg) => arg.startsWith('--route='));
  return routeArg ? routeArg.slice('--route='.length) : 'copilot/global';
}

function selectedRouteIds() {
  if (process.argv.includes('--all')) return Object.keys(PROMPT_ROUTES);
  const routesArg = process.argv.find((arg) => arg.startsWith('--routes='));
  if (routesArg) return routesArg.slice('--routes='.length).split(',').map((item) => item.trim()).filter(Boolean);
  return [selectedRouteId()];
}

function shouldAddVersion() {
  return process.argv.includes('--add-version');
}

function extractTemplate(source, constName) {
  const exportedMarker = `export const ${constName} = \``;
  const localMarker = `const ${constName} = \``;
  const marker = source.includes(exportedMarker) ? exportedMarker : localMarker;
  const start = source.indexOf(marker);
  if (start < 0) throw new Error(`${constName} declaration not found.`);
  let i = start + marker.length;
  let output = '';
  while (i < source.length) {
    const ch = source[i];
    if (ch === '`' && source[i - 1] !== '\\') return output;
    output += ch;
    i += 1;
  }
  throw new Error(`${constName} template literal was not closed.`);
}

function extractPrompt(source, routeConfig) {
  return routeConfig.promptNames.map((name) => extractTemplate(source, name)).join('\n\n');
}

function promptPackage(routeId, routeConfig, prompt) {
  return {
    schema_version: 1,
    app_id: PROMPT_APP_ID,
    route_id: routeId,
    role: routeConfig.role,
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
      tx.pure.string(inputTitle(pkg.route_id)),
      tx.pure.string(inputDescription(pkg.route_id)),
      tx.pure.string(inputFileName(pkg.route_id)),
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

async function addPromptGenericFileVersion(rpcClient, signer, pkg, bytes, walrusInfo, seriesId) {
  const hash = `sha256:${await sha256Hex(bytes)}`;
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'add_generic_file_version'),
    arguments: [
      tx.object(CONTRACTS.rootId),
      tx.object(CONTRACTS.typeRegistryId),
      tx.object(seriesId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.object(CONTRACTS.feeManagerId),
      tx.pure.string(inputTitle(pkg.route_id)),
      tx.pure.string(inputDescription(pkg.route_id)),
      tx.pure.string(inputFileName(pkg.route_id)),
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
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, 'add native copilot prompt generic_file version', { gasBudget: 100_000_000 });
  const event = getEventBySuffix(executed.result, '::ArtifactVersionAddedEvent');
  if (!event?.parsedJson) throw new Error('ArtifactVersionAddedEvent not found for prompt generic_file version.');
  return { ...event.parsedJson, series_id: seriesId, raw: executed.result };
}

async function registerPrompt(rpcClient, signer, seriesId, versionId) {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PROMPT_REGISTRY_PACKAGE_ID}::prompt_registry::register_prompt`,
    arguments: [
      tx.object(PROMPT_REGISTRY_OBJECT_ID),
      tx.object(CONTRACTS.governanceVaultId),
      tx.pure.string(PROMPT_APP_ID),
      tx.pure.string(currentRouteId),
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

let currentRouteId = 'copilot/global';

function currentRouteConfig(routeId) {
  const routeConfig = PROMPT_ROUTES[routeId];
  if (!routeConfig) throw new Error(`Unsupported prompt route: ${routeId}`);
  return routeConfig;
}

function inputTitle(routeId) {
  return currentRouteConfig(routeId).title;
}

function inputDescription(routeId) {
  return currentRouteConfig(routeId).description;
}

function inputFileName(routeId) {
  return currentRouteConfig(routeId).fileName;
}

function summaryFileName(routeId) {
  return `mainnet-native-prompts-${routeId.replaceAll('/', '-')}-summary.json`;
}

async function writeMergedAppManifest(entries) {
  let current = {
    schema_version: 1,
    app_id: PROMPT_APP_ID,
    registry_id: PROMPT_REGISTRY_OBJECT_ID,
    entries: [],
  };
  try {
    current = JSON.parse(await fs.readFile(APP_PROMPT_MANIFEST_PATH, 'utf8'));
  } catch {
    // Fresh manifest.
  }
  const byRoute = new Map((current.entries ?? []).map((entry) => [entry.route_id, entry]));
  for (const entry of entries) byRoute.set(entry.route_id, entry);
  const routeOrder = Object.keys(PROMPT_ROUTES);
  const mergedEntries = [...byRoute.values()].sort((a, b) => {
    const ai = routeOrder.indexOf(a.route_id);
    const bi = routeOrder.indexOf(b.route_id);
    if (ai === -1 && bi === -1) return a.route_id.localeCompare(b.route_id);
    if (ai === -1) return 1;
    if (bi === -1) return -1;
    return ai - bi;
  });
  const manifest = {
    schema_version: 1,
    app_id: PROMPT_APP_ID,
    registry_id: PROMPT_REGISTRY_OBJECT_ID,
    entries: mergedEntries,
  };
  await writeJson(APP_PROMPT_MANIFEST_PATH, manifest);
  return manifest;
}

async function main() {
  await fs.mkdir(OUTPUT_DIR, { recursive: true });
  const accounts = loadAccountsFromEnv();
  const signer = accounts[3].signer;
  const { rpcClient } = createClients();

  const source = await fs.readFile(APP_PROMPTS_PATH, 'utf8');
  const routeIds = selectedRouteIds();
  const forceAddVersion = shouldAddVersion();
  const manifestEntries = [];
  const publishedRoutes = [];

  for (const routeId of routeIds) {
    currentRouteId = routeId;
    const routeConfig = currentRouteConfig(currentRouteId);
    const existingSeriesId = CURRENT_PROMPT_SERIES[currentRouteId];
    const addVersion = forceAddVersion || Boolean(existingSeriesId);
    if (addVersion && !existingSeriesId) throw new Error(`No current prompt series configured for route ${currentRouteId}.`);
    const pkg = promptPackage(currentRouteId, routeConfig, extractPrompt(source, routeConfig));
  const bytes = new TextEncoder().encode(`${JSON.stringify(pkg, null, 2)}\n`);
  const localPath = path.join(OUTPUT_DIR, routeConfig.fileName);
  await fs.writeFile(localPath, bytes);

  console.log(`Prompt route: ${currentRouteId}`);
  console.log(`Prompt package bytes: ${bytes.byteLength}`);
  console.log(`Prompt package sha256: ${crypto.createHash('sha256').update(bytes).digest('hex')}`);
  const walrusInfo = await uploadWalrus(bytes, signer);
  console.log(`Walrus blob: ${walrusInfo.blobId}`);
  console.log(`Walrus object: ${walrusInfo.blobObjectId}`);

  const published = addVersion
    ? await addPromptGenericFileVersion(rpcClient, signer, pkg, bytes, walrusInfo, existingSeriesId)
    : await publishPromptGenericFile(rpcClient, signer, pkg, bytes, walrusInfo);
  console.log(`Prompt series: ${published.series_id}`);
  console.log(`Prompt version: ${published.version_id ?? published.new_version_id}`);

  const promptVersionId = published.version_id ?? published.new_version_id;
  const registered = await registerPrompt(rpcClient, signer, published.series_id, promptVersionId);
  console.log(`Registered route: ${registered.route_id}`);

  const registryFields = (await getObjectFields(rpcClient, PROMPT_REGISTRY_OBJECT_ID)).fields;
  const seriesFields = (await getObjectFields(rpcClient, published.series_id)).fields;
  const versionFields = (await getObjectFields(rpcClient, promptVersionId)).fields;

  const summary = {
    promptRegistryPackageId: PROMPT_REGISTRY_PACKAGE_ID,
    promptRegistryObjectId: PROMPT_REGISTRY_OBJECT_ID,
    routeId: currentRouteId,
    operation: addVersion ? 'add-version' : 'publish-series',
    seriesId: published.series_id,
    versionId: promptVersionId,
    walrusBlobId: walrusInfo.blobId,
    walrusBlobObjectId: walrusInfo.blobObjectId,
    contentHash: `sha256:${crypto.createHash('sha256').update(bytes).digest('hex')}`,
    localPromptPackage: localPath,
    transactions: {
      walrusRegister: walrusInfo.registerDigest,
      [addVersion ? 'addGenericFileVersion' : 'publishGenericFile']: published.raw.digest,
      registerPrompt: registered.raw.digest,
    },
    registryFields,
    seriesCurrentVersionId: seriesFields.current_version_id,
    versionHeader: versionFields.header?.fields ?? versionFields.header,
  };
    const routeSummaryPath = path.join(OUTPUT_DIR, summaryFileName(currentRouteId));
    await writeJson(routeSummaryPath, summary);
    const summaryPath = path.join(OUTPUT_DIR, 'mainnet-native-prompts-summary.json');
    await writeJson(summaryPath, summary);
    console.log(`Summary: ${routeSummaryPath}`);
    manifestEntries.push({
      route_id: currentRouteId,
      series_id: published.series_id,
      use_latest: true,
      pinned_version_id: null,
      role: routeConfig.role,
      content_type: PROMPT_CONTENT_TYPE,
    });
    publishedRoutes.push(summary);
  }

  if (manifestEntries.length) {
    await writeMergedAppManifest(manifestEntries);
    const batchSummaryPath = path.join(OUTPUT_DIR, 'mainnet-native-prompts-batch-summary.json');
    await writeJson(batchSummaryPath, {
      promptRegistryPackageId: PROMPT_REGISTRY_PACKAGE_ID,
      promptRegistryObjectId: PROMPT_REGISTRY_OBJECT_ID,
      appPromptManifest: APP_PROMPT_MANIFEST_PATH,
      routeCount: manifestEntries.length,
      routes: publishedRoutes.map((item) => ({
        routeId: item.routeId,
        operation: item.operation,
        seriesId: item.seriesId,
        versionId: item.versionId,
        contentHash: item.contentHash,
        transactions: item.transactions,
      })),
    });
    console.log(`App prompt manifest: ${APP_PROMPT_MANIFEST_PATH}`);
    console.log(`Batch summary: ${batchSummaryPath}`);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
