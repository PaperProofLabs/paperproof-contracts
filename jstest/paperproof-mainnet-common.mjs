import 'dotenv/config';

import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { PDFDocument, PDFName, PDFString, StandardFonts, degrees, rgb } from 'pdf-lib';
import { SuiGrpcClient } from '@mysten/sui/grpc';
import { SuiJsonRpcClient } from '@mysten/sui/jsonRpc';
import { Transaction } from '@mysten/sui/transactions';
import { decodeSuiPrivateKey } from '@mysten/sui/cryptography';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { walrus } from '@mysten/walrus';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export const ROOT_DIR = __dirname;
export const ARTIFACTS_DIR = path.join(ROOT_DIR, 'artifacts');
export const LOGS_DIR = path.join(ROOT_DIR, 'logs');
export const PAPERS_DIR = path.join(ARTIFACTS_DIR, 'papers');

export const MAINNET = Object.freeze({
  suiRpcUrl: 'https://fullnode.mainnet.sui.io:443',
  suiNetwork: 'mainnet',
  walrusWasmUrl: 'https://unpkg.com/@mysten/walrus-wasm@latest/web/walrus_wasm_bg.wasm',
  walrusUploadRelayUrl: 'https://upload-relay.mainnet.walrus.space',
  walrusDownloadBaseUrl: 'https://aggregator.walrus-mainnet.walrus.space',
  walrusDefaultEpochs: 1,
  walrusDeletable: false,
  walrusSharedBlob: false,
  walrusUploadRelayTipMaxMist: 3_000_000,
  clockObjectId: '0x6',
});

export const CONTRACTS = Object.freeze({
  pprfPackageId: '0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da',
  pprfType:
    '0x5d2ec9829a9e116de7c2008281a90b96690beb2252af120ad05a25fe13fae0da::pprf::PPRF',
  walType:
    '0x356a26eb9e012a68958082340d4c4116e7f55615cf27affcff209cf0ae544f59::wal::WAL',
  governancePackageId: '0x5e9624d571464b0edd55bbef88f7d603079f1b5e336873ec853eeaafc76b0ba6',
  commentsPackageId: '0x4957dc41c3f5ada9fec450681d6447334d59d21983183cbe1b876287be722097',
  publishingPackageId: '0x58f1038ed42a7585a55b860174ec70a96f80625cf2102ff167797454f3ddbd63',
  paperRegistryId: '0x7f18b6355da8684918d0d2669261cd04b4796e365c10221151d25318db0a7815',
  governanceVaultId: '0x6073595f4e1bdaa6732fc25818e793bed341c4fb888b562eadaeff8db222f43c',
  governanceConfigId: '0xb34b875ddf89abdf7253efaa68644e8abd17790ddf097915a72912d12fc89dd9',
});

export const EXPECTED_ADDRESSES = Object.freeze({
  addr1: '0x4ee4f1d5fda8efc8f29f7051dff8807c8c9e4fdeadbe519fdf831aa3647235e9',
  addr2: '0x4726dee78f1446c6a20b928cf11e11cbbfc478460b7535438d22680f6c8dbb5d',
  addr3: '0x50c1bf938eb0621665ea555e2e8a3ac2debd902e47139a54cd42b19c12d2e44c',
});

export const GOVERNANCE = Object.freeze({
  proposalTypeExecutable: 1,
  proposalTypeSignal: 2,
  actionSetCommentsFeeLevel: 2,
});

export const COMMENTS = Object.freeze({
  treeStatusOpen: 0,
  treeStatusLocked: 1,
  commentStatusActive: 0,
  commentStatusHidden: 1,
});

export const PPRF_DECIMALS = 9n;
export const ONE_PPRF = 10n ** PPRF_DECIMALS;
export const PROPOSER_THRESHOLD = 10_000_000n * ONE_PPRF;
export const MIN_LIKE_BALANCE = ONE_PPRF;

export function normalizeHexAddress(value) {
  const raw = String(value).trim().toLowerCase();
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
    message.includes('429') ||
    message.includes('503') ||
    message.includes('504')
  );
}

