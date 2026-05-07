import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  ARTIFACTS_DIR,
  ARTIFACT_TYPES,
  COMMENTS,
  CONTRACTS,
  EXPECTED_ADDRESSES,
  GOVERNANCE,
  MIN_VOTE_STAKE,
  ONE_PPRF,
  PAPERS_DIR,
  PROPOSER_THRESHOLD,
  addBlobComment,
  addOnchainComment,
  addPreprintVersion,
  buildStampedPdf,
  claimLockedTokens,
  createClients,
  createLogger,
  createRunId,
  createSignalProposal,
  decisiveNoVoteAmount,
  ensureRuntimeDirectories,
  fileDescriptor,
  formatMist,
  formatPprf,
  getBalanceByType,
  getCommentNode,
  getCommentsTree,
  getGovernanceConfig,
  getGovernanceVault,
  getLikesBook,
  getProposal,
  getProposalObjectIdByProposalId,
  getRoot,
  getSeries,
  getTypeRegistry,
  governanceOutcomePreview,
  likeArtifact,
  loadAccountsFromEnv,
  parseOptionField,
  publishPreprint,
  publishSoftwareRelease,
  resolveProposalEarly,
  setCommentStatus,
  setTreeStatus,
  transferArtifactOwner,
  transferCoinByType,
  transferSui,
  unlikeArtifact,
  updateSeriesMetadata,
  voteNo,
  writeJson,
} from './paperproof-mainnet-common.mjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SAMPLE_PREPRINT = path.join(__dirname, 'paperSamples', 'Versioned Upgrade Design.pdf');
const SOFTWARE_SAMPLE = path.join(__dirname, 'node_modules', 'pdf-lib', 'package.json');
const SUI_PREFUND_MIST = 80_000_000n;
const WAL_PREFUND_RAW = 5_000_000n;
const PPRF_LIKE_PROOF = ONE_PPRF;
const GOVERNANCE_STAKE = PROPOSER_THRESHOLD;
const DUPLICATE_VOTE_PROBE = MIN_VOTE_STAKE + ONE_PPRF;
const OBJECT_SETTLE_MS = 2_500;

const RUN_HELP = `
PaperProof current mainnet functional smoke

Usage:
  node ./mainnet-functional-test.mjs --validate
  node ./mainnet-functional-test.mjs --run

--validate is read-only.
--run sends real Sui mainnet transactions against the current deployed
PaperProof contracts. It intentionally spends a small amount of SUI/WAL, but
PPRF is temporarily distributed, locked, reclaimed, and checked at the end.
`.trim();

