import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  CONTRACTS,
  claimLockedTokens,
  createClients,
  createLogger,
  createRunId,
  ensureRuntimeDirectories,
  finalizeProposal,
  getGovernanceConfig,
  getGovernanceVault,
  getProposal,
  loadAccountsFromEnv,
  parseOptionField,
  writeJson,
} from './paperproof-mainnet-common.mjs';

const HARDCODED = Object.freeze({
  proposalId: 1,
  proposalObjectId: '0xde9f6d23daeaf22e6d38ca8677191e5cab4f5da8fab8bf52e4b81f5a0c7b5c81',
  expectedCommentsFeeLevel: 0,
  createdByRunId: 'mainnet-functional-test-2026-05-06T15-07-04-231Z',
  createdAtEpoch: 1119,
  finalizeSigner: 'ADDR_1',
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
    throw new Error(`Missing signer entry ${HARDCODED.finalizeSigner}.`);
  }

  logger.write('# Governance Finalize Run');
  logger.write(`- proposalId: ${HARDCODED.proposalId}`);
  logger.write(`- proposalObjectId: ${HARDCODED.proposalObjectId}`);
  logger.write(`- signer: ${HARDCODED.finalizeSigner} (${signerEntry.address})`);
  logger.write(`- createdByRunId: ${HARDCODED.createdByRunId}`);
  logger.write(`- createdAtEpoch: ${HARDCODED.createdAtEpoch}`);

  const before = await getProposal(rpcClient, HARDCODED.proposalObjectId);
  logger.write(`- current status before finalize: ${before.status}`);
  logger.write(`- current epoch window: start=${before.start_epoch}, end=${before.end_epoch}`);
  const systemState = await rpcClient.getLatestSuiSystemState();
  logger.write(`- current chain epoch: ${systemState.epoch}`);
  if (BigInt(systemState.epoch) <= BigInt(before.end_epoch)) {
    throw new Error(
      `Proposal voting is still active. Current epoch is ${systemState.epoch}, but the proposal only becomes finalizable after epoch ${before.end_epoch}.`,
    );
  }

  const finalized = await finalizeProposal(rpcClient, signerEntry.signer, HARDCODED.proposalObjectId);
  logger.write(`- finalize tx digest: ${finalized.result?.digest ?? finalized.digest}`);

  const after = await getProposal(rpcClient, HARDCODED.proposalObjectId);
  logger.write(`- status after finalize: ${after.status}`);
  if (Number(after.status) !== 3) {
    throw new Error(`Expected proposal to be REJECTED (3), got ${after.status}.`);
  }

  const claimFounder = await claimLockedTokens(rpcClient, accounts[0].signer, HARDCODED.proposalObjectId);
  logger.write(`- claim tx by ADDR_1: ${claimFounder.result?.digest ?? claimFounder.digest}`);

  const noVoteClaimAddr2 = await claimLockedTokens(rpcClient, accounts[1].signer, HARDCODED.proposalObjectId, true);
  logger.write(`- claim by ADDR_2 rejected as expected (no successful vote recorded): ${noVoteClaimAddr2.error ?? 'execution failure'}`);

  const noVoteClaimAddr3 = await claimLockedTokens(rpcClient, accounts[2].signer, HARDCODED.proposalObjectId, true);
  logger.write(`- claim by ADDR_3 rejected as expected (no successful vote recorded): ${noVoteClaimAddr3.error ?? 'execution failure'}`);

  const duplicateClaimFounder = await claimLockedTokens(rpcClient, accounts[0].signer, HARDCODED.proposalObjectId, true);
  logger.write(`- duplicate claim by ADDR_1 rejected as expected: ${duplicateClaimFounder.error ?? 'execution failure'}`);

  const [vault, config] = await Promise.all([
    getGovernanceVault(rpcClient),
    getGovernanceConfig(rpcClient),
  ]);
  if (Number(vault.comments_fee_level) !== HARDCODED.expectedCommentsFeeLevel) {
    throw new Error(`comments_fee_level changed unexpectedly to ${vault.comments_fee_level}.`);
  }
  if (parseOptionField(config.active_proposal_id) !== null) {
    throw new Error('GovernanceConfig.active_proposal_id should be empty after finalize.');
  }

  const artifact = {
    runId,
    hardcoded: HARDCODED,
    finalizedStatus: Number(after.status),
    finalizeTxDigest: finalized.result?.digest ?? finalized.digest,
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

  const artifactPath = path.join(__dirname, 'artifacts', `${runId}.json`);
  await writeJson(artifactPath, artifact);
  const logPath = await logger.flush();

  console.log('\nFinalize completed successfully.');
  console.log('Artifact:', artifactPath);
  console.log('Log:', logPath);
}

main().catch((error) => {
  console.error('\nGovernance finalize script failed.');
  console.error(error);
  process.exitCode = 1;
});