export async function withRetries(label, fn, options = {}) {
  const attempts = options.attempts ?? 4;
  const baseDelayMs = options.baseDelayMs ?? 1_500;
  let lastError = null;

  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt >= attempts || !isRetryableError(error)) {
        throw error;
      }

      await sleep(baseDelayMs * attempt);
    }
  }

  throw lastError ?? new Error(`${label} failed unexpectedly.`);
}

export function buildPaperProofLink(paperCode) {
  return `https://paperproof.wal.app/#/p/${encodeURIComponent(paperCode)}`;
}

export function createRunId(prefix = 'mainnet-functional-test') {
  const now = new Date().toISOString().replace(/[:.]/g, '-');
  return `${prefix}-${now}`;
}

export async function ensureRuntimeDirectories() {
  await fs.mkdir(ARTIFACTS_DIR, { recursive: true });
  await fs.mkdir(LOGS_DIR, { recursive: true });
  await fs.mkdir(PAPERS_DIR, { recursive: true });
}

export function loadAccountsFromEnv() {
  const accountEntries = [
    {
      key: 'ADDR_1',
      secretKey: 'PRIVATE_KEY_1',
      expectedAddress: EXPECTED_ADDRESSES.addr1,
      role: 'founder',
    },
    {
      key: 'ADDR_2',
      secretKey: 'PRIVATE_KEY_2',
      expectedAddress: EXPECTED_ADDRESSES.addr2,
      role: 'small_holder',
    },
    {
      key: 'ADDR_3',
      secretKey: 'PRIVATE_KEY_3',
      expectedAddress: EXPECTED_ADDRESSES.addr3,
      role: 'new_holder',
    },
  ];

  return accountEntries.map((entry) => {
    const address = normalizeHexAddress(process.env[entry.key]);
    const privateKey = process.env[entry.secretKey];

    if (!address || !privateKey) {
      throw new Error(`Missing ${entry.key} or ${entry.secretKey} in .env`);
    }

    const parsed = decodeSuiPrivateKey(privateKey);
    if (parsed.scheme !== 'ED25519') {
      throw new Error(`Unsupported private key scheme for ${entry.key}: ${parsed.scheme}`);
    }

    const signer = Ed25519Keypair.fromSecretKey(parsed.secretKey);
    const signerAddress = signer.toSuiAddress();

    if (normalizeHexAddress(signerAddress) !== normalizeHexAddress(address)) {
      throw new Error(
        `${entry.key} does not match the provided private key. Expected ${address}, got ${signerAddress}.`,
      );
    }

    if (normalizeHexAddress(address) !== normalizeHexAddress(entry.expectedAddress)) {
      throw new Error(
        `${entry.key} in .env does not match the expected deployment address ${entry.expectedAddress}.`,
      );
    }

    return {
      ...entry,
      address,
      signer,
    };
  });
}

export function createClients() {
  const rpcClient = new SuiJsonRpcClient({
    url: MAINNET.suiRpcUrl,
    network: MAINNET.suiNetwork,
  });

  const walrusClient = new SuiGrpcClient({
    network: MAINNET.suiNetwork,
    baseUrl: MAINNET.suiRpcUrl,
  }).$extend(
    walrus({
      wasmUrl: MAINNET.walrusWasmUrl,
      uploadRelay: {
        host: MAINNET.walrusUploadRelayUrl,
        sendTip: {
          max: MAINNET.walrusUploadRelayTipMaxMist,
        },
      },
    }),
  );

  return {
    rpcClient,
    walrusClient,
  };
}

export function createLogger(runId) {
  const lines = [];

  function write(line = '') {
    const text = String(line);
    lines.push(text);
    console.log(text);
  }

  async function flush() {
    const outputPath = path.join(LOGS_DIR, `${runId}.md`);
    await fs.writeFile(outputPath, `${lines.join('\n')}\n`, 'utf8');
    return outputPath;
  }

  return {
    write,
    flush,
  };
}

export function formatPprf(rawValue) {
  const value = BigInt(rawValue);
  const whole = value / ONE_PPRF;
  const fraction = value % ONE_PPRF;
  if (fraction === 0n) {
    return `${whole} PPRF`;
  }

  const fractionText = fraction.toString().padStart(Number(PPRF_DECIMALS), '0').replace(/0+$/, '');
  return `${whole}.${fractionText} PPRF`;
}

export async function sha256Hex(bytes) {
  return crypto.createHash('sha256').update(bytes).digest('hex');
}

