import 'dotenv/config';

import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { decodeSuiPrivateKey } from '@mysten/sui/cryptography';
import { SuiJsonRpcClient } from '@mysten/sui/jsonRpc';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { Transaction } from '@mysten/sui/transactions';
import { PDFDocument, PDFName, PDFString, StandardFonts, degrees, rgb } from 'pdf-lib';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const ROOT_DIR = __dirname;
export const ARTIFACTS_DIR = path.join(ROOT_DIR, 'artifacts');
export const LOGS_DIR = path.join(ROOT_DIR, 'logs');
export const PAPERS_DIR = path.join(ARTIFACTS_DIR, 'papers');

export const MAINNET = Object.freeze({
  suiRpcUrl: 'https://fullnode.mainnet.sui.io:443',
  suiNetwork: 'mainnet',
  clockObjectId: '0x6',
});

export const CONTRACTS = Object.freeze({
  pprfPackageId: '0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da',
  pprfType:
    '0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da::pprf::PPRF',
  walType:
    '0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL',
  governanceOriginalPackageId: '0x75923624e354789e995537e88afaab698bd405a61f91926e3f8837fb7cc6b5cf',
  governancePackageId: '0xc1ced3b8ae5281eeeb8cdb5527978e294c54f14a7fd8d65e7e9502d4ffffb87e',
  commentsPackageId: '0xaef346fc40bf20af62f4bbbc1608ba2272e80e4ba3d716634026baa589e9aeba',
  publishingPackageId: '0xe67a6956f37c3182354189d9b77ca14058694aad82522da0c6cb91cfddee4782',
  rootId: '0x7dc6c78b276825499a2204b060394e80b81196eb1f77d2036b503a2cca15dd78',
  typeRegistryId: '0x966ffa24d0a96b34267b62c628f39c830afc9de25438b6502835fa8a3815d6b5',
  feeManagerId: '0x7bb8360ea1fa50f923628c929b8726b00eb8968c6a678acde71f97ae146e9249',
  governanceVaultId: '0x0df35aa53ef37f8ca8f6a6280d743effa6e0bfc613c5c6c0a78318ad4a38f875',
  governanceConfigId: '0x7ed018db6b2cd7c32692a1c33543fb90d9c36add1226f93cbeb2a8fb10955dfa',
});

export const EXPECTED_ADDRESSES = Object.freeze({
  addr1: '0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9',
  addr2: '0x4726dee78f1446c6a20b928cf11e11cbbfc478460b7535438d22680f6c8dbb5d',
  addr3: '0x50c1bf938eb0621665ea555e2e8a3ac2debd902e47139a54cd42b19c12d2e44c',
  addr4: '0x8fdd4a2185cc81bc0fef20e56cabe29803ea4afc63d20550ad88cbcafb85dbb6',
});

export const ARTIFACT_TYPES = Object.freeze({
  preprint: 1,
  softwareRelease: 5,
});

export const COMMENTS = Object.freeze({
  treeStatusOpen: 0,
  treeStatusLocked: 1,
  commentStatusActive: 0,
  commentStatusHidden: 1,
  commentStatusDeleted: 2,
});

export const GOVERNANCE = Object.freeze({
  proposalTypeSignal: 2,
  actionSignalFeatureDirection: 102,
  statusActive: 1,
  statusPassed: 2,
  statusRejected: 3,
  statusExecuted: 4,
  statusExpired: 5,
});

export const PPRF_DECIMALS = 9n;
export const ONE_PPRF = 10n ** PPRF_DECIMALS;
export const MIN_LIKE_BALANCE = ONE_PPRF;
export const PROPOSER_THRESHOLD = 10_000_000n * ONE_PPRF;
export const MIN_VOTE_STAKE = 100n * ONE_PPRF;

export function normalizeHexAddress(value) {
  const raw = String(value ?? '').trim().toLowerCase().replace(/^"|"$/g, '');
  const withoutPrefix = raw.startsWith('0x') ? raw.slice(2) : raw.startsWith('x') ? raw.slice(1) : raw;
  return `0x${withoutPrefix.padStart(64, '0')}`;
}

