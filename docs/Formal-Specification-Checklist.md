<!--
Copyright (c) 2026 PaperProof Labs. All rights reserved.
SPDX-License-Identifier: LicenseRef-PaperProof-Docs-Source-Available
-->

# PaperProof Move/Sui Formal Specification Checklist

This document lists a comprehensive set of candidate formal specifications for
the PaperProof Move contracts. It is written as a prover-oriented checklist
rather than a user-facing tutorial.

The goals are:

1. identify the highest-value invariants and safety properties;
2. separate prover-friendly properties from broader review goals;
3. give each property a priority:
   - `P0`: highest-value, should be proved or tightly regression-tested first
   - `P1`: important protocol safety and integrity properties
   - `P2`: useful hardening properties, lower immediate payoff

The checklist is intentionally broader than what a first prover pass should
attempt. A realistic rollout should start with P0 governance, publishing
identity, and comments binding properties, then expand outward.

## Module Map

- `publishing/sources/artifact_types.move`
- `publishing/sources/validation.move`
- `publishing/sources/publishing.move`
- `governance/sources/governance.move`
- `governance/sources/governance_voting.move`
- `comments/sources/comments.move`

## Recommended First Wave

If only a small initial prover budget is available, start with:

- P0-01 through P0-12
- P0-25 through P0-40
- P0-61 through P0-76

Those cover governance liveness, locked-token correctness, preprint reserve
integrity, artifact identity continuity, fee binding, comment-tree binding, and
likes correctness.

---

## 1. `publishing::artifact_types`

### P0

1. `P0-01` Supported artifact type space is closed:
   only the six built-in values are accepted by `assert_supported`.

2. `P0-02` Artifact code generation is deterministic:
   for the same `(artifact_type, epoch, series_id)`, `code(...)` always returns
   the same string.

3. `P0-03` Distinct supported artifact types produce distinct human-readable
   type names through `name(...)`.

4. `P0-04` Distinct supported artifact types produce distinct code prefixes
   inside `code(...)`, so type confusion cannot arise purely from code format.

### P1

5. `P1-05` `name(...)` aborts for unsupported artifact types and never silently
   maps an unknown value to a valid built-in name.

6. `P1-06` `code(...)` aborts for unsupported artifact types and never emits a
   syntactically valid code for an invalid type.

7. `P1-07` `id_hex_prefix_12(...)` only depends on the first six bytes of the
   object ID and never reads out of bounds.

8. `P1-08` `epoch6_to_string(...)` always returns a fixed-width six-digit
   decimal string for epochs inside intended operating range.

### P2

9. `P2-09` Artifact code format never contains empty type-name segments.

10. `P2-10` Artifact code generation is side-effect free and does not depend on
    mutable global state.

---

## 2. `publishing::validation`

### P0

11. `P0-11` Content references are never accepted with an empty
    `content_hash`.

12. `P0-12` Content references are never accepted with an empty
    `walrus_blob_id`.

13. `P0-13` Content references are never accepted with an empty
    `walrus_blob_object_id`.

14. `P0-14` Content references are never accepted with an empty `content_type`.

15. `P0-15` Title validation rejects empty titles and overlong titles.

16. `P0-16` Author-list validation rejects empty author vectors.

### P1

17. `P1-17` Author-list validation rejects vectors larger than `MAX_AUTHORS`.

18. `P1-18` Keyword validation rejects vectors larger than `MAX_KEYWORDS`.

19. `P1-19` Tag validation rejects vectors larger than `MAX_TAGS`.

20. `P1-20` Vector-item validation rejects empty items in authors, keywords,
    and tags.

21. `P1-21` Vector-item validation rejects oversize items in authors,
    keywords, and tags.

22. `P1-22` `long_text(...)` rejects empty strings and strings above the long
    text bound.

23. `P1-23` `medium_text(...)` rejects empty strings and strings above the
    medium text bound.

24. `P1-24` `short_text(...)` rejects empty strings and strings above the short
    text bound.

### P2

25. `P2-25` Content-field maximum lengths are enforced independently; an input
    that satisfies one bound cannot bypass another bound.

26. `P2-26` Validation helpers are pure guards:
    they never mutate protocol state and can be reasoned about as pure
    preconditions.