export async function sha256Bytes(bytes) {
  return new Uint8Array(crypto.createHash('sha256').update(bytes).digest());
}

export async function readFileBytes(filePath) {
  return new Uint8Array(await fs.readFile(filePath));
}

export async function watermarkPdfFile(inputPath, paperCode, outputDir = PAPERS_DIR) {
  const originalBytes = await fs.readFile(inputPath);
  const pdfDoc = await PDFDocument.load(originalBytes);
  const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const pages = pdfDoc.getPages();
  const [r, g, b] = [35, 35, 35].map((value) => value / 255);

  pages.forEach((page, index) => {
    const { width, height } = page.getSize();
    const stamp = index === 0 ? `${paperCode} | Verify on PaperProof` : paperCode;
    const fontSize = index === 0 ? 10 : 9;
    const textWidth = font.widthOfTextAtSize(stamp, fontSize);
    const x = width - 28;
    const y = Math.max(18, height - 18 - textWidth);

    page.drawText(stamp, {
      x,
      y,
      size: fontSize,
      font,
      color: rgb(r, g, b),
      opacity: 0.45,
      rotate: degrees(90),
      maxWidth: height - 40,
    });

    addStampLinkAnnotation(pdfDoc, page, {
      url: buildPaperProofLink(paperCode),
      x,
      y,
      fontSize,
      textWidth,
    });
  });

  const stampedBytes = await pdfDoc.save();
  await fs.mkdir(outputDir, { recursive: true });

  const baseName = path.basename(inputPath, path.extname(inputPath));
  const outputPath = path.join(outputDir, `${baseName}.${paperCode}.originpaper.pdf`);
  await fs.writeFile(outputPath, stampedBytes);

  return validatePdfFile(outputPath, stampedBytes);
}

function addStampLinkAnnotation(pdfDoc, page, { url, x, y, fontSize, textWidth }) {
  const linkAnnotation = pdfDoc.context.obj({
    Type: PDFName.of('Annot'),
    Subtype: PDFName.of('Link'),
    Rect: [x - fontSize - 6, y - 2, x + 4, y + textWidth + 2],
    Border: [0, 0, 0],
    A: {
      S: PDFName.of('URI'),
      URI: PDFString.of(url),
    },
  });

  const linkRef = pdfDoc.context.register(linkAnnotation);
  page.node.addAnnot(linkRef);
}

export async function validatePdfFile(filePath, presetBytes = null) {
  const bytes = presetBytes ?? (await fs.readFile(filePath));
  const pdfDoc = await PDFDocument.load(bytes);

  return {
    filePath,
    fileName: path.basename(filePath),
    bytes: new Uint8Array(bytes),
    fileHash: `sha256:${await sha256Hex(bytes)}`,
    fileSize: bytes.length,
    pageCount: pdfDoc.getPageCount(),
  };
}

export async function uploadFileToWalrus(walrusClient, signer, ownerAddress, filePath) {
  const bytes = await readFileBytes(filePath);
  const flow = walrusClient.walrus.writeBlobFlow({ blob: bytes });
  const encoded = await flow.encode();
  const registered = await flow.executeRegister({
    signer,
    epochs: MAINNET.walrusDefaultEpochs,
    owner: ownerAddress,
    deletable: MAINNET.walrusDeletable,
  });
  const uploaded = await flow.upload({ digest: registered.txDigest });
  const certified = await flow.executeCertify({ signer });
  const blobDetails = await getWalrusBlobDetails(
    walrusClient,
    certified.blobObjectId ?? registered.blobObjectId,
    encoded.blobId,
  );

  return {
    encoded,
    registered,
    uploaded,
    certified,
    ...blobDetails,
  };
}

export async function uploadTextBlobToWalrus(walrusClient, signer, ownerAddress, text) {
  const bytes = new TextEncoder().encode(text);
  const flow = walrusClient.walrus.writeBlobFlow({ blob: bytes });
  const encoded = await flow.encode();
  const registered = await flow.executeRegister({
    signer,
    epochs: MAINNET.walrusDefaultEpochs,
    owner: ownerAddress,
    deletable: MAINNET.walrusDeletable,
  });
  const uploaded = await flow.upload({ digest: registered.txDigest });
  const certified = await flow.executeCertify({ signer });

  return {
    encoded,
    registered,
    uploaded,
    certified,
    blobIdBytes: new TextEncoder().encode(encoded.blobId),
    blobDigestBytes: await sha256Bytes(bytes),
    previewBytes: bytes.slice(0, Math.min(bytes.length, 96)),
    textBytes: bytes,
  };
}