export function contractTarget(packageId, moduleName, functionName) {
  return `${packageId}::${moduleName}::${functionName}`;
}

export async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableError(error) {
  const message = String(error?.message ?? error ?? '').toLowerCase();
  return (
    message.includes('fetch failed') ||
    message.includes('timeout') ||
    message.includes('econnreset') ||
    message.includes('socket hang up') ||
    message.includes('temporarily unavailable') ||
    message.includes('needs to be rebuilt') ||
    message.includes('unavailable for consumption') ||
    message.includes('429') ||
    message.includes('503') ||
    message.includes('504')
  );
}

export async function withRetries(label, fn, options = {}) {
  const attempts = options.attempts ?? 4;
  const baseDelayMs = options.baseDelayMs ?? 1_500;
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt >= attempts || !isRetryableError(error)) throw error;
      await sleep(baseDelayMs * attempt);
    }
  }
  throw lastError;
}

export function createRunId(prefix = 'mainnet-current-smoke') {
  return `${prefix}-${new Date().toISOString().replace(/[:.]/g, '-')}`;
}

export async function ensureRuntimeDirectories() {
  await fs.mkdir(ARTIFACTS_DIR, { recursive: true });
  await fs.mkdir(LOGS_DIR, { recursive: true });
  await fs.mkdir(PAPERS_DIR, { recursive: true });
}

export function loadAccountsFromEnv() {
  return [1, 2, 3, 4].map((index) => {
    const key = `ADDR_${index}`;
    const secretKey = `PRIVATE_KEY_${index}`;
    const expectedAddress = EXPECTED_ADDRESSES[`addr${index}`];
    const address = normalizeHexAddress(process.env[key]);
    const privateKey = process.env[secretKey];
    if (!privateKey) throw new Error(`Missing ${secretKey} in jstest/.env.`);

    const parsed = decodeSuiPrivateKey(privateKey);
    if (parsed.scheme !== 'ED25519') {
      throw new Error(`Unsupported key scheme for ${key}: ${parsed.scheme}.`);
    }
    const signer = Ed25519Keypair.fromSecretKey(parsed.secretKey);
    const signerAddress = normalizeHexAddress(signer.toSuiAddress());
    if (signerAddress !== address) {
      throw new Error(`${key} does not match ${secretKey}; expected ${address}, got ${signerAddress}.`);
    }
    if (address !== normalizeHexAddress(expectedAddress)) {
      throw new Error(`${key} changed unexpectedly; expected ${expectedAddress}, got ${address}.`);
    }

    return {
      key,
      role: index === 4 ? 'custodian' : `participant_${index}`,
      address,
      signer,
    };
  });
}

export function createClients() {
  return {
    rpcClient: new SuiJsonRpcClient({
      url: MAINNET.suiRpcUrl,
      network: MAINNET.suiNetwork,
    }),
  };
}

export function createLogger(runId) {
  const lines = [];
  return {
    write(line = '') {
      const text = String(line);
      lines.push(text);
      console.log(text);
    },
    async flush() {
      const outputPath = path.join(LOGS_DIR, `${runId}.md`);
      await fs.writeFile(outputPath, `${lines.join('\n')}\n`, 'utf8');
      return outputPath;
    },
  };
}

export function formatPprf(rawValue) {
  const value = BigInt(rawValue);
  const whole = value / ONE_PPRF;
  const fraction = value % ONE_PPRF;
  if (fraction === 0n) return `${whole} PPRF`;
  return `${whole}.${fraction.toString().padStart(Number(PPRF_DECIMALS), '0').replace(/0+$/, '')} PPRF`;
}

export function formatMist(rawValue) {
  const value = BigInt(rawValue);
  const whole = value / 1_000_000_000n;
  const fraction = value % 1_000_000_000n;
  return `${whole}.${fraction.toString().padStart(9, '0').replace(/0+$/, '') || '0'} SUI`;
}