function parseArgs(argv) {
  const args = new Set(argv.slice(2));
  return {
    validate: args.has('--validate'),
    run: args.has('--run'),
    help: args.has('--help') || args.has('-h'),
  };
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function digestOf(execution) {
  return execution?.result?.digest ?? execution?.raw?.digest ?? execution?.digest ?? null;
}

function recordTx(artifact, label, execution) {
  artifact.transactions.push({
    label,
    digest: digestOf(execution),
    status: execution?.expectedFailure ? 'expected-failure' : 'success',
    error: execution?.error ?? null,
  });
}

async function mustExist(filePath) {
  await fs.access(filePath);
  return filePath;
}

function metadataFor(runId, kind) {
  return [
    { key: 'smoke_run', value: runId.slice(0, 63) },
    { key: 'kind', value: kind },
  ];
}

function shortDigest(text) {
  return text.replace(/^sha256:/, '').slice(0, 64);
}

async function settleObjects() {
  await new Promise((resolve) => setTimeout(resolve, OBJECT_SETTLE_MS));
}

async function balancesSnapshot(rpcClient, accounts) {
  const entries = {};
  for (const account of accounts) {
    const [sui, wal, pprf] = await Promise.all([
      getBalanceByType(rpcClient, account.address, '0x2::sui::SUI'),
      getBalanceByType(rpcClient, account.address, CONTRACTS.walType),
      getBalanceByType(rpcClient, account.address, CONTRACTS.pprfType),
    ]);
    entries[account.key] = {
      address: account.address,
      sui: BigInt(sui.totalBalance),
      wal: BigInt(wal.totalBalance),
      pprf: BigInt(pprf.totalBalance),
    };
  }
  return entries;
}

function totalPprf(snapshot) {
  return Object.values(snapshot).reduce((sum, item) => sum + item.pprf, 0n);
}

async function validateEnvironment({ rpcClient, accounts, logger }) {
  logger.write('## Validation');
  const [root, vault, config, registry] = await Promise.all([
    getRoot(rpcClient),
    getGovernanceVault(rpcClient),
    getGovernanceConfig(rpcClient),
    getTypeRegistry(rpcClient),
  ]);

  assert(root.governance_vault_id === CONTRACTS.governanceVaultId, 'Root governance_vault_id mismatch.');
  assert(root.fee_manager_id === CONTRACTS.feeManagerId, 'Root fee_manager_id mismatch.');
  assert(root.type_registry_id === CONTRACTS.typeRegistryId, 'Root type_registry_id mismatch.');
  assert(vault.governance_authority.toLowerCase() === EXPECTED_ADDRESSES.addr4, 'Governance authority should be ADDR_4.');
  assert(vault.active_operator.toLowerCase() === EXPECTED_ADDRESSES.addr4, 'Active operator should be ADDR_4.');
  assert(vault.fee_recipient.toLowerCase() === EXPECTED_ADDRESSES.addr4, 'Fee recipient should be ADDR_4.');
  assert(vault.upgrade_authority.toLowerCase() === EXPECTED_ADDRESSES.addr4, 'Upgrade authority should be ADDR_4.');
  assert(config.registry_id === CONTRACTS.rootId, 'GovernanceConfig registry_id mismatch.');
  assert(BigInt(config.proposer_threshold) === PROPOSER_THRESHOLD, 'Unexpected proposer threshold.');

  await Promise.all([mustExist(SAMPLE_PREPRINT), mustExist(SOFTWARE_SAMPLE)]);

  const balances = await balancesSnapshot(rpcClient, accounts);
  for (const account of accounts) {
    const b = balances[account.key];
    logger.write(
      `- ${account.key} ${account.address}: SUI=${formatMist(b.sui)} WAL=${b.wal} PPRF=${formatPprf(b.pprf)}`,
    );
  }
  logger.write(`- root.paused=${root.paused}`);
  logger.write(`- active_proposal_id=${JSON.stringify(config.active_proposal_id)}`);
  logger.write(`- registry.version=${registry.version}`);

  return { root, vault, config, registry, balances };
}

async function ensureRunFunding({ rpcClient, accounts, logger, artifact }) {
  const [addr1, addr2, addr3, addr4] = accounts;
  const before = await balancesSnapshot(rpcClient, accounts);

  for (const recipient of [addr1, addr2, addr3]) {
    if (before[recipient.key].sui < SUI_PREFUND_MIST) {
      const tx = await transferSui(rpcClient, addr4.signer, recipient.address, SUI_PREFUND_MIST);
      recordTx(artifact, `prefund ${recipient.key} SUI`, tx);
      logger.write(`- prefunded ${recipient.key} with ${formatMist(SUI_PREFUND_MIST)}: ${digestOf(tx)}`);
    }
    if (before[recipient.key].wal < WAL_PREFUND_RAW && before.ADDR_4.wal >= WAL_PREFUND_RAW) {
      const tx = await transferCoinByType(rpcClient, addr4.signer, CONTRACTS.walType, recipient.address, WAL_PREFUND_RAW, 'WAL');
      recordTx(artifact, `prefund ${recipient.key} WAL`, tx);
      logger.write(`- prefunded ${recipient.key} with ${WAL_PREFUND_RAW} raw WAL: ${digestOf(tx)}`);
    }
  }

  for (const recipient of [addr2, addr3]) {
    const latest = await balancesSnapshot(rpcClient, accounts);
    if (latest[recipient.key].pprf < PPRF_LIKE_PROOF) {
      const tx = await transferCoinByType(rpcClient, addr4.signer, CONTRACTS.pprfType, recipient.address, PPRF_LIKE_PROOF, 'PPRF');
      recordTx(artifact, `temporary ${recipient.key} PPRF proof`, tx);
      logger.write(`- temporarily sent ${formatPprf(PPRF_LIKE_PROOF)} to ${recipient.key}: ${digestOf(tx)}`);
    }
  }
}

async function returnParticipantPprf({ rpcClient, accounts, logger, artifact }) {
  const [, addr2, addr3, addr4] = accounts;
  for (const source of [addr2, addr3]) {
    const balance = await getBalanceByType(rpcClient, source.address, CONTRACTS.pprfType);
    const amount = BigInt(balance.totalBalance);
    if (amount > 0n) {
      const tx = await transferCoinByType(rpcClient, source.signer, CONTRACTS.pprfType, addr4.address, amount, 'PPRF');
      recordTx(artifact, `return all ${source.key} PPRF to ADDR_4`, tx);
      logger.write(`- returned ${formatPprf(amount)} from ${source.key} to ADDR_4: ${digestOf(tx)}`);
    }
  }
}

async function ensurePprfBalance({ rpcClient, accounts, target, amount, logger, artifact, label }) {
  const addr4 = accounts[3];
  const balance = await getBalanceByType(rpcClient, target.address, CONTRACTS.pprfType);
  const current = BigInt(balance.totalBalance);
  if (current >= amount) return;
  const needed = amount - current;
  const tx = await transferCoinByType(rpcClient, addr4.signer, CONTRACTS.pprfType, target.address, needed, 'PPRF');
  recordTx(artifact, label ?? `temporary ${target.key} PPRF`, tx);
  logger.write(`- temporarily sent ${formatPprf(needed)} to ${target.key}: ${digestOf(tx)}`);
}

async function settleProposalWithDecisiveNo({
  rpcClient,
  accounts,
  proposalObjectId,
  proposerAccount,
  noVoterAccount,
  logger,
  artifact,
  labelPrefix,
}) {
  const addr4 = accounts[3];
  const noVoter = noVoterAccount ?? accounts[3];
  const proposer = proposerAccount ?? addr4;
  const config = await getGovernanceConfig(rpcClient);
  const before = await getProposal(rpcClient, proposalObjectId);
  if (Number(before.status) !== GOVERNANCE.statusActive) {
    logger.write(`- ${labelPrefix}: proposal already settled with status ${before.status}`);
    return before;
  }

  const noAmount = decisiveNoVoteAmount(config.pprf_total_supply, before.yes_votes, before.no_votes);
  logger.write(`- ${labelPrefix}: decisive counter-vote amount = ${formatPprf(noAmount)} by ${noVoter.key}`);
  await ensurePprfBalance({
    rpcClient,
    accounts,
    target: noVoter,
    amount: noAmount + DUPLICATE_VOTE_PROBE,
    logger,
    artifact,
    label: `${labelPrefix}: temporary ${noVoter.key} counter-vote PPRF`,
  });

  const vote = await voteNo(rpcClient, noVoter.signer, proposalObjectId, noAmount);
  recordTx(artifact, `${labelPrefix}: ${noVoter.key} decisive counter-vote`, vote);

  const afterVote = await getProposal(rpcClient, proposalObjectId);
  const preview = governanceOutcomePreview(config.pprf_total_supply, afterVote.yes_votes, afterVote.no_votes);
  if (!preview.deterministicFail) {
    const topUp = MIN_VOTE_STAKE + ONE_PPRF;
    logger.write(`- ${labelPrefix}: adding ${formatPprf(topUp)} counter-vote margin by ${accounts[2].key}`);
    await ensurePprfBalance({
      rpcClient,
      accounts,
      target: accounts[2],
      amount: topUp,
      logger,
      artifact,
      label: `${labelPrefix}: counter-vote margin PPRF`,
    });
    const marginVote = await voteNo(rpcClient, accounts[2].signer, proposalObjectId, topUp);
    recordTx(artifact, `${labelPrefix}: ${accounts[2].key} counter-vote margin`, marginVote);
    const afterMargin = await getProposal(rpcClient, proposalObjectId);
    const marginPreview = governanceOutcomePreview(config.pprf_total_supply, afterMargin.yes_votes, afterMargin.no_votes);
    assert(marginPreview.deterministicFail, `${labelPrefix}: proposal should be deterministically failed after counter-vote margin.`);
  }

  const duplicateVote = await voteNo(rpcClient, noVoter.signer, proposalObjectId, DUPLICATE_VOTE_PROBE, true);
  recordTx(artifact, `${labelPrefix}: ${noVoter.key} duplicate vote rejected`, duplicateVote);

  const resolved = await resolveProposalEarly(rpcClient, addr4.signer, proposalObjectId);
  recordTx(artifact, `${labelPrefix}: resolve proposal early rejected`, resolved);

  const rejected = await getProposal(rpcClient, proposalObjectId);
  assert(Number(rejected.status) === GOVERNANCE.statusRejected, `${labelPrefix}: expected proposal status REJECTED, got ${rejected.status}.`);

  const claimProposer = await claimLockedTokens(rpcClient, proposer.signer, proposalObjectId);
  recordTx(artifact, `${labelPrefix}: ${proposer.key} reclaim proposer balance`, claimProposer);
  const claimNoVoter = await claimLockedTokens(rpcClient, noVoter.signer, proposalObjectId);
  recordTx(artifact, `${labelPrefix}: ${noVoter.key} reclaim counter-vote balance`, claimNoVoter);
  const duplicateClaim = await claimLockedTokens(rpcClient, noVoter.signer, proposalObjectId, true);
  recordTx(artifact, `${labelPrefix}: ${noVoter.key} duplicate reclaim rejected`, duplicateClaim);

  return getProposal(rpcClient, proposalObjectId);
}

async function settleActiveProposalIfAny({ rpcClient, accounts, validation, logger, artifact }) {
  const activeProposalId = parseOptionField(validation.config.active_proposal_id);
  if (activeProposalId === null) return;
  logger.write('\n## Recovery - Settle existing active governance proposal');
  const proposalObjectId = await getProposalObjectIdByProposalId(rpcClient, validation.config, activeProposalId);
  logger.write(`- active proposal ${activeProposalId}: ${proposalObjectId}`);
  artifact.recoveredActiveProposal = { proposalId: activeProposalId, proposalObjectId };
  await settleProposalWithDecisiveNo({
    rpcClient,
    accounts,
    proposalObjectId,
    proposerAccount: accounts[3],
    noVoterAccount: accounts[1],
    logger,
    artifact,
    labelPrefix: `recover proposal ${activeProposalId}`,
  });
  await returnParticipantPprf({ rpcClient, accounts, logger, artifact });
  const configAfter = await getGovernanceConfig(rpcClient);
  assert(parseOptionField(configAfter.active_proposal_id) === null, 'active_proposal_id should be empty after recovery settlement.');
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
  const [addr1, addr2, addr3, addr4] = accounts;
  const { rpcClient } = createClients();

  const artifact = {
    runId,
    mode: args.validate ? 'validate' : 'run',
    contracts: CONTRACTS,
    accounts: accounts.map(({ key, role, address }) => ({ key, role, address })),
    transactions: [],
    preprint: {},
    softwareRelease: {},
    governance: {},
  };

  logger.write('# PaperProof Current Mainnet Functional Smoke');
  logger.write(`- runId: ${runId}`);
  logger.write(`- mode: ${artifact.mode}`);
  logger.write(`- root: ${CONTRACTS.rootId}`);
  logger.write(`- publishing package: ${CONTRACTS.publishingPackageId}`);
  logger.write(`- comments package: ${CONTRACTS.commentsPackageId}`);
  logger.write(`- governance package latest: ${CONTRACTS.governancePackageId}`);
  logger.write('');

  const validation = await validateEnvironment({ rpcClient, accounts, logger });
  artifact.validation = {
    pprfTotalAcrossEnvAccounts: totalPprf(validation.balances).toString(),
    activeProposalId: validation.config.active_proposal_id,
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

  await settleActiveProposalIfAny({ rpcClient, accounts, validation, logger, artifact });
  const postRecoveryBalances = await balancesSnapshot(rpcClient, accounts);
  const postRecoveryConfig = await getGovernanceConfig(rpcClient);
  assert(parseOptionField(postRecoveryConfig.active_proposal_id) === null, 'An active proposal still exists after recovery.');
  validation.balances = postRecoveryBalances;
  const pprfBefore = totalPprf(validation.balances);

  logger.write('\n## Phase 1 - Funding and PPRF guardrails');
  await ensureRunFunding({ rpcClient, accounts, logger, artifact });

  logger.write('\n## Phase 2 - Publish preprint and add version');
  const stamped = await buildStampedPdf(SAMPLE_PREPRINT, runId.slice(-24), PAPERS_DIR);
  const preprint1 = await publishPreprint(rpcClient, addr1.signer, {
    title: `PaperProof Mainnet Preprint Smoke ${runId.slice(-8)}`,
    abstractText:
      'A live mainnet preprint smoke artifact that exercises current publishing, comments, likes, metadata, and version flows.',
    authors: ['PaperProof Labs', 'Mainnet JS Harness'],
    keywords: ['paperproof', 'preprint', 'mainnet', 'smoke'],
    field: 'Computer Science',
    license: 'PaperProof Source-Available License',
    pageCount: 1,
    contentHash: stamped.hash,
    walrusBlobId: `local-preprint-${stamped.shortHash}`,
    walrusBlobObjectId: stamped.shortHash,
    contentType: 'application/pdf',
    seriesMetadata: metadataFor(runId, 'preprint-series'),
    versionMetadata: [{ key: 'source', value: 'jstest-pdf-sample' }],
  });
  recordTx(artifact, 'publish preprint', preprint1.raw);
  artifact.preprint = {
    seriesId: preprint1.series_id,
    version1Id: preprint1.version_id,
    artifactCode: preprint1.artifact_code,
    commentsTreeId: preprint1.comments_tree_id,
    likesBookId: preprint1.likes_book_id,
    file: stamped.filePath,
  };
  logger.write(`- preprint series: ${preprint1.series_id}`);
  logger.write(`- artifact code: ${preprint1.artifact_code}`);
  logger.write(`- comments tree: ${preprint1.comments_tree_id}`);
  logger.write(`- likes book: ${preprint1.likes_book_id}`);
  assert(String(preprint1.artifact_code).startsWith('PaperProof-preprint-'), 'Unexpected preprint artifact code format.');

  const seriesAfterPublish = await getSeries(rpcClient, preprint1.series_id);
  assert(seriesAfterPublish.comments_tree_id === preprint1.comments_tree_id, 'Series comments_tree_id mismatch.');
  assert(seriesAfterPublish.likes_book_id === preprint1.likes_book_id, 'Series likes_book_id mismatch.');
  assert(Number(seriesAfterPublish.artifact_type) === ARTIFACT_TYPES.preprint, 'Series artifact type mismatch.');

  const updateMetadata = await updateSeriesMetadata(rpcClient, addr1.signer, preprint1.series_id, [
    { key: 'smoke_run', value: runId.slice(0, 63) },
    { key: 'updated', value: 'true' },
  ]);
  recordTx(artifact, 'update preprint series metadata', updateMetadata);

  const stampedV2 = await buildStampedPdf(SAMPLE_PREPRINT, `${runId.slice(-18)}-v2`, PAPERS_DIR);
  const preprintV2 = await addPreprintVersion(rpcClient, addr1.signer, {
    seriesId: preprint1.series_id,
    title: `PaperProof Mainnet Preprint Smoke ${runId.slice(-8)} v2`,
    abstractText: 'Second version for the live mainnet smoke test. The version metadata is intentionally immutable.',
    authors: ['PaperProof Labs', 'Mainnet JS Harness'],
    keywords: ['paperproof', 'preprint', 'version2'],
    field: 'Computer Science',
    license: 'PaperProof Source-Available License',
    pageCount: 1,
    contentHash: stampedV2.hash,
    walrusBlobId: `local-preprint-v2-${stampedV2.shortHash}`,
    walrusBlobObjectId: stampedV2.shortHash,
    contentType: 'application/pdf',
    versionMetadata: [{ key: 'version_note', value: 'second-version' }],
  });
  recordTx(artifact, 'add preprint version', preprintV2.raw);
  artifact.preprint.version2Id = preprintV2.new_version_id;
  const seriesAfterV2 = await getSeries(rpcClient, preprint1.series_id);
  assert(Number(seriesAfterV2.current_version) === 2, 'Preprint current_version should be 2.');
  assert(seriesAfterV2.current_version_id === preprintV2.new_version_id, 'Preprint current_version_id mismatch.');

  logger.write('\n## Phase 3 - Comments and likes');
  const comment1 = await addOnchainComment(rpcClient, addr2.signer, {
    treeId: preprint1.comments_tree_id,
    parentCommentId: 0,
    content: 'ADDR_2 top-level comment from current mainnet JS smoke.',
  });
  recordTx(artifact, 'add top-level comment', comment1.raw);
  await settleObjects();
  const reply1 = await addOnchainComment(rpcClient, addr3.signer, {
    treeId: preprint1.comments_tree_id,
    parentCommentId: comment1.comment_id,
    content: 'ADDR_3 reply to ADDR_2 comment.',
  });
  recordTx(artifact, 'add reply comment', reply1.raw);
  await settleObjects();
  const hideByTreeOwner = await setCommentStatus(
    rpcClient,
    addr1.signer,
    preprint1.comments_tree_id,
    reply1.comment_id,
    COMMENTS.commentStatusHidden,
  );
  recordTx(artifact, 'tree owner hides reply', hideByTreeOwner);
  await settleObjects();
  const authorRestoreHidden = await setCommentStatus(
    rpcClient,
    addr3.signer,
    preprint1.comments_tree_id,
    reply1.comment_id,
    COMMENTS.commentStatusActive,
    true,
  );
  recordTx(artifact, 'hidden comment author cannot restore active', authorRestoreHidden);
  await settleObjects();
  const hiddenNode = await getCommentNode(rpcClient, preprint1.comments_tree_id, reply1.comment_id);
  assert(Number(hiddenNode.status) === COMMENTS.commentStatusHidden, 'Hidden reply should remain hidden.');

  const blobPayload = new TextEncoder().encode('blob-backed comment body kept off-chain for smoke coverage');
  const blobComment = await addBlobComment(rpcClient, addr2.signer, {
    treeId: preprint1.comments_tree_id,
    parentCommentId: comment1.comment_id,
    blobIdBytes: new TextEncoder().encode(`local-blob-${runId}`),
    blobObjectId: null,
    blobDigestBytes: new Uint8Array(Buffer.from(await import('node:crypto').then(({ default: c }) => c.createHash('sha256').update(blobPayload).digest()))),
    previewBytes: blobPayload.slice(0, 48),
  });
  recordTx(artifact, 'add blob-backed comment', blobComment.raw);
  artifact.preprint.commentIds = [comment1.comment_id, reply1.comment_id, blobComment.comment_id];
  await settleObjects();

  const like = await likeArtifact(rpcClient, addr2.signer, preprint1.likes_book_id);
  recordTx(artifact, 'ADDR_2 like preprint', like);
  await settleObjects();
  const duplicateLike = await likeArtifact(rpcClient, addr2.signer, preprint1.likes_book_id).catch((error) => ({
    expectedFailure: true,
    error: error.message,
  }));
  recordTx(artifact, 'ADDR_2 duplicate like rejected', duplicateLike);
  await settleObjects();
  const unlike = await unlikeArtifact(rpcClient, addr2.signer, preprint1.likes_book_id);
  recordTx(artifact, 'ADDR_2 unlike preprint', unlike);
  await settleObjects();
  const unlikeAgain = await unlikeArtifact(rpcClient, addr2.signer, preprint1.likes_book_id).catch((error) => ({
    expectedFailure: true,
    error: error.message,
  }));
  recordTx(artifact, 'ADDR_2 duplicate unlike rejected', unlikeAgain);
  const likeBookAfter = await getLikesBook(rpcClient, preprint1.likes_book_id);
  assert(Number(likeBookAfter.like_count) === 0, `Expected like_count 0 after unlike, got ${likeBookAfter.like_count}.`);

  const lockTree = await setTreeStatus(rpcClient, addr1.signer, preprint1.comments_tree_id, COMMENTS.treeStatusLocked);
  recordTx(artifact, 'lock comments tree', lockTree);
  await settleObjects();
  const commentWhileLocked = await addOnchainComment(rpcClient, addr2.signer, {
    treeId: preprint1.comments_tree_id,
    parentCommentId: 0,
    content: 'This should fail while tree is locked.',
  }).catch((error) => ({ expectedFailure: true, error: error.message }));
  recordTx(artifact, 'comment rejected while tree locked', commentWhileLocked);
  await settleObjects();
  const reopenTree = await setTreeStatus(rpcClient, addr1.signer, preprint1.comments_tree_id, COMMENTS.treeStatusOpen);
  recordTx(artifact, 'reopen comments tree', reopenTree);
  await settleObjects();

  logger.write('\n## Phase 4 - Transfer series owner and verify comments owner sync');
  const transferOwner = await transferArtifactOwner(rpcClient, addr1.signer, preprint1.series_id, preprint1.comments_tree_id, addr3.address);
  recordTx(artifact, 'transfer preprint owner to ADDR_3', transferOwner);
  const oldOwnerMetadata = await updateSeriesMetadata(rpcClient, addr1.signer, preprint1.series_id, [
    { key: 'should_fail', value: 'old-owner' },
  ]).catch((error) => ({ expectedFailure: true, error: error.message }));
  recordTx(artifact, 'old owner cannot update metadata', oldOwnerMetadata);
  const newOwnerMetadata = await updateSeriesMetadata(rpcClient, addr3.signer, preprint1.series_id, [
    { key: 'owner', value: 'ADDR_3' },
    { key: 'smoke_run', value: runId.slice(0, 63) },
  ]);
  recordTx(artifact, 'new owner updates metadata', newOwnerMetadata);
  const treeAfterTransfer = await getCommentsTree(rpcClient, preprint1.comments_tree_id);
  assert(treeAfterTransfer.owner.toLowerCase() === addr3.address, 'Comments tree owner did not follow series owner.');

  logger.write('\n## Phase 5 - Publish software release sample from node_modules');
  const softwareFile = await fileDescriptor(SOFTWARE_SAMPLE);
  const software = await publishSoftwareRelease(rpcClient, addr2.signer, {
    projectName: 'pdf-lib package smoke sample',
    versionName: 'node_modules-sample',
    sourceHash: shortDigest(softwareFile.hash),
    packageHash: shortDigest(softwareFile.hash),
    changelog: 'Small package metadata file from node_modules used to exercise the software_release artifact type.',
    license: 'MIT',
    repositoryUrl: 'https://github.com/Hopding/pdf-lib',
    contentHash: softwareFile.hash,
    walrusBlobId: `local-software-${softwareFile.shortHash}`,
    walrusBlobObjectId: softwareFile.shortHash,
    contentType: 'application/json',
    seriesMetadata: metadataFor(runId, 'software-release-series'),
    versionMetadata: [{ key: 'source_path', value: 'node_modules/pdf-lib/package.json' }],
  });
  recordTx(artifact, 'publish software release', software.raw);
  artifact.softwareRelease = {
    seriesId: software.series_id,
    version1Id: software.version_id,
    artifactCode: software.artifact_code,
    commentsTreeId: software.comments_tree_id,
    likesBookId: software.likes_book_id,
    sourceFile: SOFTWARE_SAMPLE,
  };
  assert(String(software.artifact_code).startsWith('PaperProof-software_release-'), 'Unexpected software artifact code.');
  const softwareSeries = await getSeries(rpcClient, software.series_id);
  assert(Number(softwareSeries.artifact_type) === ARTIFACT_TYPES.softwareRelease, 'Software artifact type mismatch.');

  logger.write('\n## Phase 6 - Governance signal proposal and PPRF reclaim');
  await ensurePprfBalance({
    rpcClient,
    accounts,
    target: addr2,
    amount: GOVERNANCE_STAKE,
    logger,
    artifact,
    label: 'temporary ADDR_2 proposer PPRF',
  });
  const proposal = await createSignalProposal(rpcClient, addr2.signer, {
    title: `PaperProof JS smoke signal ${runId.slice(-8)}`,
    description: 'Live mainnet signal proposal created by the current JS smoke harness. It is intentionally rejected and reclaimed.',
    payloadText: `smoke ${runId}`,
    stakeAmountRaw: GOVERNANCE_STAKE,
    payloadAddress: addr2.address,
  });
  recordTx(artifact, 'create signal proposal', proposal.raw);
  artifact.governance = {
    proposalId: proposal.proposal_id,
    proposalObjectId: proposal.proposal_object_id,
  };
  await settleProposalWithDecisiveNo({
    rpcClient,
    accounts,
    proposalObjectId: proposal.proposal_object_id,
    proposerAccount: addr2,
    noVoterAccount: addr4,
    logger,
    artifact,
    labelPrefix: 'current proposal',
  });

  logger.write('\n## Phase 7 - PPRF return and final checks');
  await returnParticipantPprf({ rpcClient, accounts, logger, artifact });
  const finalBalances = await balancesSnapshot(rpcClient, accounts);
  const pprfAfter = totalPprf(finalBalances);
  artifact.finalBalances = Object.fromEntries(
    Object.entries(finalBalances).map(([key, value]) => [
      key,
      {
        address: value.address,
        sui: value.sui.toString(),
        wal: value.wal.toString(),
        pprf: value.pprf.toString(),
      },
    ]),
  );
  artifact.pprfGuard = {
    before: pprfBefore.toString(),
    after: pprfAfter.toString(),
    delta: (pprfAfter - pprfBefore).toString(),
  };
  assert(pprfAfter === pprfBefore, `PPRF total across .env accounts changed: before=${pprfBefore} after=${pprfAfter}.`);
  assert(finalBalances.ADDR_2.pprf === 0n, 'ADDR_2 should end with 0 PPRF after return.');
  assert(finalBalances.ADDR_3.pprf === 0n, 'ADDR_3 should end with 0 PPRF after return.');

  const artifactPath = path.join(ARTIFACTS_DIR, `${runId}.json`);
  await writeJson(artifactPath, artifact);
  const logPath = await logger.flush();
  console.log('\nMainnet smoke run finished successfully.');
  console.log('Artifact:', artifactPath);
  console.log('Log:', logPath);
}

async function emergencyReturnLoosePprf() {
  try {
    const accounts = loadAccountsFromEnv();
    const { rpcClient } = createClients();
    const [, addr2, addr3, addr4] = accounts;
    const config = await getGovernanceConfig(rpcClient);
    const activeProposalId = parseOptionField(config.active_proposal_id);
    if (activeProposalId !== null) {
      console.error(`Emergency settling active proposal ${activeProposalId} before loose balance return...`);
      const proposalObjectId = await getProposalObjectIdByProposalId(rpcClient, config, activeProposalId);
      let proposal = await getProposal(rpcClient, proposalObjectId);
      let preview = governanceOutcomePreview(config.pprf_total_supply, proposal.yes_votes, proposal.no_votes);
      if (!preview.deterministicFail) {
        const margin = MIN_VOTE_STAKE + ONE_PPRF;
        const b3 = BigInt((await getBalanceByType(rpcClient, addr3.address, CONTRACTS.pprfType)).totalBalance);
        if (b3 < margin) {
          const tx = await transferCoinByType(rpcClient, addr4.signer, CONTRACTS.pprfType, addr3.address, margin - b3, 'PPRF');
          console.error(`Emergency margin transfer tx: ${digestOf(tx)}`);
        }
        const vote = await voteNo(rpcClient, addr3.signer, proposalObjectId, margin);
        console.error(`Emergency margin counter-vote tx: ${digestOf(vote)}`);
        proposal = await getProposal(rpcClient, proposalObjectId);
        preview = governanceOutcomePreview(config.pprf_total_supply, proposal.yes_votes, proposal.no_votes);
      }
      if (preview.deterministicFail) {
        const settle = await resolveProposalEarly(rpcClient, addr4.signer, proposalObjectId);
        console.error(`Emergency early settlement tx: ${digestOf(settle)}`);
        for (const account of [addr2, addr3, addr4]) {
          const claim = await claimLockedTokens(rpcClient, account.signer, proposalObjectId, true);
          if (claim.expectedFailure) {
            console.error(`Emergency ${account.key} reclaim skipped: ${claim.error}`);
          } else {
            console.error(`Emergency ${account.key} reclaim tx: ${digestOf(claim)}`);
          }
        }
      }
    }
    for (const source of [addr2, addr3]) {
      const balance = await getBalanceByType(rpcClient, source.address, CONTRACTS.pprfType);
      const amount = BigInt(balance.totalBalance);
      if (amount > 0n) {
        console.error(`Emergency returning ${formatPprf(amount)} from ${source.key} to ADDR_4...`);
        const tx = await transferCoinByType(rpcClient, source.signer, CONTRACTS.pprfType, addr4.address, amount, 'PPRF');
        console.error(`Emergency ${source.key} PPRF return tx: ${digestOf(tx)}`);
      }
    }

    let total = 0n;
    for (const account of accounts) {
      const balance = await getBalanceByType(rpcClient, account.address, CONTRACTS.pprfType);
      total += BigInt(balance.totalBalance);
    }
    console.error(`Emergency PPRF total across .env accounts: ${formatPprf(total)} (${total})`);
  } catch (returnError) {
    console.error('Emergency loose PPRF return failed; inspect balances before continuing.');
    console.error(returnError instanceof Error ? returnError.stack ?? returnError.message : String(returnError));
  }
}

main().catch(async (error) => {
  console.error('\nMainnet smoke run failed.');
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  await emergencyReturnLoosePprf();
  process.exitCode = 1;
});