export async function getWalrusBlobDetails(client, blobObjectId, blobId) {
  const response = await withRetries(`get walrus blob details ${blobObjectId}`, () =>
    client.getObject({
      objectId: blobObjectId,
      include: {
        content: true,
      },
    }),
  );

  const fields = response.object?.content?.fields ?? response.data?.content?.fields ?? {};
  const storage = fields.storage?.fields ?? fields.storage ?? {};

  return {
    walrusBlobId: blobId,
    walrusBlobObjectId: blobObjectId,
    storageEndEpoch: Number(storage.end_epoch ?? storage.endEpoch ?? 0),
    isSharedBlob: Boolean(fields.is_shared_blob ?? fields.isSharedBlob ?? MAINNET.walrusSharedBlob),
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
  if (!fields) {
    throw new Error(`Object ${objectId} has no Move fields in RPC response.`);
  }
  return {
    response,
    fields,
  };
}

export async function getDynamicFieldObject(rpcClient, parentId, name) {
  return withRetries(`get dynamic field ${parentId}`, () =>
    rpcClient.getDynamicFieldObject({
      parentId,
      name,
    }),
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

export async function getGovernanceVault(rpcClient) {
  const { fields } = await getObjectFields(rpcClient, CONTRACTS.governanceVaultId);
  return fields;
}

export async function getGovernanceConfig(rpcClient) {
  const { fields } = await getObjectFields(rpcClient, CONTRACTS.governanceConfigId);
  return fields;
}

export async function getPaperRegistry(rpcClient) {
  const { fields } = await getObjectFields(rpcClient, CONTRACTS.paperRegistryId);
  return fields;
}

export async function getPaperRecord(rpcClient, recordId) {
  const { fields } = await getObjectFields(rpcClient, recordId);
  return fields;
}

export async function getPaperVersion(rpcClient, versionId) {
  const { fields } = await getObjectFields(rpcClient, versionId);
  return fields;
}

export async function getCommentsTree(rpcClient, treeId) {
  const { fields } = await getObjectFields(rpcClient, treeId);
  return fields;
}

export async function getCommentNode(rpcClient, treeId, commentId) {
  const tree = await getCommentsTree(rpcClient, treeId);
  const nodesTableId = tree.nodes?.fields?.id?.id;
  if (!nodesTableId) {
    throw new Error(`Could not resolve comments nodes table for tree ${treeId}.`);
  }

  const dynamicField = await getDynamicFieldObject(rpcClient, nodesTableId, {
    type: 'u64',
    value: String(commentId),
  });

  return dynamicField.data?.content?.fields?.value?.fields ?? dynamicField.data?.content?.fields?.value;
}

export async function getProposal(rpcClient, proposalObjectId) {
  const { fields } = await getObjectFields(rpcClient, proposalObjectId);
  return fields;
}

export async function getCoinsByType(rpcClient, owner, coinType) {
  const page = await withRetries(`get coins ${coinType} for ${owner}`, () =>
    rpcClient.getCoins({
      owner,
      coinType,
    }),
  );

  return page.data ?? [];
}

export async function getBalanceByType(rpcClient, owner, coinType) {
  return withRetries(`get balance ${coinType} for ${owner}`, () =>
    rpcClient.getBalance({
      owner,
      coinType,
    }),
  );
}

export async function getLargestCoin(rpcClient, owner, coinType) {
  const coins = await getCoinsByType(rpcClient, owner, coinType);
  if (!coins.length) {
    throw new Error(`No ${coinType} coin objects found for ${owner}.`);
  }

  return [...coins].sort((left, right) => BigInt(right.balance) > BigInt(left.balance) ? 1 : -1)[0];
}

export async function getCoinAtLeast(rpcClient, owner, coinType, minBalance) {
  const coins = await getCoinsByType(rpcClient, owner, coinType);
  const match = coins
    .filter((coin) => BigInt(coin.balance) >= BigInt(minBalance))
    .sort((left, right) => BigInt(right.balance) > BigInt(left.balance) ? 1 : -1)[0];

  if (!match) {
    throw new Error(`No ${coinType} coin with balance >= ${minBalance} for ${owner}.`);
  }

  return match;
}

function extractExecutionStatus(result) {
  const status = result.effects?.status;
  if (!status) return { status: 'unknown', error: null };
  if (typeof status.status === 'string') {
    return { status: status.status.toLowerCase(), error: status.error ?? null };
  }
  if (typeof status.$kind === 'string') {
    return { status: status.$kind.toLowerCase(), error: status.error ?? null };
  }
  return { status: 'unknown', error: null };
}

export async function executeTransaction(rpcClient, signer, tx, label, options = {}) {
  const include = {
    showEffects: true,
    showEvents: true,
    showObjectChanges: true,
    showBalanceChanges: true,
    ...(options.showRawInput ? { showInput: true } : {}),
  };

  try {
    let transactionBytes;
    if (tx instanceof Uint8Array) {
      transactionBytes = tx;
    } else {
      tx.setSenderIfNotSet(signer.toSuiAddress());
      transactionBytes = await tx.build({ client: rpcClient });
    }

    const { signature, bytes } = await signer.signTransaction(transactionBytes);
    const result = await withRetries(label, () =>
      rpcClient.executeTransactionBlock({
        transactionBlock: bytes,
        signature,
        options: include,
      }),
    );

    const normalized = {
      ...result,
      digest: result.digest,
      events: result.events ?? [],
      objectChanges: result.objectChanges ?? [],
      balanceChanges: result.balanceChanges ?? [],
      effects: result.effects ?? null,
    };

    const execution = extractExecutionStatus(normalized);
    if (options.expectFailure) {
      if (execution.status === 'failure') {
        return {
          ok: false,
          expectedFailure: true,
          result: normalized,
          error: execution.error,
        };
      }

      throw new Error(`${label} was expected to fail but succeeded with digest ${normalized.digest}.`);
    }

    if (execution.status !== 'success') {
      throw new Error(`${label} failed on-chain: ${execution.error ?? 'unknown execution error'}`);
    }

    try {
      await withRetries(`wait for transaction ${normalized.digest}`, () =>
        rpcClient.waitForTransaction({
          digest: normalized.digest,
          options: {
            showEffects: true,
          },
          timeout: 60_000,
          pollInterval: 1_500,
        }),
      );
    } catch {
      // The transaction already executed successfully; continue even if waitForTransaction
      // hits an RPC hiccup.
    }

    return {
      ok: true,
      expectedFailure: false,
      result: normalized,
      error: null,
    };
  } catch (error) {
    if (options.expectFailure) {
      return {
        ok: false,
        expectedFailure: true,
        result: null,
        error: error instanceof Error ? error.message : String(error),
      };
    }

    throw new Error(`${label} threw before a successful on-chain result: ${error instanceof Error ? error.message : String(error)}`);
  }
}

export function getEventBySuffix(result, suffix) {
  return (result.events ?? []).find((event) => event.type?.endsWith(suffix));
}

export function buildNoneObjectOption(tx, type) {
  return tx.object.option({
    type,
    value: null,
  });
}

export function buildNonePureOption(tx, type) {
  return tx.pure(`option<${type}>`, null);
}

export async function transferPprf(rpcClient, signer, recipient, amountRaw) {
  const sourceCoin = await getLargestCoin(rpcClient, signer.toSuiAddress(), CONTRACTS.pprfType);
  const tx = new Transaction();
  const [transferCoin] = tx.splitCoins(tx.object(sourceCoin.coinObjectId), [tx.pure.u64(String(amountRaw))]);
  tx.transferObjects([transferCoin], tx.pure.address(recipient));
  return executeTransaction(rpcClient, signer, tx, `transfer ${formatPprf(amountRaw)} to ${recipient}`);
}

export async function transferCoinByType(rpcClient, signer, coinType, recipient, amountRaw, label = coinType) {
  const sourceCoin = await getLargestCoin(rpcClient, signer.toSuiAddress(), coinType);
  const tx = new Transaction();
  const [transferCoin] = tx.splitCoins(tx.object(sourceCoin.coinObjectId), [tx.pure.u64(String(amountRaw))]);
  tx.transferObjects([transferCoin], tx.pure.address(recipient));
  return executeTransaction(rpcClient, signer, tx, `transfer ${amountRaw} ${label} to ${recipient}`);
}

export async function transferSui(rpcClient, signer, recipient, amountMist) {
  const tx = new Transaction();
  const [transferCoin] = tx.splitCoins(tx.gas, [tx.pure.u64(String(amountMist))]);
  tx.transferObjects([transferCoin], tx.pure.address(recipient));
  return executeTransaction(rpcClient, signer, tx, `transfer ${amountMist} MIST to ${recipient}`);
}

export async function reserveCode(rpcClient, signer) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'reserve_code'),
    arguments: [
      tx.object(CONTRACTS.paperRegistryId),
      tx.object(MAINNET.clockObjectId),
    ],
  });

  const executed = await executeTransaction(rpcClient, signer, tx, 'reserve paper code');
  const event = getEventBySuffix(executed.result, '::CodeReserved');
  if (!event?.parsedJson) {
    throw new Error('CodeReserved event not found in reserve_code result.');
  }

  return {
    txDigest: executed.result.digest,
    paperCode: event.parsedJson.paper_code,
    recordId: event.parsedJson.paper_record_id,
    paperEpoch: Number(event.parsedJson.paper_epoch),
    epochSeq: Number(event.parsedJson.epoch_seq),
    recordNumber: Number(event.parsedJson.record_number),
    raw: executed.result,
  };
}