export async function sha256Hex(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

export async function readFileBytes(filePath) {
  return new Uint8Array(await fs.readFile(filePath));
}

export async function buildStampedPdf(inputPath, artifactCodeHint, outputDir = PAPERS_DIR) {
  const originalBytes = await fs.readFile(inputPath);
  const pdfDoc = await PDFDocument.load(originalBytes);
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const stamp = `${artifactCodeHint} | Verify on PaperProof`;
  const [r, g, b] = [35, 35, 35].map((value) => value / 255);

  for (const page of pdfDoc.getPages()) {
    const { width, height } = page.getSize();
    const fontSize = 9;
    const textWidth = font.widthOfTextAtSize(stamp, fontSize);
    const x = width - 24;
    const y = Math.max(18, height - 18 - textWidth);
    page.drawText(stamp, {
      x,
      y,
      size: fontSize,
      font,
      color: rgb(r, g, b),
      opacity: 0.45,
      rotate: degrees(90),
    });
    const linkRef = pdfDoc.context.register(pdfDoc.context.obj({
      Type: PDFName.of('Annot'),
      Subtype: PDFName.of('Link'),
      Rect: [x - fontSize - 6, y - 2, x + 4, y + textWidth + 2],
      Border: [0, 0, 0],
      A: { S: PDFName.of('URI'), URI: PDFString.of('https://paperproof.wal.app/') },
    }));
    page.node.addAnnot(linkRef);
  }

  await fs.mkdir(outputDir, { recursive: true });
  const outputPath = path.join(
    outputDir,
    `${path.basename(inputPath, path.extname(inputPath))}.${artifactCodeHint}.paperproof-smoke.pdf`,
  );
  const bytes = await pdfDoc.save();
  await fs.writeFile(outputPath, bytes);
  return fileDescriptor(outputPath, bytes);
}

export async function fileDescriptor(filePath, presetBytes = null) {
  const bytes = presetBytes ?? (await fs.readFile(filePath));
  return {
    filePath,
    fileName: path.basename(filePath),
    bytes: new Uint8Array(bytes),
    size: bytes.length,
    hash: `sha256:${await sha256Hex(bytes)}`,
    shortHash: await sha256Hex(bytes).then((hash) => hash.slice(0, 32)),
  };
}

export async function getObjectResponse(rpcClient, objectId, options = {}) {
  return withRetries(`get object ${objectId}`, () =>
    rpcClient.getObject({
      id: objectId,
      options: {
        showContent: true,
        showOwner: true,
        showPreviousTransaction: true,
        ...options,
      },
    }),
  );
}

export async function getObjectFields(rpcClient, objectId) {
  const response = await getObjectResponse(rpcClient, objectId);
  const fields = response.data?.content?.fields;
  if (!fields) throw new Error(`Object ${objectId} has no Move fields.`);
  return { response, fields };
}

export async function getDynamicFieldObject(rpcClient, parentId, name) {
  return withRetries(`get dynamic field from ${parentId}`, () =>
    rpcClient.getDynamicFieldObject({ parentId, name }),
  );
}

export function parseOptionField(field) {
  if (!field) return null;
  if (typeof field === 'string') return field;
  if (Array.isArray(field)) return field.length ? field[0] : null;
  if (field.vec) return field.vec.length ? field.vec[0] : null;
  if (field.fields?.vec) return field.fields.vec.length ? field.fields.vec[0] : null;
  return null;
}

export async function getRoot(rpcClient) {
  return (await getObjectFields(rpcClient, CONTRACTS.rootId)).fields;
}

export async function getTypeRegistry(rpcClient) {
  return (await getObjectFields(rpcClient, CONTRACTS.typeRegistryId)).fields;
}

export async function getGovernanceVault(rpcClient) {
  return (await getObjectFields(rpcClient, CONTRACTS.governanceVaultId)).fields;
}

export async function getGovernanceConfig(rpcClient) {
  return (await getObjectFields(rpcClient, CONTRACTS.governanceConfigId)).fields;
}

export async function getSeries(rpcClient, seriesId) {
  return (await getObjectFields(rpcClient, seriesId)).fields;
}

export async function getVersionRecord(rpcClient, versionId) {
  return (await getObjectFields(rpcClient, versionId)).fields;
}

export async function getCommentsTree(rpcClient, treeId) {
  return (await getObjectFields(rpcClient, treeId)).fields;
}

export async function getLikesBook(rpcClient, bookId) {
  return (await getObjectFields(rpcClient, bookId)).fields;
}

export async function getCommentNode(rpcClient, treeId, commentId) {
  const tree = await getCommentsTree(rpcClient, treeId);
  const nodesTableId = tree.nodes?.fields?.id?.id ?? tree.nodes?.fields?.id;
  if (!nodesTableId) throw new Error(`Cannot resolve nodes table for tree ${treeId}.`);
  const dynamicField = await getDynamicFieldObject(rpcClient, nodesTableId, {
    type: 'u64',
    value: String(commentId),
  });
  return dynamicField.data?.content?.fields?.value?.fields ?? dynamicField.data?.content?.fields?.value;
}

export async function getProposal(rpcClient, proposalObjectId) {
  return (await getObjectFields(rpcClient, proposalObjectId)).fields;
}

export async function getProposalObjectIdByProposalId(rpcClient, config, proposalId) {
  const tableId = config.proposal_id_to_object?.fields?.id?.id ?? config.proposal_id_to_object?.fields?.id;
  if (!tableId) throw new Error('Cannot resolve GovernanceConfig.proposal_id_to_object table id.');
  const dynamicField = await getDynamicFieldObject(rpcClient, tableId, {
    type: 'u64',
    value: String(proposalId),
  });
  const value = dynamicField.data?.content?.fields?.value;
  if (typeof value === 'string') return value;
  if (value?.fields?.bytes) return normalizeHexAddress(Buffer.from(value.fields.bytes).toString('hex'));
  if (value?.fields?.id) return value.fields.id;
  throw new Error(`Cannot resolve proposal object id for proposal ${proposalId}.`);
}

export function governanceOutcomePreview(totalSupplyRaw, yesVotesRaw, noVotesRaw) {
  const totalSupply = BigInt(totalSupplyRaw);
  const yesVotes = BigInt(yesVotesRaw);
  const noVotes = BigInt(noVotesRaw);
  const remainingVotingSupply = totalSupply - yesVotes - noVotes;
  const passageRuleSatisfied = (yes, no) => yes * 3n >= no * 4n && yes * 10n > totalSupply;
  const deterministicPass = passageRuleSatisfied(yesVotes, noVotes + remainingVotingSupply);
  const deterministicFail = !passageRuleSatisfied(yesVotes + remainingVotingSupply, noVotes);
  return {
    remainingVotingSupply,
    deterministicPass,
    deterministicFail,
    determinable: deterministicPass || deterministicFail,
  };
}

export function governanceOutcomeDeterminable(totalSupplyRaw, yesVotesRaw, noVotesRaw) {
  return governanceOutcomePreview(totalSupplyRaw, yesVotesRaw, noVotesRaw);
}

export function decisiveNoVoteAmount(totalSupplyRaw, yesVotesRaw, noVotesRaw) {
  const totalSupply = BigInt(totalSupplyRaw);
  const yesVotes = BigInt(yesVotesRaw);
  const noVotes = BigInt(noVotesRaw);
  const remainingVotingSupply = totalSupply - yesVotes - noVotes;
  const minimumNoForDeterministicFail = (3n * totalSupply) / 7n + 1n;
  const needed = minimumNoForDeterministicFail > noVotes ? minimumNoForDeterministicFail - noVotes : MIN_VOTE_STAKE + 1n;
  if (needed > remainingVotingSupply) {
    throw new Error(`Cannot make proposal deterministically fail; need ${needed}, remaining voting supply is ${remainingVotingSupply}.`);
  }
  return needed <= MIN_VOTE_STAKE ? MIN_VOTE_STAKE + 1n : needed;
}

export async function getCoinsByType(rpcClient, owner, coinType) {
  const coins = [];
  let cursor = null;
  do {
    const page = await withRetries(`get coins ${coinType} for ${owner}`, () =>
      rpcClient.getCoins({ owner, coinType, cursor }),
    );
    coins.push(...(page.data ?? []));
    cursor = page.hasNextPage ? page.nextCursor : null;
  } while (cursor);
  return coins;
}

export async function getBalanceByType(rpcClient, owner, coinType) {
  return withRetries(`get balance ${coinType} for ${owner}`, () =>
    rpcClient.getBalance({ owner, coinType }),
  );
}

export async function getLargestCoin(rpcClient, owner, coinType) {
  const coins = await getCoinsByType(rpcClient, owner, coinType);
  if (!coins.length) throw new Error(`No ${coinType} coin found for ${owner}.`);
  return [...coins].sort((a, b) => (BigInt(b.balance) > BigInt(a.balance) ? 1 : -1))[0];
}

export async function getCoinAtLeast(rpcClient, owner, coinType, minBalance) {
  const coins = await getCoinsByType(rpcClient, owner, coinType);
  const match = coins
    .filter((coin) => BigInt(coin.balance) >= BigInt(minBalance))
    .sort((a, b) => (BigInt(b.balance) > BigInt(a.balance) ? 1 : -1))[0];
  if (!match) throw new Error(`No ${coinType} coin >= ${minBalance} found for ${owner}.`);
  return match;
}

export async function getCoinsCovering(rpcClient, owner, coinType, amount) {
  const sorted = (await getCoinsByType(rpcClient, owner, coinType)).sort((a, b) =>
    BigInt(b.balance) > BigInt(a.balance) ? 1 : -1,
  );
  const selected = [];
  let total = 0n;
  for (const coin of sorted) {
    selected.push(coin);
    total += BigInt(coin.balance);
    if (total >= BigInt(amount)) return { coins: selected, total };
  }
  throw new Error(`Total ${coinType} balance ${total} is below required ${amount} for ${owner}.`);
}

async function coinArgumentCovering(rpcClient, signer, tx, coinType, amountRaw) {
  const owner = signer.toSuiAddress();
  const single = (await getCoinsByType(rpcClient, owner, coinType))
    .filter((coin) => BigInt(coin.balance) >= BigInt(amountRaw))
    .sort((a, b) => (BigInt(b.balance) > BigInt(a.balance) ? 1 : -1))[0];
  if (single) {
    return BigInt(amountRaw) < BigInt(single.balance)
      ? tx.splitCoins(tx.object(single.coinObjectId), [tx.pure.u64(String(amountRaw))])[0]
      : tx.object(single.coinObjectId);
  }

  const { coins, total } = await getCoinsCovering(rpcClient, owner, coinType, amountRaw);
  const primary = tx.object(coins[0].coinObjectId);
  if (coins.length > 1) {
    tx.mergeCoins(primary, coins.slice(1).map((coin) => tx.object(coin.coinObjectId)));
  }
  return BigInt(amountRaw) < total
    ? tx.splitCoins(primary, [tx.pure.u64(String(amountRaw))])[0]
    : primary;
}

function extractExecutionStatus(result) {
  const status = result.effects?.status;
  if (!status) return { status: 'unknown', error: null };
  if (typeof status.status === 'string') return { status: status.status.toLowerCase(), error: status.error ?? null };
  if (typeof status.$kind === 'string') return { status: status.$kind.toLowerCase(), error: status.error ?? null };
  return { status: 'unknown', error: null };
}

export async function executeTransaction(rpcClient, signer, tx, label, options = {}) {
  const include = {
    showEffects: true,
    showEvents: true,
    showObjectChanges: true,
    showBalanceChanges: true,
  };

  try {
    tx.setSenderIfNotSet(signer.toSuiAddress());
    if (options.gasBudget) tx.setGasBudget(options.gasBudget);
    const result = await withRetries(label, async () => {
      const bytesToSign = await tx.build({ client: rpcClient });
      const { signature, bytes } = await signer.signTransaction(bytesToSign);
      return rpcClient.executeTransactionBlock({
        transactionBlock: bytes,
        signature,
        options: include,
      });
    });
    const normalized = {
      ...result,
      events: result.events ?? [],
      objectChanges: result.objectChanges ?? [],
      balanceChanges: result.balanceChanges ?? [],
    };
    const execution = extractExecutionStatus(normalized);
    if (options.expectFailure) {
      if (execution.status === 'failure') {
        return { expectedFailure: true, result: normalized, error: execution.error };
      }
      throw new Error(`${label} was expected to fail but succeeded with digest ${normalized.digest}.`);
    }
    if (execution.status !== 'success') {
      throw new Error(`${label} failed on-chain: ${execution.error ?? 'unknown error'}`);
    }
    return { result: normalized };
  } catch (error) {
    if (options.expectFailure) {
      return { expectedFailure: true, error: error instanceof Error ? error.message : String(error) };
    }
    throw error;
  }
}

export function getEventBySuffix(result, suffix) {
  return (result.events ?? []).find((event) => event.type?.endsWith(suffix));
}

export function noneSuiPayment(tx) {
  return tx.object.option({ type: '0x2::coin::Coin<0x2::sui::SUI>', value: null });
}

export function noneIdOption(tx) {
  return tx.pure.option('address', null);
}

export function metadataAttribute(tx, key, value) {
  return tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'metadata_attribute'),
    arguments: [tx.pure.string(key), tx.pure.string(value)],
  });
}