27. `P2-27` Any successful `content_fields(...)` call implies all four content
    reference strings are non-empty and length-bounded.

28. `P2-28` Any successful `authors(...)`, `keywords(...)`, or `tags(...)`
    call implies every accepted item is non-empty and length-bounded.

---

## 3. `governance::governance`

### P0

29. `P0-29` `new_vault(...)` never creates a vault with zero governance
    authority.

30. `P0-30` `new_vault(...)` never creates a vault with zero initial operator.

31. `P0-31` `new_vault_with_action_executor_cap(...)` creates an action
    executor cap whose `registry_id` matches the vault `registry_id`.

32. `P0-32` `assert_action_executor_cap(...)` rejects caps whose
    `governance_vault_id` does not match the target vault.

33. `P0-33` Governance config can be bound only once to a vault through
    `bind_governance_config(...)`.

34. `P0-34` Only the current upgrade authority can call
    `register_managed_upgrade_cap(...)`.

35. `P0-35` Only the current upgrade authority can call
    `authorize_managed_upgrade(...)`.

36. `P0-36` Only the current upgrade authority can call
    `commit_managed_upgrade(...)`.

37. `P0-37` Only the current upgrade authority can call `migrate_vault(...)`.

38. `P0-38` `set_fee_recipient(...)` is impossible unless direct authority mode
    allows that mutation and the caller is the governance authority.

39. `P0-39` `set_governance_authority(...)` is impossible unless direct
    authority mode allows that mutation and the caller is the governance
    authority.

40. `P0-40` `set_upgrade_authority(...)` is impossible unless direct authority
    mode allows that mutation and the caller is the governance authority.

### P1

41. `P1-41` `set_comments_fee_level(...)` cannot succeed unless the caller is
    governance authority and the fee manager belongs to the same registry.

42. `P1-42` `apply_fee_recipient(...)` never accepts the zero address.

43. `P1-43` `apply_governance_authority(...)` never accepts the zero address.

44. `P1-44` `apply_upgrade_authority(...)` never accepts the zero address.

45. `P1-45` `apply_direct_authority_mode_from_vote(...)` never accepts an
    invalid mode byte.

46. `P1-46` Once `direct_authority_permanently_disabled` becomes `true`, no
    later mode transition can restore direct authority.

47. `P1-47` `collect_artifact_fee(...)` rejects fee managers from a different
    registry.

48. `P1-48` `collect_comments_fee(...)` rejects fee managers from a different
    registry.

49. `P1-49` `apply_comments_fee_level_from_ticket(...)` only accepts governance
    tickets of action type `ACTION_SET_COMMENTS_FEE_LEVEL`.

50. `P1-50` `apply_artifact_fee_level_from_ticket(...)` only accepts governance
    tickets of action types `ACTION_SET_ARTIFACT_FEE_LEVEL` or
    `ACTION_ACTIVATE_ARTIFACT_TYPE`.

51. `P1-51` `unpack_artifact_type_enabled_ticket(...)` only accepts governance
    tickets of action type `ACTION_SET_ARTIFACT_TYPE_ENABLED`.

52. `P1-52` `assert_active_operator(...)` rejects stale permits whose epoch no
    longer matches the vault.

53. `P1-53` `nominate_operator(...)` cannot overwrite an existing pending
    operator transfer.

54. `P1-54` `nominate_operator_internal(...)` never records a zero pending
    operator.

55. `P1-55` `nominate_operator_internal(...)` always increments operator epoch
    for the pending transfer path.

56. `P1-56` Accepting an operator transfer moves the active operator to the
    nominated operator and clears pending-transfer state.

57. `P1-57` Cancelling an operator transfer clears pending-transfer state
    without changing the current active operator.

58. `P1-58` `fee_level(...)` defaults to `FREE` when no explicit fee level is
    stored for a fee key.

59. `P1-59` `artifact_fee_amount(...)` is always derived from the stored fee
    level and never from untrusted caller input.

60. `P1-60` `comments_fee_amount(...)` is always derived from the stored fee
    level and never from untrusted caller input.

### P2