function noneSuiPayment(tx) {
  return buildNoneObjectOption(tx, '0x2::coin::Coin<0x2::sui::SUI>');
}

export async function finalizePaper(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'finalize_paper'),
    arguments: [
      tx.object(CONTRACTS.paperRegistryId),
      tx.object(input.recordId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.pure.string(input.title),
      tx.pure.string(input.abstractText),
      tx.pure.vector('string', input.keywords),
      tx.pure.vector('string', input.authors),
      tx.pure.string(input.field),
      tx.pure.string(input.license),
      tx.pure.string(input.walrusBlobId),
      tx.pure.string(input.walrusBlobObjectId),
      tx.pure.string(input.fileHash),
      tx.pure.u64(String(input.fileSize)),
      tx.pure.u64(String(input.pageCount)),
      tx.pure.u64(String(input.storageEndEpoch)),
      tx.pure.bool(Boolean(input.isSharedBlob)),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });

  const executed = await executeTransaction(rpcClient, signer, tx, `finalize paper ${input.paperCode}`);
  const finalized = getEventBySuffix(executed.result, '::PaperFinalized');
  const bound = getEventBySuffix(executed.result, '::CommentsTreeBound');
  if (!finalized?.parsedJson || !bound?.parsedJson) {
    throw new Error('Expected PaperFinalized and CommentsTreeBound events were not emitted.');
  }

  return {
    txDigest: executed.result.digest,
    recordId: finalized.parsedJson.paper_record_id,
    versionId: finalized.parsedJson.version_id,
    commentsTreeId: bound.parsedJson.comments_tree_id,
    raw: executed.result,
  };
}