export function metadataVector(tx, attributes = []) {
  return tx.makeMoveVec({
    type: `${CONTRACTS.publishingPackageId}::publishing::MetadataAttribute`,
    elements: attributes.map((item) => metadataAttribute(tx, item.key, item.value)),
  });
}

export async function transferCoinByType(rpcClient, signer, coinType, recipient, amountRaw, label = coinType) {
  const tx = new Transaction();
  const coin = await coinArgumentCovering(rpcClient, signer, tx, coinType, amountRaw);
  tx.transferObjects([coin], tx.pure.address(recipient));
  return executeTransaction(rpcClient, signer, tx, `transfer ${amountRaw} ${label} to ${recipient}`);
}

export async function transferSui(rpcClient, signer, recipient, amountMist) {
  const tx = new Transaction();
  const [coin] = tx.splitCoins(tx.gas, [tx.pure.u64(String(amountMist))]);
  tx.transferObjects([coin], tx.pure.address(recipient));
  return executeTransaction(rpcClient, signer, tx, `transfer ${amountMist} MIST to ${recipient}`);
}

export async function publishPreprint(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'publish_preprint'),
    arguments: [
      tx.object(CONTRACTS.rootId),
      tx.object(CONTRACTS.typeRegistryId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.object(CONTRACTS.feeManagerId),
      tx.pure.string(input.title),
      tx.pure.string(input.abstractText),
      tx.pure.vector('string', input.authors),
      tx.pure.vector('string', input.keywords),
      tx.pure.string(input.field),
      tx.pure.string(input.license),
      tx.pure.u64(String(input.pageCount)),
      tx.pure.string(input.contentHash),
      tx.pure.string(input.walrusBlobId),
      tx.pure.string(input.walrusBlobObjectId),
      tx.pure.string(input.contentType),
      metadataVector(tx, input.seriesMetadata),
      metadataVector(tx, input.versionMetadata),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `publish preprint ${input.title}`);
  const event = getEventBySuffix(executed.result, '::ArtifactPublishedEvent');
  if (!event?.parsedJson) throw new Error('ArtifactPublishedEvent not found for preprint publish.');
  return { ...event.parsedJson, raw: executed.result };
}

