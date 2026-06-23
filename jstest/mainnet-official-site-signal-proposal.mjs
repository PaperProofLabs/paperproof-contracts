import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  CONTRACTS,
  GOVERNANCE,
  ONE_PPRF,
  PROPOSER_THRESHOLD,
  claimLockedTokens,
  createClients,
  createLogger,
  createRunId,
  createSignalProposal,
  ensureRuntimeDirectories,
  formatPprf,
  getBalanceByType,
  getGovernanceConfig,
  getProposal,
  governanceOutcomePreview,
  loadAccountsFromEnv,
  parseOptionField,
  resolveProposalEarly,
  sleep,
  transferCoinByType,
  voteYes,
  writeJson,
} from './paperproof-mainnet-common.mjs';

const YES_VOTE_AMOUNT = 5_800_000_000n * ONE_PPRF;

function digestOf(tx) {
  return tx?.result?.digest ?? tx?.digest ?? null;
}

function explorerTx(digest) {
  return `https://suivision.xyz/txblock/${digest}`;
}

function explorerObject(objectId) {
  return `https://suivision.xyz/object/${objectId}`;
}

async function pprfBalance(rpcClient, account) {
  const balance = await getBalanceByType(rpcClient, account.address, CONTRACTS.pprfType);
  return BigInt(balance.totalBalance);
}

async function pprfSnapshot(rpcClient, accounts) {
  const entries = await Promise.all(accounts.map(async (account) => [
    account.key,
    {
      address: account.address,
      pprf: (await pprfBalance(rpcClient, account)).toString(),
    },
  ]));
  return Object.fromEntries(entries);
}

function totalPprf(snapshot) {
  return Object.values(snapshot).reduce((sum, entry) => sum + BigInt(entry.pprf), 0n);
}

async function ensurePprf({ rpcClient, accounts, target, amount, logger, artifact, label }) {
  const custodian = accounts[3];
  const current = await pprfBalance(rpcClient, target);
  if (current >= amount) {
    logger.write(`- ${target.key} already has ${formatPprf(current)}.`);
    return null;
  }
  const needed = amount - current;
  const tx = await transferCoinByType(rpcClient, custodian.signer, CONTRACTS.pprfType, target.address, needed, 'PPRF');
  artifact.transactions.push({ label, digest: digestOf(tx), explorer: explorerTx(digestOf(tx)) });
  logger.write(`- ${label}: ${formatPprf(needed)} -> ${target.key}, tx ${digestOf(tx)}`);
  return tx;
}

async function returnLoosePprf({ rpcClient, accounts, logger, artifact }) {
  const custodian = accounts[3];
  for (const source of [accounts[1], accounts[2]]) {
    const amount = await pprfBalance(rpcClient, source);
    if (amount > 0n) {
      const tx = await transferCoinByType(rpcClient, source.signer, CONTRACTS.pprfType, custodian.address, amount, 'PPRF');
      artifact.transactions.push({ label: `return ${source.key} loose PPRF`, digest: digestOf(tx), explorer: explorerTx(digestOf(tx)) });
      logger.write(`- returned ${formatPprf(amount)} from ${source.key} to ADDR_4, tx ${digestOf(tx)}`);
    } else {
      logger.write(`- ${source.key} has no loose PPRF to return.`);
    }
  }
}

async function waitForProposalStatus(rpcClient, proposalObjectId, expectedStatus, attempts = 12) {
  let latest = null;
  for (let index = 0; index < attempts; index += 1) {
    latest = await getProposal(rpcClient, proposalObjectId);
    if (Number(latest.status) === expectedStatus) return latest;
    await sleep(1_500);
  }
  return latest;
}