export async function addVersion(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'add_version'),
    arguments: [
      tx.object(CONTRACTS.paperRegistryId),
      tx.object(input.recordId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.pure.string(input.title),
      tx.pure.string(input.abstractText),
      tx.pure.vector('string', input.keywords),
      tx.pure.vector('string', input.authors),
      tx.pure.string(input.field),
      tx.pure.string(input.license),
      tx.pure.string(input.walrusBlobId),
      tx.pure.string(input.walrusBlobObjectId),
      tx.pure.string(input.fileHash),
      tx.pure.u64(String(input.fileSize)),
      tx.pure.u64(String(input.pageCount)),
      tx.pure.u64(String(input.storageEndEpoch)),
      tx.pure.bool(Boolean(input.isSharedBlob)),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });

  const executed = await executeTransaction(rpcClient, signer, tx, `add version to ${input.paperCode}`);
  const event = getEventBySuffix(executed.result, '::PaperVersionAdded');
  if (!event?.parsedJson) {
    throw new Error('PaperVersionAdded event not found.');
  }

  return {
    txDigest: executed.result.digest,
    versionId: event.parsedJson.version_id,
    newVersionNumber: Number(event.parsedJson.new_version_number),
    raw: executed.result,
  };
}

export async function recordStorageExtension(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'record_storage_extension'),
    arguments: [
      tx.object(input.recordId),
      tx.object(input.versionId),
      tx.pure.u64(String(input.newStorageEndEpoch)),
      tx.object(MAINNET.clockObjectId),
    ],
  });

  return executeTransaction(rpcClient, signer, tx, `extend storage for version ${input.versionId}`);
}