export async function addPreprintVersion(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'add_preprint_version'),
    arguments: [
      tx.object(CONTRACTS.rootId),
      tx.object(CONTRACTS.typeRegistryId),
      tx.object(input.seriesId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.object(CONTRACTS.feeManagerId),
      tx.pure.string(input.title),
      tx.pure.string(input.abstractText),
      tx.pure.vector('string', input.authors),
      tx.pure.vector('string', input.keywords),
      tx.pure.string(input.field),
      tx.pure.string(input.license),
      tx.pure.u64(String(input.pageCount)),
      tx.pure.string(input.contentHash),
      tx.pure.string(input.walrusBlobId),
      tx.pure.string(input.walrusBlobObjectId),
      tx.pure.string(input.contentType),
      metadataVector(tx, input.versionMetadata),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `add preprint version for ${input.seriesId}`);
  const event = getEventBySuffix(executed.result, '::ArtifactVersionAddedEvent');
  if (!event?.parsedJson) throw new Error('ArtifactVersionAddedEvent not found.');
  return { ...event.parsedJson, raw: executed.result };
}

export async function publishSoftwareRelease(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'publish_software_release'),
    arguments: [
      tx.object(CONTRACTS.rootId),
      tx.object(CONTRACTS.typeRegistryId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.object(CONTRACTS.feeManagerId),
      tx.pure.string(input.projectName),
      tx.pure.string(input.versionName),
      tx.pure.string(input.sourceHash),
      tx.pure.string(input.packageHash),
      tx.pure.string(input.changelog),
      tx.pure.string(input.license),
      tx.pure.string(input.repositoryUrl),
      tx.pure.string(input.contentHash),
      tx.pure.string(input.walrusBlobId),
      tx.pure.string(input.walrusBlobObjectId),
      tx.pure.string(input.contentType),
      metadataVector(tx, input.seriesMetadata),
      metadataVector(tx, input.versionMetadata),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `publish software release ${input.projectName}`);
  const event = getEventBySuffix(executed.result, '::ArtifactPublishedEvent');
  if (!event?.parsedJson) throw new Error('ArtifactPublishedEvent not found for software release.');
  return { ...event.parsedJson, raw: executed.result };
}