61. `P2-61` All externally readable vault accessors are observational only and
    cannot mutate vault state.

62. `P2-62` Managed upgrade events always bind emitted package IDs to the same
    registry as the managed cap.

63. `P2-63` `new_action_ticket(...)` preserves payload values without
    reordering or truncation.

64. `P2-64` `assert_current_vault(...)` and version migration logic prevent old
    versions from being silently treated as current.

---

## 4. `governance::governance_voting`

### P0

65. `P0-65` At most one active proposal exists at a time:
    proposal creation is impossible while `active_proposal_id` is set.

66. `P0-66` Creating a proposal always sets `active_proposal_id` to the new
    proposal ID.

67. `P0-67` Creating a proposal always records the proposer stake as a first
    `YES` vote in both `votes` and `yes_locked_balance`.

68. `P0-68` Creating a proposal is impossible when proposal creation is paused.

69. `P0-69` Creating a proposal is impossible if proposer stake is below the
    current proposer threshold.

70. `P0-70` Creating a proposal is impossible for an invalid
    `(proposal_type, action_type)` pair.

71. `P0-71` Creating a proposal is impossible for a governance action that is
    currently disabled.

72. `P0-72` `vote_yes(...)` is impossible once the proposal is no longer
    `ACTIVE`.

73. `P0-73` `vote_no(...)` is impossible once the proposal is no longer
    `ACTIVE`.

74. `P0-74` One address can successfully vote at most once per proposal.

75. `P0-75` Successful votes always increase exactly one of
    `yes_locked_balance` or `no_locked_balance` by exactly the recorded voting
    power.

76. `P0-76` `claim_locked_tokens(...)` is impossible while the proposal status
    is `ACTIVE`.

77. `P0-77` `claim_locked_tokens(...)` is impossible for an address with no
    vote record in the proposal.

78. `P0-78` A successful claim removes the voter's record, so a second claim by
    the same address must fail.

79. `P0-79` A successful claim returns exactly the recorded vote power from the
    matching side's locked balance and cannot over-withdraw.

80. `P0-80` `finalize_proposal(...)` is impossible before `end_epoch`.

81. `P0-81` A successful `finalize_proposal(...)` always clears
    `active_proposal_id` when it points at that proposal.

82. `P0-82` A successful `resolve_proposal_early(...)` always clears
    `active_proposal_id` when it points at that proposal.

83. `P0-83` `resolve_proposal_early(...)` is impossible unless the proposal
    outcome is mathematically determinable under current total supply and votes.

84. `P0-84` Executable proposals cannot be executed unless they are in status
    `PASSED` and `executed == false`.

85. `P0-85` No executable proposal can be executed twice.

86. `P0-86` A passed executable proposal that is executed after the execution
    validity window becomes `EXPIRED` instead of mutating protocol state.

### P1

87. `P1-87` `expire_passed_proposal(...)` is impossible before the execution
    validity window has expired.

88. `P1-88` `expire_passed_proposal(...)` is impossible for non-executable
    proposals.

89. `P1-89` `consume_executable_proposal_action(...)` only consumes proposals
    whose `action_type` matches the expected action.

90. `P1-90` `consume_executable_proposal_action(...)` only accepts action
    executor caps tied to the correct registry and governance vault.

91. `P1-91` `execute_cancel_operator_transfer_proposal(...)` only applies to
    proposals of action type `ACTION_CANCEL_OPERATOR_TRANSFER`.

92. `P1-92` `assert_proposal_belongs_to_config(...)` prevents mismatched
    proposal/config pairs and prevents proposal-object substitution attacks.

93. `P1-93` `remaining_voting_supply(...)` equals
    `total_supply - yes_votes - no_votes` and never goes negative under valid
    protocol states.

94. `P1-94` `outcome_determinable(...)` is equivalent to
    `deterministic_pass || deterministic_fail`.

95. `P1-95` `passage_rule_satisfied(...)` only depends on explicit vote totals
    and configured total supply, not on hidden mutable state.

96. `P1-96` Proposal payload validation rejects zero addresses for governance
    actions that require a real address.

97. `P1-97` Proposal payload validation rejects invalid boolean payloads for
    enable/pause actions.