export async function transferPaperOwner(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.publishingPackageId, 'publishing', 'transfer_paper_owner'),
    arguments: [
      tx.object(input.recordId),
      tx.object(input.commentsTreeId),
      tx.pure.address(input.newOwner),
      tx.object(MAINNET.clockObjectId),
    ],
  });

  return executeTransaction(rpcClient, signer, tx, `transfer paper owner for ${input.recordId}`);
}

export async function addOnchainComment(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'add_onchain_comment'),
    arguments: [
      tx.object(input.treeId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.pure.u64(String(input.parentCommentId)),
      tx.pure.vector('u8', Array.from(new TextEncoder().encode(input.content))),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });

  const executed = await executeTransaction(rpcClient, signer, tx, `add on-chain comment to ${input.treeId}`);
  const event = getEventBySuffix(executed.result, '::CommentAddedEvent');
  if (!event?.parsedJson) {
    throw new Error('CommentAddedEvent not found for on-chain comment.');
  }

  return {
    txDigest: executed.result.digest,
    commentId: Number(event.parsedJson.comment_id),
    depth: Number(event.parsedJson.depth),
    raw: executed.result,
  };
}

export async function addBlobComment(rpcClient, signer, input) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'add_blob_comment'),
    arguments: [
      tx.object(input.treeId),
      tx.object(CONTRACTS.governanceVaultId),
      tx.pure.u64(String(input.parentCommentId)),
      tx.pure.vector('u8', Array.from(input.blobIdBytes)),
        tx.pure.option('address', input.blobObjectId ?? null),
      tx.pure.vector('u8', Array.from(input.blobDigestBytes)),
      tx.pure.vector('u8', Array.from(input.previewBytes)),
      noneSuiPayment(tx),
      tx.object(MAINNET.clockObjectId),
    ],
  });

  const executed = await executeTransaction(rpcClient, signer, tx, `add blob-backed comment to ${input.treeId}`);
  const event = getEventBySuffix(executed.result, '::CommentAddedEvent');
  if (!event?.parsedJson) {
    throw new Error('CommentAddedEvent not found for blob-backed comment.');
  }

  return {
    txDigest: executed.result.digest,
    commentId: Number(event.parsedJson.comment_id),
    depth: Number(event.parsedJson.depth),
    raw: executed.result,
  };
}

export async function likePaper(rpcClient, signer, treeId) {
  const proofCoin = await getCoinAtLeast(rpcClient, signer.toSuiAddress(), CONTRACTS.pprfType, MIN_LIKE_BALANCE);
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'like_paper'),
    arguments: [
      tx.object(treeId),
      tx.object(proofCoin.coinObjectId),
    ],
  });

  return executeTransaction(rpcClient, signer, tx, `like paper for tree ${treeId}`);
}

export async function unlikePaper(rpcClient, signer, treeId) {
  const proofCoin = await getCoinAtLeast(rpcClient, signer.toSuiAddress(), CONTRACTS.pprfType, MIN_LIKE_BALANCE);
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'unlike_paper'),
    arguments: [
      tx.object(treeId),
      tx.object(proofCoin.coinObjectId),
    ],
  });

  return executeTransaction(rpcClient, signer, tx, `unlike paper for tree ${treeId}`);
}

export async function setTreeStatus(rpcClient, signer, treeId, newStatus, expectFailure = false) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'set_tree_status'),
    arguments: [
      tx.object(treeId),
      tx.pure.u8(newStatus),
    ],
  });

  return executeTransaction(rpcClient, signer, tx, `set tree status ${newStatus} for ${treeId}`, {
    expectFailure,
  });
}