export async function updateSeriesMetadata(rpcClient, signer, seriesId, attributes) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'update_series_metadata_extensions'),
    arguments: [tx.object(seriesId), metadataVector(tx, attributes), tx.object(MAINNET.clockObjectId)],
  });
  return executeTransaction(rpcClient, signer, tx, `update series metadata for ${seriesId}`);
}

export async function transferArtifactOwner(rpcClient, signer, seriesId, commentsTreeId, newOwner) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'transfer_artifact_owner'),
    arguments: [tx.object(seriesId), tx.object(commentsTreeId), tx.pure.address(newOwner), tx.object(MAINNET.clockObjectId)],
  });
  return executeTransaction(rpcClient, signer, tx, `transfer artifact owner for ${seriesId}`);
}

export async function addOnchainComment(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'add_onchain_comment'),
    arguments: [
      tx.object(input.treeId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.object(CONTRACTS.feeManagerId),
      tx.pure.u64(String(input.parentCommentId)),
      tx.pure.vector('u8', Array.from(new TextEncoder().encode(input.content))),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `add on-chain comment to ${input.treeId}`);
  const event = getEventBySuffix(executed.result, '::CommentAddedEvent');
  if (!event?.parsedJson) throw new Error('CommentAddedEvent not found.');
  return { ...event.parsedJson, raw: executed.result };
}