98. `P1-98` Proposal payload validation rejects invalid proposer-threshold and
    proposal-duration values.

99. `P1-99` Action enablement cannot target
    `ACTION_SET_GOVERNANCE_ACTION_ENABLED` itself.

100. `P1-100` The sum of all unclaimed vote records' voting power equals the
     sum of `yes_locked_balance` and `no_locked_balance`.

### P2

101. `P2-101` Proposal ID allocation is monotonic: each successful creation
     consumes exactly one `next_proposal_id`.

102. `P2-102` Proposal version migration preserves proposal identity,
     registry binding, and vote balances.

103. `P2-103` Config version migration preserves active-proposal and
     proposal-object binding state.

104. `P2-104` Event emission order for creation is stable:
     `ProposalCreatedEvent` and proposer `VoteCastEvent` describe the same
     proposal ID and voting power.

---

## 5. `comments::comments`

### P0

105. `P0-105` `new_tree_factory_cap(...)` can only be created by governance
     authority or upgrade authority.

106. `P0-106` `new_tree_factory_cap(...)` binds exactly one registry, vault,
     and fee manager triple.

107. `P0-107` `new_tree(...)` is impossible with an empty `target_key`.

108. `P0-108` `new_tree(...)` creates a root comment at
     `ROOT_COMMENT_ID == 0` and makes it active.

109. `P0-109` `new_tree(...)` binds the resulting `CommentsTree` and
     `LikesBook` to the same registry, target series, and artifact type.

110. `P0-110` `add_onchain_comment(...)` is impossible unless the tree is
     `OPEN`.

111. `P0-111` `add_onchain_comment(...)` is impossible for a missing parent
     comment.

112. `P0-112` `add_onchain_comment(...)` is impossible if the parent comment is
     not `ACTIVE`.

113. `P0-113` `add_onchain_comment(...)` is impossible when content is empty.

114. `P0-114` `add_onchain_comment(...)` is impossible when content exceeds the
     tree's on-chain size limit.

115. `P0-115` `add_onchain_comment(...)` is impossible if governance vault or
     fee manager bindings do not match the tree.

116. `P0-116` `add_onchain_comment(...)` is impossible if the computed child
     depth would exceed `max_comment_depth`.

117. `P0-117` A successful `add_onchain_comment(...)` increments exactly:
     `next_comment_id`, `total_comments`, and the parent's `children_count`.

118. `P0-118` `add_blob_comment(...)` is impossible unless the tree is `OPEN`.

119. `P0-119` `add_blob_comment(...)` is impossible for a missing parent
     comment.

120. `P0-120` `add_blob_comment(...)` is impossible if blob ID or blob digest
     is empty.

121. `P0-121` `add_blob_comment(...)` is impossible if blob ID, blob digest, or
     preview exceed the configured byte limits.

122. `P0-122` `add_blob_comment(...)` is impossible if governance vault or fee
     manager bindings do not match the tree.

123. `P0-123` `add_blob_comment(...)` is impossible if the computed child depth
     would exceed `max_comment_depth`.

124. `P0-124` `like_paper(...)` is impossible unless the provided PPRF proof
     coin has at least `MIN_PPRF_FOR_LIKE`.

125. `P0-125` One address can successfully like a given `LikesBook` at most
     once until it unlikes.

126. `P0-126` A successful unlike is impossible unless the address had liked
     before.

127. `P0-127` `like_count` equals the number of addresses currently stored in
     the likes table.

128. `P0-128` `set_comment_status(...)` can never change the root comment.

129. `P0-129` Once a comment is marked `DELETED`, it can never transition to
     another status.

130. `P0-130` A non-owner, non-tree-owner cannot change another user's comment
     status.

### P1

131. `P1-131` A normal comment author can only set their own comment to
     `DELETED`, not to arbitrary statuses.

132. `P1-132` Tree owner can set any non-root, non-final comment to any valid
     comment status.

133. `P1-133` `set_tree_status(...)` can only be called by the current tree
     owner.

134. `P1-134` `transfer_tree_owner(...)` can only be called by the current tree
     owner.

135. `P1-135` `transfer_tree_owner(...)` never accepts the zero address.