export async function setCommentStatus(rpcClient, signer, treeId, commentId, newStatus, expectFailure = false) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.commentsPackageId, 'comments', 'set_comment_status'),
    arguments: [
      tx.object(treeId),
      tx.pure.u64(String(commentId)),
      tx.pure.u8(newStatus),
    ],
  });

  return executeTransaction(
    rpcClient,
    signer,
    tx,
    `set comment status ${newStatus} for comment ${commentId}`,
    { expectFailure },
  );
}

export async function createProposal(rpcClient, signer, input) {
  const sourceCoin = await getLargestCoin(rpcClient, signer.toSuiAddress(), CONTRACTS.pprfType);
  const tx = new Transaction();
  const stakeArg =
    input.stakeAmountRaw && BigInt(input.stakeAmountRaw) < BigInt(sourceCoin.balance)
      ? tx.splitCoins(tx.object(sourceCoin.coinObjectId), [tx.pure.u64(String(input.stakeAmountRaw))])[0]
      : tx.object(sourceCoin.coinObjectId);

  tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'create_proposal'),
    arguments: [
      tx.object(CONTRACTS.governanceConfigId),
      tx.pure.u8(input.proposalType),
      tx.pure.u8(input.actionType),
      tx.pure.string(input.title),
      tx.pure.string(input.description),
      tx.pure.u64(String(input.payloadU64_1 ?? 0)),
      tx.pure.u64(String(input.payloadU64_2 ?? 0)),
      tx.pure.address(input.payloadAddress ?? '0x0000000000000000000000000000000000000000000000000000000000000000'),
        tx.pure.option('address', input.payloadObjectId ?? null),
      tx.pure.vector('u8', Array.from(input.payloadBytes ?? [])),
      stakeArg,
    ],
  });

  const executed = await executeTransaction(
    rpcClient,
    signer,
    tx,
    `create proposal ${input.title}`,
    { expectFailure: input.expectFailure ?? false },
  );

  if (input.expectFailure) {
    return executed;
  }

  const event = getEventBySuffix(executed.result, '::ProposalCreatedEvent');
  if (!event?.parsedJson) {
    throw new Error('ProposalCreatedEvent not found.');
  }

  return {
    txDigest: executed.result.digest,
    proposalId: Number(event.parsedJson.proposal_id),
    proposalObjectId: event.parsedJson.proposal_object_id,
    raw: executed.result,
  };
}

export async function voteNo(rpcClient, signer, proposalObjectId, amountRaw = null, expectFailure = false) {
  const sourceCoin = await getLargestCoin(rpcClient, signer.toSuiAddress(), CONTRACTS.pprfType);
  const tx = new Transaction();
  const voteArg =
    amountRaw && BigInt(amountRaw) < BigInt(sourceCoin.balance)
      ? tx.splitCoins(tx.object(sourceCoin.coinObjectId), [tx.pure.u64(String(amountRaw))])[0]
      : tx.object(sourceCoin.coinObjectId);

  tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'vote_no'),
    arguments: [
      tx.object(proposalObjectId),
      voteArg,
    ],
  });

  return executeTransaction(rpcClient, signer, tx, `vote NO on proposal ${proposalObjectId}`, {
    expectFailure,
  });
}

export async function finalizeProposal(rpcClient, signer, proposalObjectId) {
  const tx = new Transaction();
  tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'finalize_proposal'),
    arguments: [
      tx.object(CONTRACTS.governanceConfigId),
      tx.object(proposalObjectId),
    ],
  });

  return executeTransaction(rpcClient, signer, tx, `finalize proposal ${proposalObjectId}`);
}

export async function claimLockedTokens(rpcClient, signer, proposalObjectId, expectFailure = false) {
  const tx = new Transaction();
  const claimedCoin = tx.moveCall({
    target: contractTarget(CONTRACTS.governancePackageId, 'governance_voting', 'claim_locked_tokens'),
    arguments: [
      tx.object(proposalObjectId),
    ],
  });
  tx.transferObjects([claimedCoin], tx.pure.address(signer.toSuiAddress()));

  return executeTransaction(rpcClient, signer, tx, `claim locked tokens for ${signer.toSuiAddress()}`, {
    expectFailure,
  });
}

export async function writeJson(filePath, data) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

export async function writeText(filePath, text) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, text, 'utf8');
}

export function relativeToRoot(...segments) {
  return path.join(ROOT_DIR, ...segments);
}