export async function addBlobComment(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'add_blob_comment'),
    arguments: [
      tx.object(input.treeId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.object(CONTRACTS.feeManagerId),
      tx.pure.u64(String(input.parentCommentId)),
      tx.pure.vector('u8', Array.from(input.blobIdBytes)),
      tx.pure.option('address', input.blobObjectId ?? null),
      tx.pure.vector('u8', Array.from(input.blobDigestBytes)),
      tx.pure.vector('u8', Array.from(input.previewBytes)),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `add blob comment to ${input.treeId}`);
  const event = getEventBySuffix(executed.result, '::CommentAddedEvent');
  if (!event?.parsedJson) throw new Error('CommentAddedEvent not found.');
  return { ...event.parsedJson, raw: executed.result };
}

export async function likeArtifact(rpcClient, signer, likesBookId) {
  const proofCoin = await getCoinAtLeast(rpcClient, signer.toSuiAddress(), CONTRACTS.pprfType, MIN_LIKE_BALANCE);
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'like_paper'),
    arguments: [tx.object(likesBookId), tx.object(proofCoin.coinObjectId)],
  });
  return executeTransaction(rpcClient, signer, tx, `like using book ${likesBookId}`);
}

export async function unlikeArtifact(rpcClient, signer, likesBookId) {
  const proofCoin = await getCoinAtLeast(rpcClient, signer.toSuiAddress(), CONTRACTS.pprfType, MIN_LIKE_BALANCE);
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'unlike_paper'),
    arguments: [tx.object(likesBookId), tx.object(proofCoin.coinObjectId)],
  });
  return executeTransaction(rpcClient, signer, tx, `unlike using book ${likesBookId}`);
}

