import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  ARTIFACTS_DIR,
  COMMENTS,
  CONTRACTS,
  EXPECTED_ADDRESSES,
  GOVERNANCE,
  LOGS_DIR,
  MAINNET,
  ONE_PPRF,
  PAPERS_DIR,
  PROPOSER_THRESHOLD,
  addBlobComment,
  addOnchainComment,
  addVersion,
  buildPaperProofLink,
  contractTarget,
  createClients,
  createLogger,
  createProposal,
  createRunId,
  ensureRuntimeDirectories,
  executeTransaction,
  finalizePaper,
  formatPprf,
  getBalanceByType,
  getCommentNode,
  getCommentsTree,
  getDynamicFieldObject,
  getGovernanceConfig,
  getGovernanceVault,
  getLargestCoin,
  getObjectFields,
  getPaperRecord,
  getPaperVersion,
  getProposal,
  likePaper,
  loadAccountsFromEnv,
  parseOptionField,
  recordStorageExtension,
  reserveCode,
  setCommentStatus,
  setTreeStatus,
  transferPaperOwner,
  transferCoinByType,
  transferPprf,
  transferSui,
  unlikePaper,
  uploadFileToWalrus,
  uploadTextBlobToWalrus,
  validatePdfFile,
  voteNo,
  watermarkPdfFile,
  writeJson,
  writeText,
} from './paperproof-mainnet-common.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SAMPLE_A = path.join(__dirname, 'paperSamples', 'Versioned Upgrade Design.pdf');
const SAMPLE_B = path.join(__dirname, 'paperSamples', 'PaperProof Contracts Observability and Read APIs.pdf');
const WAL_PREFUND_RAW = 10_000_000n;
const SUI_PREFUND_MIST = 100_000_000n;
const RUN_HELP = `
PaperProof Mainnet Functional Test

Usage:
  node ./mainnet-functional-test.mjs --validate
  node ./mainnet-functional-test.mjs --run

Modes:
  --validate   Read-only environment and dependency validation.
  --run        Execute the mainnet test flow up to governance proposal voting.

Notes:
  - This script performs real mainnet transactions in --run mode.
  - Governance finalization and token reclaim happen the next day through
    ./mainnet-governance-finalize.mjs, which this script rewrites with the
    current proposal ids and addresses.
`.trim();

function parseArgs(argv) {
  const args = new Set(argv.slice(2));
  return {
    validate: args.has('--validate'),
    run: args.has('--run'),
    help: args.has('--help') || args.has('-h'),
  };
}