136. `P1-136` `assert_tree_factory_cap(...)` rejects factory caps whose
     registry, vault, or fee manager binding differs from the requested
     creation context.

137. `P1-137` Tree and likes-book version checks prevent outdated versions from
     being silently used as current.

138. `P1-138` `migrate_tree(...)` can only be performed by the governance
     upgrade authority for the same registry.

139. `P1-139` Every successful comment addition emits `CommentAddedEvent` with
     the same `comment_id`, `parent_comment_id`, `author`, and `depth` as the
     stored node.

140. `P1-140` Every successful like/unlike emits an event whose `like_count`
     matches the post-state count.

### P2

141. `P2-141` `created_at_ms` on the root comment equals the tree creation
     timestamp.

142. `P2-142` Newly created comment nodes always start with `children_count == 0`.

143. `P2-143` Newly created comment nodes always start with
     `edited_at_ms == none`.

144. `P2-144` Successful status changes clear `edited_at_ms` rather than
     leaving stale edit timestamps behind.

---

## 6. `publishing::publishing`

### P0

145. `P0-145` `init(...)` always creates exactly one root, one type registry,
     and one type index for each built-in artifact type.

146. `P0-146` `init(...)` binds root, governance vault, fee manager, type
     registry, comments tree factory cap, and governance action executor cap to
     the same registry.

147. `P0-147` Direct preprint publish is impossible:
     `publish_preprint(...)` always aborts.

148. `P0-148` `reserve_preprint_code(...)` is impossible unless publishing
     context is valid for the preprint type.

149. `P0-149` Each successful preprint reservation emits an artifact code that
     is derived from the reserved series address and current epoch.

150. `P0-150` `finalize_reserved_preprint(...)` is impossible unless title,
     abstract, authors, keywords, field, and license validations all pass.

151. `P0-151` Finalizing a reserved preprint always uses the reservation-derived
     series identity, not an arbitrary caller-supplied series ID.

152. `P0-152` Finalizing a reserved preprint always produces a
     `PreprintVersionRecord` whose series code matches the reservation's
     `artifact_code`.

153. `P0-153` `publish_blog_post(...)` is impossible unless title, summary,
     tags, and language validations all pass.

154. `P0-154` `publish_technical_report(...)` is impossible unless title,
     abstract, authors, organization, report number, keywords, and license
     validations all pass.

155. `P0-155` `publish_dataset(...)` is impossible unless title, description,
     format, keywords, and license validations all pass.

156. `P0-156` `publish_software_release(...)` is impossible unless project
     name, version name, source hash, package hash, changelog, license, and
     repository URL validations all pass.

157. `P0-157` `publish_generic_file(...)` is impossible unless title,
     description, filename, and license validations all pass.

158. `P0-158` Every successful publish path creates and binds a new official
     `CommentsTree` and `LikesBook` to the same series.

159. `P0-159` Every successful publish path records the correct artifact type in
     both `ArtifactSeries` and the typed version record header.

160. `P0-160` Every successful publish path starts the series at version `1`.

161. `P0-161` Every successful publish path records the first version ID as
     `current_version_id` and as the sole element of `version_ids`.

162. `P0-162` Every successful publish path enforces content-field validation
     before storing `content_hash`, `walrus_blob_id`,
     `walrus_blob_object_id`, and `content_type`.

163. `P0-163` Every successful publish path is impossible when the protocol is
     paused.

164. `P0-164` Every successful publish path is impossible when the target
     artifact type is disabled.

### P1

165. `P1-165` Add-version entrypoints never change `artifact_type` of the
     target series.

166. `P1-166` Add-version entrypoints never change the target series ID.

167. `P1-167` Add-version entrypoints always append a new version ID to
     `version_ids` and advance `current_version`.

168. `P1-168` Add-version entrypoints always set `previous_version_id` in the
     new header to the prior `current_version_id`.

169. `P1-169` Add-version entrypoints never replace or rebind the series'
     official `comments_tree_id`.

170. `P1-170` Add-version entrypoints never replace or rebind the series'
     official `likes_book_id`.

171. `P1-171` `MAX_VERSIONS_PER_SERIES` is enforced and cannot be bypassed by
     any typed add-version path.