export async function setTreeStatus(rpcClient, signer, treeId, status, expectFailure = false) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'set_tree_status'),
    arguments: [tx.object(treeId), tx.pure.u8(status)],
  });
  return executeTransaction(rpcClient, signer, tx, `set tree status ${status}`, { expectFailure });
}

export async function setCommentStatus(rpcClient, signer, treeId, commentId, status, expectFailure = false) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'set_comment_status'),
    arguments: [tx.object(treeId), tx.pure.u64(String(commentId)), tx.pure.u8(status)],
  });
  return executeTransaction(rpcClient, signer, tx, `set comment ${commentId} status ${status}`, { expectFailure });
}

export async function createSignalProposal(rpcClient, signer, input) {
  const tx = new Transaction();
  const stake = await coinArgumentCovering(rpcClient, signer, tx, CONTRACTS.pprfType, input.stakeAmountRaw);
  tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'create_proposal'),
    arguments: [
      tx.object(CONTRACTS.governanceConfigId),
      tx.pure.u8(GOVERNANCE.proposalTypeSignal),
      tx.pure.u8(GOVERNANCE.actionSignalFeatureDirection),
      tx.pure.string(input.title),
      tx.pure.string(input.description),
      tx.pure.u64('0'),
      tx.pure.u64('0'),
      tx.pure.address(input.payloadAddress ?? signer.toSuiAddress()),
      tx.pure.option('address', null),
      tx.pure.vector('u8', Array.from(new TextEncoder().encode(input.payloadText ?? 'mainnet smoke signal'))),
      stake,
    ],
  });
  const executed = await executeTransaction(rpcClient, signer, tx, `create signal proposal ${input.title}`);
  const event = getEventBySuffix(executed.result, '::ProposalCreatedEvent');
  if (!event?.parsedJson) throw new Error('ProposalCreatedEvent not found.');
  return { ...event.parsedJson, raw: executed.result };
}

export async function voteNo(rpcClient, signer, proposalObjectId, amountRaw, expectFailure = false) {
  const tx = new Transaction();
  const voteCoin = await coinArgumentCovering(rpcClient, signer, tx, CONTRACTS.pprfType, amountRaw);
  tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'vote_no'),
    arguments: [tx.object(proposalObjectId), voteCoin],
  });
  return executeTransaction(rpcClient, signer, tx, `vote NO on ${proposalObjectId}`, { expectFailure });
}

export async function resolveProposalEarly(rpcClient, signer, proposalObjectId) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'resolve_proposal_early'),
    arguments: [tx.object(CONTRACTS.governanceConfigId), tx.object(proposalObjectId)],
  });
  return executeTransaction(rpcClient, signer, tx, `resolve proposal early ${proposalObjectId}`);
}

export async function finalizeProposal(rpcClient, signer, proposalObjectId) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'finalize_proposal'),
    arguments: [tx.object(CONTRACTS.governanceConfigId), tx.object(proposalObjectId)],
  });
  return executeTransaction(rpcClient, signer, tx, `finalize proposal ${proposalObjectId}`);
}

export async function claimLockedTokens(rpcClient, signer, proposalObjectId, expectFailure = false) {
  const tx = new Transaction();
  const claimed = tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'claim_locked_tokens'),
    arguments: [tx.object(proposalObjectId)],
  });
  tx.transferObjects([claimed], tx.pure.address(signer.toSuiAddress()));
  return executeTransaction(rpcClient, signer, tx, `claim locked PPRF for ${signer.toSuiAddress()}`, { expectFailure });
}

export async function writeJson(filePath, data) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

export async function writeText(filePath, text) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, text, 'utf8');
}