async function main() {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);

  await ensureRuntimeDirectories();
  const runId = createRunId('official-site-signal-proposal');
  const logger = createLogger(runId);
  const accounts = loadAccountsFromEnv();
  const { rpcClient } = createClients();
  const [, proposer, yesVoter, resolver] = accounts;

  const artifact = {
    runId,
    proposal: null,
    transactions: [],
    initialBalances: null,
    finalBalances: null,
    pprfGuard: null,
  };

  logger.write('# Official Website Signal Policy Proposal');
  logger.write(`- runId: ${runId}`);
  logger.write(`- proposer: ${proposer.key} ${proposer.address}`);
  logger.write(`- yes voter: ${yesVoter.key} ${yesVoter.address}`);
  logger.write(`- resolver/custodian: ${resolver.key} ${resolver.address}`);

  const configBefore = await getGovernanceConfig(rpcClient);
  const activeProposalId = parseOptionField(configBefore.active_proposal_id);
  if (activeProposalId !== null) {
    throw new Error(`Governance already has active proposal id ${activeProposalId}; settle it before creating a new proposal.`);
  }

  artifact.initialBalances = await pprfSnapshot(rpcClient, accounts);
  const initialTotal = totalPprf(artifact.initialBalances);
  logger.write(`- initial PPRF total across .env accounts: ${formatPprf(initialTotal)}`);

  await ensurePprf({
    rpcClient,
    accounts,
    target: proposer,
    amount: PROPOSER_THRESHOLD,
    logger,
    artifact,
    label: 'fund proposer stake',
  });
  await ensurePprf({
    rpcClient,
    accounts,
    target: yesVoter,
    amount: YES_VOTE_AMOUNT,
    logger,
    artifact,
    label: 'fund decisive YES vote',
  });

  const proposal = await createSignalProposal(rpcClient, proposer.signer, {
    actionType: GOVERNANCE.actionSignalPolicyPosition,
    title: 'Signal: publish the official PaperProof protocol website',
    description:
      'This signal proposal supports publishing https://paperproof.site/ as the official PaperProof Protocol website for protocol discovery, documentation, artifact browsing, governance visibility, and community onboarding.',
    payloadText:
      'Policy position: PaperProof governance supports https://paperproof.site/ as the official protocol website and public entry point for PaperProof artifacts, documentation, governance, and community-facing protocol operations.',
    payloadAddress: proposer.address,
    stakeAmountRaw: PROPOSER_THRESHOLD,
  });
  artifact.transactions.push({ label: 'create signal policy proposal', digest: digestOf(proposal.raw), explorer: explorerTx(digestOf(proposal.raw)) });
  artifact.proposal = {
    proposalId: proposal.proposal_id,
    proposalObjectId: proposal.proposal_object_id,
    objectExplorer: explorerObject(proposal.proposal_object_id),
    actionType: GOVERNANCE.actionSignalPolicyPosition,
  };
  logger.write(`- created proposal id ${proposal.proposal_id}`);
  logger.write(`- proposal object: ${proposal.proposal_object_id}`);
  logger.write(`- create tx: ${digestOf(proposal.raw)}`);

  const yesVote = await voteYes(rpcClient, yesVoter.signer, proposal.proposal_object_id, YES_VOTE_AMOUNT);
  artifact.transactions.push({ label: 'decisive YES vote', digest: digestOf(yesVote), explorer: explorerTx(digestOf(yesVote)) });
  logger.write(`- YES vote by ${yesVoter.key}: ${formatPprf(YES_VOTE_AMOUNT)}, tx ${digestOf(yesVote)}`);

  const afterVote = await getProposal(rpcClient, proposal.proposal_object_id);
  const preview = governanceOutcomePreview(configBefore.pprf_total_supply, afterVote.yes_votes, afterVote.no_votes);
  logger.write(`- yes votes: ${formatPprf(afterVote.yes_votes)}`);
  logger.write(`- no votes: ${formatPprf(afterVote.no_votes)}`);
  logger.write(`- early determinable: ${preview.determinable}, deterministic pass: ${preview.deterministicPass}`);
  if (!preview.deterministicPass) {
    throw new Error('Proposal is not yet deterministically passing; refusing early resolve.');
  }

  const resolved = await resolveProposalEarly(rpcClient, resolver.signer, proposal.proposal_object_id);
  artifact.transactions.push({ label: 'early resolve proposal', digest: digestOf(resolved), explorer: explorerTx(digestOf(resolved)) });
  logger.write(`- early resolved: ${digestOf(resolved)}`);

  const settled = await waitForProposalStatus(rpcClient, proposal.proposal_object_id, GOVERNANCE.statusPassed);
  artifact.proposal.finalStatus = Number(settled.status);
  artifact.proposal.yesVotes = String(settled.yes_votes);
  artifact.proposal.noVotes = String(settled.no_votes);
  logger.write(`- final proposal status: ${settled.status}`);
  if (Number(settled.status) !== GOVERNANCE.statusPassed) {
    throw new Error(`Expected proposal PASSED (${GOVERNANCE.statusPassed}), got ${settled.status}.`);
  }

  for (const voter of [proposer, yesVoter]) {
    const claim = await claimLockedTokens(rpcClient, voter.signer, proposal.proposal_object_id);
    artifact.transactions.push({ label: `${voter.key} claim locked PPRF`, digest: digestOf(claim), explorer: explorerTx(digestOf(claim)) });
    logger.write(`- ${voter.key} claimed locked PPRF: ${digestOf(claim)}`);
  }

  await returnLoosePprf({ rpcClient, accounts, logger, artifact });

  artifact.finalBalances = await pprfSnapshot(rpcClient, accounts);
  const finalTotal = totalPprf(artifact.finalBalances);
  artifact.pprfGuard = {
    before: initialTotal.toString(),
    after: finalTotal.toString(),
    delta: (finalTotal - initialTotal).toString(),
  };
  logger.write(`- final PPRF total across .env accounts: ${formatPprf(finalTotal)}`);
  logger.write(`- PPRF total delta: ${artifact.pprfGuard.delta}`);

  if (finalTotal !== initialTotal) {
    throw new Error(`PPRF total changed across .env accounts: before=${initialTotal}, after=${finalTotal}.`);
  }

  const artifactPath = path.join(__dirname, 'artifacts', `${runId}.json`);
  await writeJson(artifactPath, artifact);
  const logPath = await logger.flush();

  console.log('\nOfficial website signal proposal completed successfully.');
  console.log('Proposal object:', proposal.proposal_object_id);
  console.log('Proposal explorer:', explorerObject(proposal.proposal_object_id));
  console.log('Artifact:', artifactPath);
  console.log('Log:', logPath);
}

main().catch(async (error) => {
  console.error('\nOfficial website signal proposal failed.');
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exitCode = 1;
});