172. `P1-172` `metadata_extensions` on both series and versions never exceed
     `MAX_METADATA_ATTRIBUTES`.

173. `P1-173` Metadata keys are never empty.

174. `P1-174` Metadata keys are unique within a metadata vector.

175. `P1-175` Metadata key and value byte-length bounds are always enforced.

176. `P1-176` `set_series_status(...)` or equivalent status transitions accept
     only valid series-status values.

177. `P1-177` Only the current series owner can change owner-controlled series
     state such as status, metadata, or ownership.

178. `P1-178` Ownership transfer on a series updates the corresponding
     comments-tree owner binding consistently.

179. `P1-179` Type activation and type enablement governance actions can only
     mutate the `TypeRegistry` associated with the current root registry.

180. `P1-180` Artifact fee changes through governance tickets can only mutate
     fee levels for the intended artifact type.

181. `P1-181` A series' `artifact_code` remains stable across all future
     versions and owner changes.

182. `P1-182` `ui_status` changes never alter protocol identity fields such as
     `artifact_type`, `artifact_code`, `comments_tree_id`, or `likes_book_id`.

### P2

183. `P2-183` `init(...)` emits creation events whose IDs match the created
     root, registry, and type-index objects.

184. `P2-184` `reserve_preprint_code(...)` can be called multiple times by the
     same address without causing reservation cross-talk or shared-series
     aliasing.

185. `P2-185` Distinct reservations produce distinct reservation IDs and
     distinct reserved series addresses.

186. `P2-186` Typed version records preserve their type-specific user fields
     without field order ambiguity.

187. `P2-187` Root, registry, series, and typed version version-migration
     helpers preserve registry binding and identity.

188. `P2-188` Type registry timestamps are monotonic for any successful type
     enable/disable or activation mutation.

---

## 7. Cross-Module Properties

### P0

189. `P0-189` Every published `ArtifactSeries.comments_tree_id` points to a
     `CommentsTree` whose `target_series_id` equals the series ID.

190. `P0-190` Every published `ArtifactSeries.likes_book_id` points to a
     `LikesBook` whose `target_series_id` equals the series ID.

191. `P0-191` Every published `CommentsTree.likes_book_id` points back to the
     official `LikesBook` for that same series.

192. `P0-192` Governance-registry IDs across publishing, comments, and
     governance objects always match for the same official deployment.

193. `P0-193` A comment addition can never successfully pay fees into a fee
     manager from the wrong registry.

194. `P0-194` A publishing flow can never successfully create a series whose
     official comments tree was created under a different governance vault.

### P1

195. `P1-195` Artifact-type governance changes only affect future publishing
     eligibility and do not retroactively alter historical series types.

196. `P1-196` Governance fee-level changes only affect fee collection logic and
     do not mutate historical published version records.

197. `P1-197` Preprint reservation/finalize flow and comments-tree creation
     together preserve the same series identity from reservation event to
     durable published artifact.

198. `P1-198` If a series owner changes, the associated comments-tree owner is
     eventually brought into the same owner boundary through official paths.

### P2

199. `P2-199` Canonical emitted events across publishing, comments, and
     governance are consistent with the post-state object bindings they claim to
     describe.

200. `P2-200` No successful protocol path can create an official artifact whose
     governance, fee, comments, likes, and series bindings disagree about the
     underlying registry.

---

## Notes for Prover Rollout

Recommended proof order:

1. `governance_voting.move`:
   `P0-65` through `P0-86`, then `P1-87` through `P1-100`
2. `publishing.move`:
   `P0-147` through `P0-164`, then `P1-165` through `P1-182`
3. `comments.move`:
   `P0-105` through `P0-130`, then `P1-131` through `P1-140`
4. `governance.move`:
   `P0-29` through `P0-40`, then `P1-41` through `P1-60`
5. cross-module binding properties:
   `P0-189` through `P2-200`

Good first formalization targets:

- single active proposal
- locked-vote balance conservation
- claim cannot over-withdraw
- direct preprint publish disabled
- reserved preprint code equals finalized series code
- add-version preserves series identity
- comments tree and likes book remain correctly bound to series
- registry equality across publishing, comments, and governance objects