function buildMetadata(label) {
  if (label === 'A') {
    return {
      title: 'Versioned Upgrade Design for PaperProof Contracts',
      abstractText:
        'This mainnet test paper exercises the canonical PaperProof publishing flow, including finalize, version updates, comments, likes, and governance-safe interaction coverage.',
      keywords: ['paperproof', 'sui', 'walrus', 'upgrade', 'testing'],
      authors: ['PaperProof Labs', 'Mainnet Test Harness'],
      field: 'Computer Science',
      license: 'PaperProof Source-Available License',
    };
  }

  return {
    title: 'PaperProof Contracts Observability and Read APIs',
    abstractText:
      'This mainnet test paper validates the second canonical publishing path and provides a stable target for ownership transfer and comments tree governance checks.',
    keywords: ['paperproof', 'observability', 'comments', 'governance', 'mainnet'],
    authors: ['PaperProof Labs', 'Mainnet Test Harness'],
    field: 'Computer Science',
    license: 'PaperProof Source-Available License',
  };
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function fileExists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function validateEnvironment({ rpcClient, accounts, logger }) {
  logger.write('## Validation');

  const [vault, config, registry] = await Promise.all([
    getGovernanceVault(rpcClient),
    getGovernanceConfig(rpcClient),
    getObjectFields(rpcClient, CONTRACTS.paperRegistryId).then((value) => value.fields),
  ]);

  assert(vault.governance_authority.toLowerCase() === EXPECTED_ADDRESSES.addr1.toLowerCase(), 'Governance authority mismatch.');
  assert(vault.active_operator.toLowerCase() === EXPECTED_ADDRESSES.addr1.toLowerCase(), 'Active operator mismatch.');
  assert(vault.fee_recipient.toLowerCase() === EXPECTED_ADDRESSES.addr1.toLowerCase(), 'Fee recipient mismatch.');
  assert(vault.upgrade_authority.toLowerCase() === EXPECTED_ADDRESSES.addr1.toLowerCase(), 'Upgrade authority mismatch.');
  assert(Number(config.proposal_duration_epochs) === 1, 'Expected proposal_duration_epochs to remain 1.');
  assert(BigInt(config.proposer_threshold) === PROPOSER_THRESHOLD, 'Proposer threshold mismatch.');

  const pprfBalances = await Promise.all(
    accounts.map((account) => getBalanceByType(rpcClient, account.address, CONTRACTS.pprfType)),
  );
  const suiBalances = await Promise.all(accounts.map((account) => getBalanceByType(rpcClient, account.address, '0x2::sui::SUI')));

  accounts.forEach((account, index) => {
    logger.write(
      `- ${account.key} (${account.role}) | address=${account.address} | SUI=${suiBalances[index].totalBalance} | PPRF=${formatPprf(pprfBalances[index].totalBalance)}`,
    );
  });

  assert(Number(registry.max_file_size) > 0, 'Registry max_file_size should be configured.');

  const sampleChecks = await Promise.all([
    fileExists(SAMPLE_A),
    fileExists(SAMPLE_B),
  ]);
  assert(sampleChecks.every(Boolean), 'Sample PDFs are missing from jstest/paperSamples.');

  const activeProposal = parseOptionField(config.active_proposal_id);
  return {
    vault,
    config,
    registry,
    balances: {
      pprfBalances,
      suiBalances,
    },
    activeProposal,
  };
}

function bytesToAscii(value) {
  return Buffer.from(value).toString('utf8');
}

async function writeFinalizeScript(params) {
  const filePath = path.join(__dirname, 'mainnet-governance-finalize.mjs');
  const source = `import path from 'node:path';
import { fileURLToPath } from 'node:url';

  import {
    CONTRACTS,
    EXPECTED_ADDRESSES,
    MAINNET,
    claimLockedTokens,
    createClients,
    createLogger,
    createRunId,
    ensureRuntimeDirectories,
    finalizeProposal,
    getGovernanceConfig,
    getGovernanceVault,
    governanceOutcomeDeterminable,
    parseOptionField,
    getProposal,
    loadAccountsFromEnv,
    resolveProposalEarly,
    writeJson,
  } from './paperproof-mainnet-common.mjs';

const HARDCODED = Object.freeze({
  proposalId: ${params.proposalId},
  proposalObjectId: '${params.proposalObjectId}',
  expectedCommentsFeeLevel: 0,
  participantAddresses: [
    '${EXPECTED_ADDRESSES.addr1}',
    '${EXPECTED_ADDRESSES.addr2}',
    '${EXPECTED_ADDRESSES.addr3}',
  ],
  createdByRunId: '${params.runId}',
  createdAtEpoch: ${params.createdAtEpoch},
  finalizeSigner: 'ADDR_3',
});

async function main() {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);
  await ensureRuntimeDirectories();
  const runId = createRunId('governance-finalize');
  const logger = createLogger(runId);
  const accounts = loadAccountsFromEnv();
  const { rpcClient } = createClients();

  const signerEntry = accounts.find((item) => item.key === HARDCODED.finalizeSigner);
  if (!signerEntry) {
    throw new Error(\`Missing signer entry \${HARDCODED.finalizeSigner}.\`);
  }

  logger.write('# Governance Finalize Run');
  logger.write(\`- proposalId: \${HARDCODED.proposalId}\`);
  logger.write(\`- proposalObjectId: \${HARDCODED.proposalObjectId}\`);
  logger.write(\`- signer: \${HARDCODED.finalizeSigner} (\${signerEntry.address})\`);

  const before = await getProposal(rpcClient, HARDCODED.proposalObjectId);
  const configBefore = await getGovernanceConfig(rpcClient);
  logger.write(\`- current status before finalize: \${before.status}\`);
  logger.write(\`- current epoch window: start=\${before.start_epoch}, end=\${before.end_epoch}\`);
  const systemState = await rpcClient.getLatestSuiSystemState();
  logger.write(\`- current chain epoch: \${systemState.epoch}\`);
  const early = governanceOutcomeDeterminable(
    configBefore.pprf_total_supply,
    before.yes_votes,
    before.no_votes,
  );
  logger.write(\`- remaining voting supply: \${early.remainingVotingSupply}\`);
  logger.write(\`- early determinable: \${early.determinable}\`);
  if (early.determinable) {
    logger.write(\`- early resolution branch: \${early.deterministicPass ? 'PASS' : 'REJECT'}\`);
  }

  let settlement;
  let settlementMode;
  if (BigInt(systemState.epoch) <= BigInt(before.end_epoch)) {
    if (!early.determinable) {
      throw new Error(
        \`Proposal voting is still active and its outcome is not yet mathematically fixed. Current epoch is \${systemState.epoch}, voting end epoch is \${before.end_epoch}. Wait until voting ends or until the vote becomes determinable.\`,
      );
    }

    settlement = await resolveProposalEarly(rpcClient, signerEntry.signer, HARDCODED.proposalObjectId);
    settlementMode = 'early-resolve';
    logger.write(\`- early resolve tx digest: \${settlement.result?.digest ?? settlement.digest}\`);
  } else {
    settlement = await finalizeProposal(rpcClient, signerEntry.signer, HARDCODED.proposalObjectId);
    settlementMode = 'finalize';
    logger.write(\`- finalize tx digest: \${settlement.result?.digest ?? settlement.digest}\`);
  }

  const after = await getProposal(rpcClient, HARDCODED.proposalObjectId);
  logger.write(\`- status after settlement: \${after.status}\`);
  if (Number(after.status) !== 3) {
    throw new Error(\`Expected proposal to be REJECTED (3), got \${after.status}.\`);
  }

    const claimFounder = await claimLockedTokens(rpcClient, accounts[0].signer, HARDCODED.proposalObjectId);
    logger.write(\`- claim tx by ADDR_1: \${claimFounder.result?.digest ?? claimFounder.digest}\`);

    const noVoteClaimAddr2 = await claimLockedTokens(rpcClient, accounts[1].signer, HARDCODED.proposalObjectId, true);
    logger.write(\`- claim by ADDR_2 rejected as expected (no successful vote recorded): \${noVoteClaimAddr2.error ?? 'execution failure'}\`);

    const noVoteClaimAddr3 = await claimLockedTokens(rpcClient, accounts[2].signer, HARDCODED.proposalObjectId, true);
    logger.write(\`- claim by ADDR_3 rejected as expected (no successful vote recorded): \${noVoteClaimAddr3.error ?? 'execution failure'}\`);

    const duplicateClaimFounder = await claimLockedTokens(rpcClient, accounts[0].signer, HARDCODED.proposalObjectId, true);
    logger.write(\`- duplicate claim by ADDR_1 rejected as expected: \${duplicateClaimFounder.error ?? 'execution failure'}\`);

  const [vault, config] = await Promise.all([
    getGovernanceVault(rpcClient),
    getGovernanceConfig(rpcClient),
  ]);
  if (Number(vault.comments_fee_level) !== HARDCODED.expectedCommentsFeeLevel) {
    throw new Error(\`comments_fee_level changed unexpectedly to \${vault.comments_fee_level}.\`);
  }
    if (parseOptionField(config.active_proposal_id) !== null) {
      throw new Error('GovernanceConfig.active_proposal_id should be empty after finalize.');
    }

  const artifact = {
    runId,
    hardcoded: HARDCODED,
    settlementMode,
    finalizedStatus: Number(after.status),
    settlementTxDigest: settlement.result?.digest ?? settlement.digest,
      claims: [
        {
          account: accounts[0].key,
          address: accounts[0].address,
          digest: claimFounder.result?.digest ?? claimFounder.digest,
        },
      ],
      noVoteClaimAddr2Error: noVoteClaimAddr2.error ?? null,
      noVoteClaimAddr3Error: noVoteClaimAddr3.error ?? null,
      duplicateClaimError: duplicateClaimFounder.error ?? null,
    finalCommentsFeeLevel: Number(vault.comments_fee_level),
    finalActiveProposalId: config.active_proposal_id,
  };

  const artifactPath = path.join(__dirname, 'artifacts', \`\${runId}.json\`);
  await writeJson(artifactPath, artifact);
  const logPath = await logger.flush();
  console.log('\\nFinalize completed successfully.');
  console.log('Artifact:', artifactPath);
  console.log('Log:', logPath);
}

main().catch((error) => {
  console.error('\\nGovernance finalize failed.');
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
`;
  await fs.writeFile(filePath, source, 'utf8');
  return filePath;
}

function createArtifactSkeleton(runId, accounts) {
  return {
    runId,
    network: MAINNET.suiNetwork,
    canonical: {
      ...CONTRACTS,
    },
    accounts: accounts.map((account) => ({
      key: account.key,
      address: account.address,
      role: account.role,
    })),
    transactions: [],
    papers: {},
    governance: {},
    comments: {
      paperA: {
        commentIds: {},
      },
    },
    notes: [],
  };
}

function recordTx(artifact, label, execution) {
  artifact.transactions.push({
    label,
    digest: execution?.result?.digest ?? execution?.digest ?? null,
    status: execution?.expectedFailure ? 'expected-failure' : 'success',
    error: execution?.error ?? null,
  });
}

function eventDigest(execution) {
  return execution?.result?.digest ?? execution?.digest ?? null;
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help || (!args.validate && !args.run)) {
    console.log(RUN_HELP);
    return;
  }

  await ensureRuntimeDirectories();
  const runId = createRunId();
  const logger = createLogger(runId);
  const accounts = loadAccountsFromEnv();
  const { rpcClient, walrusClient } = createClients();

  logger.write('# PaperProof Mainnet Functional Test');
  logger.write(`- runId: ${runId}`);
  logger.write(`- mode: ${args.validate ? 'validate' : 'run'}`);
  logger.write(`- registry: ${CONTRACTS.paperRegistryId}`);
  logger.write(`- governanceVault: ${CONTRACTS.governanceVaultId}`);
  logger.write(`- governanceConfig: ${CONTRACTS.governanceConfigId}`);
  logger.write('');

  const artifact = createArtifactSkeleton(runId, accounts);
  const validation = await validateEnvironment({ rpcClient, accounts, logger });
  artifact.validation = {
    activeProposal: validation.activeProposal,
    pprfBalances: validation.balances.pprfBalances.map((balance) => balance.totalBalance),
    suiBalances: validation.balances.suiBalances.map((balance) => balance.totalBalance),
  };

  if (args.validate) {
    const artifactPath = path.join(ARTIFACTS_DIR, `${runId}.json`);
    await writeJson(artifactPath, artifact);
    const logPath = await logger.flush();
    console.log('\nValidation finished successfully.');
    console.log('Artifact:', artifactPath);
    console.log('Log:', logPath);
    return;
  }

  if (validation.activeProposal !== null && validation.activeProposal !== undefined) {
    throw new Error(
      `GovernanceConfig already has an active proposal (${JSON.stringify(validation.activeProposal)}). Wait until its end epoch, then run ./mainnet-governance-finalize.mjs (or finalize it manually) before starting a fresh full script run.`,
    );
  }

  const [addr1, addr2, addr3] = accounts;

  logger.write('\n## Phase 1 - PPRF distribution and preconditions');

  const [addr2PreWal, addr3PreWal, addr2PreSui, addr3PreSui] = await Promise.all([
    getBalanceByType(rpcClient, addr2.address, CONTRACTS.walType),
    getBalanceByType(rpcClient, addr3.address, CONTRACTS.walType),
    getBalanceByType(rpcClient, addr2.address, '0x2::sui::SUI'),
    getBalanceByType(rpcClient, addr3.address, '0x2::sui::SUI'),
  ]);

  const addr3PrePprf = await getBalanceByType(rpcClient, addr3.address, CONTRACTS.pprfType);
  const addr3PrePprfRaw = BigInt(addr3PrePprf.totalBalance);
  assert(
    addr3PrePprfRaw <= ONE_PPRF,
    `ADDR_3 should hold at most 1 PPRF before this scripted round, but currently has ${formatPprf(addr3PrePprf.totalBalance)}.`,
  );
  if (addr3PrePprfRaw === 0n) {
    artifact.notes.push('ADDR_3 started with 0 PPRF, so on-chain like/proposal paths requiring a proof coin are impossible before transfer.');
  } else {
    artifact.notes.push(`ADDR_3 already held ${formatPprf(addr3PrePprf.totalBalance)} before the scripted round, so the transfer step will be skipped.`);
  }

  const lowBalanceProposal = await createProposal(rpcClient, addr2.signer, {
    proposalType: GOVERNANCE.proposalTypeExecutable,
    actionType: GOVERNANCE.actionSetCommentsFeeLevel,
    title: 'PaperProof mainnet low-balance proposer threshold check',
    description: 'Expected to fail because the proposer stake is far below threshold.',
    payloadU64_1: 1,
    payloadU64_2: 0,
    payloadAddress: EXPECTED_ADDRESSES.addr1,
    payloadBytes: new Uint8Array(),
    stakeAmountRaw: ONE_PPRF,
    expectFailure: true,
  });
  recordTx(artifact, 'low-balance proposal attempt by ADDR_2', lowBalanceProposal);
  logger.write(`- low-balance proposal attempt rejected as expected: ${lowBalanceProposal.error ?? 'failure status returned'}`);

  if (addr3PrePprfRaw === 0n) {
    const transferResult = await transferPprf(rpcClient, addr1.signer, addr3.address, ONE_PPRF);
    recordTx(artifact, 'transfer 1 PPRF from ADDR_1 to ADDR_3', transferResult);
    logger.write(`- transferred 1 PPRF to ADDR_3 in tx ${eventDigest(transferResult)}`);
  } else {
    logger.write(`- skipped transfer because ADDR_3 already has ${formatPprf(addr3PrePprf.totalBalance)}`);
  }

  if (BigInt(addr2PreWal.totalBalance) < WAL_PREFUND_RAW) {
    const fundWalAddr2 = await transferCoinByType(
      rpcClient,
      addr1.signer,
      CONTRACTS.walType,
      addr2.address,
      WAL_PREFUND_RAW,
      'WAL',
    );
    recordTx(artifact, 'prefund ADDR_2 with WAL', fundWalAddr2);
    logger.write(`- funded ADDR_2 with WAL in tx ${eventDigest(fundWalAddr2)}`);
  } else {
    logger.write(`- skipped ADDR_2 WAL prefund because it already has ${addr2PreWal.totalBalance} raw WAL`);
  }

  if (BigInt(addr2PreSui.totalBalance) < SUI_PREFUND_MIST) {
    const fundSuiAddr2 = await transferSui(rpcClient, addr1.signer, addr2.address, SUI_PREFUND_MIST);
    recordTx(artifact, 'prefund ADDR_2 with SUI', fundSuiAddr2);
    logger.write(`- funded ADDR_2 with SUI in tx ${eventDigest(fundSuiAddr2)}`);
  } else {
    logger.write(`- skipped ADDR_2 SUI prefund because it already has ${addr2PreSui.totalBalance} MIST`);
  }

  if (BigInt(addr3PreWal.totalBalance) < WAL_PREFUND_RAW) {
    const fundWalAddr3 = await transferCoinByType(
      rpcClient,
      addr1.signer,
      CONTRACTS.walType,
      addr3.address,
      WAL_PREFUND_RAW,
      'WAL',
    );
    recordTx(artifact, 'prefund ADDR_3 with WAL', fundWalAddr3);
    logger.write(`- funded ADDR_3 with WAL in tx ${eventDigest(fundWalAddr3)}`);
  } else {
    logger.write(`- skipped ADDR_3 WAL prefund because it already has ${addr3PreWal.totalBalance} raw WAL`);
  }

  if (BigInt(addr3PreSui.totalBalance) < SUI_PREFUND_MIST) {
    const fundSuiAddr3 = await transferSui(rpcClient, addr1.signer, addr3.address, SUI_PREFUND_MIST);
    recordTx(artifact, 'prefund ADDR_3 with SUI', fundSuiAddr3);
    logger.write(`- funded ADDR_3 with SUI in tx ${eventDigest(fundSuiAddr3)}`);
  } else {
    logger.write(`- skipped ADDR_3 SUI prefund because it already has ${addr3PreSui.totalBalance} MIST`);
  }

  logger.write('\n## Phase 2 - Publish Paper A');
  const reserveA = await reserveCode(rpcClient, addr1.signer);
  artifact.papers.paperA = {
    reserve: reserveA,
  };
  logger.write(`- Paper A reserved code: ${reserveA.paperCode}`);

  const stampedA1 = await watermarkPdfFile(SAMPLE_A, reserveA.paperCode, PAPERS_DIR);
  const walrusA1 = await uploadFileToWalrus(walrusClient, addr1.signer, addr1.address, stampedA1.filePath);
  const metadataA = buildMetadata('A');
  const finalizedA = await finalizePaper(rpcClient, addr1.signer, {
    recordId: reserveA.recordId,
    paperCode: reserveA.paperCode,
    ...metadataA,
    walrusBlobId: walrusA1.walrusBlobId,
    walrusBlobObjectId: walrusA1.walrusBlobObjectId,
    fileHash: stampedA1.fileHash,
    fileSize: stampedA1.fileSize,
    pageCount: stampedA1.pageCount,
    storageEndEpoch: walrusA1.storageEndEpoch,
    isSharedBlob: walrusA1.isSharedBlob,
  });
  recordTx(artifact, 'finalize Paper A', finalizedA.raw);
  artifact.papers.paperA = {
    ...artifact.papers.paperA,
    recordId: reserveA.recordId,
    version1Id: finalizedA.versionId,
    commentsTreeId: finalizedA.commentsTreeId,
    paperCode: reserveA.paperCode,
    stampedFiles: [stampedA1.filePath],
    walrus: [
      {
        blobId: walrusA1.walrusBlobId,
        blobObjectId: walrusA1.walrusBlobObjectId,
        storageEndEpoch: walrusA1.storageEndEpoch,
        source: 'version1',
      },
    ],
  };

  const recordAAfterFinalize = await getPaperRecord(rpcClient, reserveA.recordId);
  assert(
    parseOptionField(recordAAfterFinalize.comments_tree_id) === finalizedA.commentsTreeId,
    'Paper A comments_tree_id does not match the finalize event.',
  );

  logger.write('\n## Phase 2 - Publish Paper B');
  const reserveB = await reserveCode(rpcClient, addr2.signer);
  artifact.papers.paperB = {
    reserve: reserveB,
  };
  logger.write(`- Paper B reserved code: ${reserveB.paperCode}`);

  const stampedB1 = await watermarkPdfFile(SAMPLE_B, reserveB.paperCode, PAPERS_DIR);
  const walrusB1 = await uploadFileToWalrus(walrusClient, addr2.signer, addr2.address, stampedB1.filePath);
  const metadataB = buildMetadata('B');
  const finalizedB = await finalizePaper(rpcClient, addr2.signer, {
    recordId: reserveB.recordId,
    paperCode: reserveB.paperCode,
    ...metadataB,
    walrusBlobId: walrusB1.walrusBlobId,
    walrusBlobObjectId: walrusB1.walrusBlobObjectId,
    fileHash: stampedB1.fileHash,
    fileSize: stampedB1.fileSize,
    pageCount: stampedB1.pageCount,
    storageEndEpoch: walrusB1.storageEndEpoch,
    isSharedBlob: walrusB1.isSharedBlob,
  });
  recordTx(artifact, 'finalize Paper B', finalizedB.raw);
  artifact.papers.paperB = {
    ...artifact.papers.paperB,
    recordId: reserveB.recordId,
    version1Id: finalizedB.versionId,
    commentsTreeId: finalizedB.commentsTreeId,
    paperCode: reserveB.paperCode,
    stampedFiles: [stampedB1.filePath],
    walrus: [
      {
        blobId: walrusB1.walrusBlobId,
        blobObjectId: walrusB1.walrusBlobObjectId,
        storageEndEpoch: walrusB1.storageEndEpoch,
        source: 'version1',
      },
    ],
  };

  logger.write('\n## Phase 2 - Add version to Paper A');
  const stampedA2 = await watermarkPdfFile(SAMPLE_B, reserveA.paperCode, PAPERS_DIR);
  const walrusA2 = await uploadFileToWalrus(walrusClient, addr1.signer, addr1.address, stampedA2.filePath);
  const version2 = await addVersion(rpcClient, addr1.signer, {
    recordId: reserveA.recordId,
    paperCode: reserveA.paperCode,
    title: `${metadataA.title} (Version 2)`,
    abstractText: `${metadataA.abstractText} This second version validates add_version and comments tree continuity.`,
    keywords: [...metadataA.keywords, 'version2'],
    authors: metadataA.authors,
    field: metadataA.field,
    license: metadataA.license,
    walrusBlobId: walrusA2.walrusBlobId,
    walrusBlobObjectId: walrusA2.walrusBlobObjectId,
    fileHash: stampedA2.fileHash,
    fileSize: stampedA2.fileSize,
    pageCount: stampedA2.pageCount,
    storageEndEpoch: walrusA2.storageEndEpoch,
    isSharedBlob: walrusA2.isSharedBlob,
  });
  recordTx(artifact, 'add version to Paper A', version2.raw);
  artifact.papers.paperA.version2Id = version2.versionId;
  artifact.papers.paperA.stampedFiles.push(stampedA2.filePath);
  artifact.papers.paperA.walrus.push({
    blobId: walrusA2.walrusBlobId,
    blobObjectId: walrusA2.walrusBlobObjectId,
    storageEndEpoch: walrusA2.storageEndEpoch,
    source: 'version2',
  });

  const recordAAfterVersion2 = await getPaperRecord(rpcClient, reserveA.recordId);
  const paperACommentsTreeAfterVersion2 = parseOptionField(recordAAfterVersion2.comments_tree_id);
  assert(
    paperACommentsTreeAfterVersion2 === finalizedA.commentsTreeId,
    'Paper A comments tree changed after add_version, which should not happen.',
  );

  logger.write('\n## Phase 2 - Record storage extension on Paper A version 2');
  const version2BeforeExtension = await getPaperVersion(rpcClient, version2.versionId);
  const newStorageEndEpoch = Number(version2BeforeExtension.storage_end_epoch) + 1;
  const storageExtension = await recordStorageExtension(rpcClient, addr1.signer, {
    recordId: reserveA.recordId,
    versionId: version2.versionId,
    newStorageEndEpoch,
  });
  recordTx(artifact, 'extend Paper A version 2 storage', storageExtension);
  const version2AfterExtension = await getPaperVersion(rpcClient, version2.versionId);
  assert(
    Number(version2AfterExtension.storage_end_epoch) === newStorageEndEpoch,
    'Paper A version 2 storage_end_epoch was not updated.',
  );

  logger.write('\n## Phase 3 - Like / unlike');
  const likeAddr2 = await likePaper(rpcClient, addr2.signer, finalizedA.commentsTreeId);
  recordTx(artifact, 'ADDR_2 like Paper A', likeAddr2);

  const duplicateLikeAddr2 = await likePaper(rpcClient, addr2.signer, finalizedA.commentsTreeId).catch((error) => ({
    ok: false,
    expectedFailure: true,
    error: error.message,
  }));
  recordTx(artifact, 'ADDR_2 duplicate like Paper A', duplicateLikeAddr2);
  logger.write(`- duplicate like by ADDR_2 rejected as expected: ${duplicateLikeAddr2.error ?? 'failure status returned'}`);

  const likeAddr3 = await likePaper(rpcClient, addr3.signer, finalizedA.commentsTreeId);
  recordTx(artifact, 'ADDR_3 like Paper A', likeAddr3);

  const unlikeAddr3 = await unlikePaper(rpcClient, addr3.signer, finalizedA.commentsTreeId);
  recordTx(artifact, 'ADDR_3 unlike Paper A', unlikeAddr3);

  const unlikeAgainAddr3 = await unlikePaper(rpcClient, addr3.signer, finalizedA.commentsTreeId).catch((error) => ({
    ok: false,
    expectedFailure: true,
    error: error.message,
  }));
  recordTx(artifact, 'ADDR_3 unlike again Paper A', unlikeAgainAddr3);
  logger.write(`- unlike-again by ADDR_3 rejected as expected: ${unlikeAgainAddr3.error ?? 'failure status returned'}`);

  const treeAAfterLikes = await getCommentsTree(rpcClient, finalizedA.commentsTreeId);
  assert(Number(treeAAfterLikes.like_count) === 1, `Expected Paper A like_count to be 1, got ${treeAAfterLikes.like_count}.`);

  logger.write('\n## Phase 4 - Paper A comments tree');
  const commentIds = artifact.comments.paperA.commentIds;
  const commentA = await addOnchainComment(rpcClient, addr2.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: 0,
    content: 'Top-level comment A from ADDR_2.',
  });
  recordTx(artifact, 'Paper A comment A', commentA.raw);
  commentIds.A = commentA.commentId;

  const commentA1 = await addOnchainComment(rpcClient, addr1.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: commentA.commentId,
    content: 'Reply A1 from ADDR_1.',
  });
  recordTx(artifact, 'Paper A comment A1', commentA1.raw);
  commentIds.A1 = commentA1.commentId;

  const commentA1a = await addOnchainComment(rpcClient, addr3.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: commentA1.commentId,
    content: 'Reply A1a from ADDR_3.',
  });
  recordTx(artifact, 'Paper A comment A1a', commentA1a.raw);
  commentIds.A1a = commentA1a.commentId;

  const commentB = await addOnchainComment(rpcClient, addr3.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: 0,
    content: 'Top-level comment B from ADDR_3.',
  });
  recordTx(artifact, 'Paper A comment B', commentB.raw);
  commentIds.B = commentB.commentId;

  const commentB1 = await addOnchainComment(rpcClient, addr2.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: commentB.commentId,
    content: 'Reply B1 from ADDR_2.',
  });
  recordTx(artifact, 'Paper A comment B1', commentB1.raw);
  commentIds.B1 = commentB1.commentId;

  const commentB1a = await addOnchainComment(rpcClient, addr1.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: commentB1.commentId,
    content: 'Reply B1a from ADDR_1.',
  });
  recordTx(artifact, 'Paper A comment B1a', commentB1a.raw);
  commentIds.B1a = commentB1a.commentId;

  const commentC = await addOnchainComment(rpcClient, addr1.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: 0,
    content: 'Top-level comment C from ADDR_1.',
  });
  recordTx(artifact, 'Paper A comment C', commentC.raw);
  commentIds.C = commentC.commentId;

  const commentC1 = await addOnchainComment(rpcClient, addr3.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: commentC.commentId,
    content: 'Reply C1 from ADDR_3.',
  });
  recordTx(artifact, 'Paper A comment C1', commentC1.raw);
  commentIds.C1 = commentC1.commentId;

  const commentC1a = await addOnchainComment(rpcClient, addr2.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: commentC1.commentId,
    content: 'Reply C1a from ADDR_2.',
  });
  recordTx(artifact, 'Paper A comment C1a', commentC1a.raw);
  commentIds.C1a = commentC1a.commentId;

  const hideB1 = await setCommentStatus(rpcClient, addr2.signer, finalizedA.commentsTreeId, commentB1.commentId, COMMENTS.commentStatusHidden);
  recordTx(artifact, 'hide comment B1', hideB1);

  const hiddenB1 = await getCommentNode(rpcClient, finalizedA.commentsTreeId, commentB1.commentId);
  assert(Number(hiddenB1.status) === COMMENTS.commentStatusHidden, 'Comment B1 should be hidden on-chain.');

  const blobReplyPayload = await uploadTextBlobToWalrus(
    walrusClient,
    addr3.signer,
    addr3.address,
    'Blob-backed reply under hidden comment B1 for mainnet functional coverage.',
  );
  const commentB1b = await addBlobComment(rpcClient, addr3.signer, {
    treeId: finalizedA.commentsTreeId,
    parentCommentId: commentB1.commentId,
    blobIdBytes: blobReplyPayload.blobIdBytes,
    blobObjectId: blobReplyPayload.certified.blobObjectId ?? blobReplyPayload.registered.blobObjectId,
    blobDigestBytes: blobReplyPayload.blobDigestBytes,
    previewBytes: blobReplyPayload.previewBytes,
  });
  recordTx(artifact, 'blob-backed reply under hidden B1', commentB1b.raw);
  commentIds.B1bBlob = commentB1b.commentId;

  const treeAAfterComments = await getCommentsTree(rpcClient, finalizedA.commentsTreeId);
  assert(Number(treeAAfterComments.total_comments) === 10, `Expected Paper A total_comments to be 10, got ${treeAAfterComments.total_comments}.`);

  logger.write('\n## Phase 5 - Paper B owner sync and tree controls');
  const transferOwnerB = await transferPaperOwner(rpcClient, addr2.signer, {
    recordId: reserveB.recordId,
    commentsTreeId: finalizedB.commentsTreeId,
    newOwner: addr3.address,
  });
  recordTx(artifact, 'transfer Paper B owner to ADDR_3', transferOwnerB);

  const treeBAfterTransfer = await getCommentsTree(rpcClient, finalizedB.commentsTreeId);
  assert(treeBAfterTransfer.owner.toLowerCase() === addr3.address.toLowerCase(), 'Paper B comments tree owner did not follow the new paper owner.');

  const oldOwnerLockFail = await setTreeStatus(rpcClient, addr2.signer, finalizedB.commentsTreeId, COMMENTS.treeStatusLocked, true);
  recordTx(artifact, 'old Paper B owner lock attempt', oldOwnerLockFail);
  logger.write(`- old owner lock attempt rejected as expected: ${oldOwnerLockFail.error ?? 'failure status returned'}`);

  const lockTreeB = await setTreeStatus(rpcClient, addr3.signer, finalizedB.commentsTreeId, COMMENTS.treeStatusLocked);
  recordTx(artifact, 'lock Paper B tree by ADDR_3', lockTreeB);

  const lockedCommentFail = await addOnchainComment(rpcClient, addr1.signer, {
    treeId: finalizedB.commentsTreeId,
    parentCommentId: 0,
    content: 'This comment should fail because Paper B tree is locked.',
  }).catch((error) => ({
    ok: false,
    expectedFailure: true,
    error: error.message,
  }));
  recordTx(artifact, 'comment while Paper B tree locked', lockedCommentFail);
  logger.write(`- comment while tree locked rejected as expected: ${lockedCommentFail.error ?? 'failure status returned'}`);

  const reopenTreeB = await setTreeStatus(rpcClient, addr3.signer, finalizedB.commentsTreeId, COMMENTS.treeStatusOpen);
  recordTx(artifact, 'reopen Paper B tree by ADDR_3', reopenTreeB);

  const reopenedComment = await addOnchainComment(rpcClient, addr1.signer, {
    treeId: finalizedB.commentsTreeId,
    parentCommentId: 0,
    content: 'Paper B reopened-tree success comment from ADDR_1.',
  });
  recordTx(artifact, 'Paper B reopened-tree comment', reopenedComment.raw);
  artifact.comments.paperB = {
    reopenedCommentId: reopenedComment.commentId,
  };

  logger.write('\n## Phase 6 - Governance proposal without passing');
  const lowBalanceProposalAddr3 = await createProposal(rpcClient, addr3.signer, {
    proposalType: GOVERNANCE.proposalTypeExecutable,
    actionType: GOVERNANCE.actionSetCommentsFeeLevel,
    title: 'ADDR_3 proposer threshold failure',
    description: 'Expected to fail because ADDR_3 only has 1 PPRF.',
    payloadU64_1: 1,
    payloadU64_2: 0,
    payloadAddress: EXPECTED_ADDRESSES.addr1,
    payloadBytes: new Uint8Array(),
    stakeAmountRaw: ONE_PPRF,
    expectFailure: true,
  });
  recordTx(artifact, 'low-balance proposal attempt by ADDR_3', lowBalanceProposalAddr3);

  const proposalCreated = await createProposal(rpcClient, addr1.signer, {
    proposalType: GOVERNANCE.proposalTypeExecutable,
    actionType: GOVERNANCE.actionSetCommentsFeeLevel,
    title: 'Mainnet functional test executable proposal (expected to be rejected)',
    description:
      'This proposal is intentionally created for mainnet governance path validation. It should not pass because only the proposer votes YES and the total yes power remains below the >10% quorum requirement.',
    payloadU64_1: 1,
    payloadU64_2: 0,
    payloadAddress: EXPECTED_ADDRESSES.addr1,
    payloadBytes: new Uint8Array(),
    stakeAmountRaw: PROPOSER_THRESHOLD,
  });
  recordTx(artifact, 'create executable governance proposal', proposalCreated.raw);
  artifact.governance.proposalId = proposalCreated.proposalId;
  artifact.governance.proposalObjectId = proposalCreated.proposalObjectId;

  const secondProposalWhileActive = await createProposal(rpcClient, addr2.signer, {
    proposalType: GOVERNANCE.proposalTypeSignal,
    actionType: 102,
    title: 'Second proposal while one is active',
    description: 'Expected to fail because only one active proposal is allowed.',
    payloadU64_1: 0,
    payloadU64_2: 0,
    payloadAddress: EXPECTED_ADDRESSES.addr2,
    payloadBytes: new Uint8Array(),
    stakeAmountRaw: ONE_PPRF,
    expectFailure: true,
  });
  recordTx(artifact, 'second proposal while first is active', secondProposalWhileActive);

  const lowBalanceVoteNo2 = await voteNo(rpcClient, addr2.signer, proposalCreated.proposalObjectId, null, true);
  recordTx(artifact, 'ADDR_2 low-balance vote NO attempt', lowBalanceVoteNo2);
  logger.write(`- low-balance NO vote by ADDR_2 rejected as expected: ${lowBalanceVoteNo2.error ?? 'failure status returned'}`);

  const lowBalanceVoteNo3 = await voteNo(rpcClient, addr3.signer, proposalCreated.proposalObjectId, null, true);
  recordTx(artifact, 'ADDR_3 low-balance vote NO attempt', lowBalanceVoteNo3);
  logger.write(`- low-balance NO vote by ADDR_3 rejected as expected: ${lowBalanceVoteNo3.error ?? 'failure status returned'}`);

  const proposalState = await getProposal(rpcClient, proposalCreated.proposalObjectId);
  artifact.governance.startEpoch = Number(proposalState.start_epoch);
  artifact.governance.endEpoch = Number(proposalState.end_epoch);
  artifact.governance.currentStatus = Number(proposalState.status);
  artifact.governance.yesVotes = proposalState.yes_votes;
  artifact.governance.noVotes = proposalState.no_votes;

  const finalizeScriptPath = await writeFinalizeScript({
    runId,
    proposalId: proposalCreated.proposalId,
    proposalObjectId: proposalCreated.proposalObjectId,
    createdAtEpoch: Number(proposalState.start_epoch),
  });
  artifact.governance.finalizeScriptPath = finalizeScriptPath;

  const artifactPath = path.join(ARTIFACTS_DIR, `${runId}.json`);
  await writeJson(artifactPath, artifact);

  const summaryPath = path.join(LOGS_DIR, `${runId}.summary.md`);
  await writeText(
    summaryPath,
    [
      '# PaperProof Mainnet Functional Test Summary',
      '',
      `- runId: \`${runId}\``,
      `- Paper A code: \`${artifact.papers.paperA.paperCode}\``,
      `- Paper A record: \`${artifact.papers.paperA.recordId}\``,
      `- Paper A comments tree: \`${artifact.papers.paperA.commentsTreeId}\``,
      `- Paper B code: \`${artifact.papers.paperB.paperCode}\``,
      `- Paper B record: \`${artifact.papers.paperB.recordId}\``,
      `- Paper B comments tree: \`${artifact.papers.paperB.commentsTreeId}\``,
      `- Governance proposal id: \`${artifact.governance.proposalId}\``,
      `- Governance proposal object: \`${artifact.governance.proposalObjectId}\``,
      `- Proposal start epoch: \`${artifact.governance.startEpoch}\``,
      `- Proposal end epoch: \`${artifact.governance.endEpoch}\``,
      `- Finalize script: \`${finalizeScriptPath}\``,
      '',
      'Next step:',
      '',
      `- After epoch \`${artifact.governance.endEpoch}\` is reached, run \`node ./mainnet-governance-finalize.mjs\` from \`${path.dirname(finalizeScriptPath)}\`.`,
    ].join('\n'),
  );

  const logPath = await logger.flush();
  console.log('\nMainnet functional test run completed.');
  console.log('Artifact:', artifactPath);
  console.log('Summary:', summaryPath);
  console.log('Log:', logPath);
  console.log('Finalize script:', finalizeScriptPath);
}

main().catch((error) => {
  console.error('\nMainnet functional test failed.');
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
