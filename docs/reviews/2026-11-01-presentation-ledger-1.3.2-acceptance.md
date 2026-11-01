# Ledger presentation acceptance - 1.3.2

## Current Scoped Verdict

**PASS: P1.1-P1.10 and G8 only.** Independently scored on 2026-11-01 (Asia/Shanghai) against final runtime `df072ba0e6f603e66ba87e0b29c75fcc334a8e43`. Tester: Independent Ledger QA. Branch: `qa/presentation-ledger-1.3.2`. ReportPortal UI 5.15.6, project `superadmin_personal`.

This is the owner's simplified 1.x scope, not a whole-release certification. No G11, V criteria, 2.x runtime, corpus reconstruction, CI or matrix verification is claimed here. Master approved this QA evidence commit only; no push, release, protected-branch change, PR merge or tag is authorized. All historical observations below remain historical, including prior failures and Decision 15's now-withdrawn 1.x exception.

Current machine-readable evidence: [scoped-acceptance.json](assets/1x-p1-20261101/scoped-acceptance.json), with **715 checks, zero failures**, exact inputs/expected/actual values, Launch/item/log IDs, and capture/source SHA-256 bindings. The older `assets/presentation-ledger-1.3.2-acceptance.json` is preserved unchanged as historical evidence, not used as a current verdict.

## Current Runs

| Runtime / Presentation | Master Native F01 / F04 / F14 / F14-negative | Frozen 62-Frame F04 | Independent Original-3778 Replay |
| --- | --- | --- | --- |
| Cucumber 9.2.1 / plain | 3807 / 3808 / 3809 / 3810 | 3811 | 3827 |
| Cucumber 9.2.1 / rich | 3812 / 3813 / 3814 / 3815 | 3816 | 3828 |
| Cucumber 10.2.0 / plain | 3817 / 3818 / 3819 / 3820 | 3821 | 3829 |
| Cucumber 10.2.0 / rich | 3822 / 3823 / 3824 / 3825 | 3826 | 3830 |

The 24 Launches above have fresh independent GET captures in `fresh-master-get-01` and `fresh-replay-get-01`. All item/log sets are complete and match their source captures. Loaded SDK bytes are independently checked against the final SHA. Master executed the four unchanged QA replay commands with private credential injection only; QA supplied the original inputs, runner and assertions. The 20 native/frozen executions were Master-run; independent GETs, scoring and CUA observations, not Master verdicts, are the QA evidence.

The six remaining fixtures were freshly executed using unchanged existing QA runners on Cucumber 10.2.0/plain: F16a 3831, F16d 3832, F16e 3833, F16f 3834, non-Exception event adapter 3835, and explicit framework-only input replay 3836. Each has authenticated live readback, source binding, one intentional native failure and one ERROR log. Adapter inputs are explicitly distinguished from natural Ruby exceptions. No extra matrix was run.

Baseline Launch **3778** is the reused committed historical GET at `assets/ledger-qa-live/wp5-ci-final-20261101-c10.2.0-baseline/F14-negative/snapshot.json`, not a newly fetched baseline. All 33 loaded SDK file hashes bind it to actual v1.3.1 `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`. The 14 original message/frame splits are in [launch-3778-inputs.json](assets/1x-p1-20261101/launch-3778-inputs.json), SHA-256 `e13f5e4c02cfab1679628abafc7b9dda1682f5bd8480c793c6597a266609cdf7`. Every replay contains all 58 original frames per case; **56/56 messages, full tails and combined raw failures are byte-identical**, including `back\slash`. Presentation escaping alone is decoded; no path or frame normalization is used. Native C9/C10 backtraces are separately compared to their own native JSON, never declared equal to each other or to 3778.

## Current Results

| Criterion | Verdict | Independent Evidence |
| --- | --- | --- |
| P1.1 | PASS | Plain 3811/3821 equal the complete proposal golden. All four frozen tails retain all 62 original lines, SHA-256 `3fd9692c6e95a2e7e1868111ad41fd5f2584f95098c67d18ccc9756d66eca75d`. |
| P1.2 | PASS | Exact escaped titles; non-Exception 3835; empty message 3832; 200-character ellipsis title 3833. Its full original 500-character message is retained in the optional Full message block. No Decision 15 exception. |
| P1.3 | PASS | Counts independently recomputed for all 125 nonempty tails, including 62 total / 56 framework / 2 runner in frozen F04 and framework-only 3836. |
| P1.4 | PASS | Original frame order, at most eight project frames, feature last, 40-character display cap; 3836 shows precisely the first three framework frames. |
| P1.5 | PASS | 3831 preserves both continuation lines in a text fence immediately after meta and before Project frames. Caption is absent without continuation. |
| P1.6 | PASS | Eight independent DOM checks across 3827-3830: both markup inputs appear literally; title/card DOM contains zero injected script or b elements. |
| P1.7 | PASS | Revised by D19: 3834 preserves the exact original synthetic message and complete native tail, rather than adding failure-path redaction. |
| P1.8 | PASS | S01 for 3811/3821 at 1100 x 780: title y=527 and meta y=589, both above the untouched fold, without scrolling or expansion. |
| P1.9 | PASS | S02 for 3811/3821: Stack trace begins with the card title. RP displays raw Markdown in this tab, not an h2 DOM element. |
| P1.10 | PASS | Separate C9/C10 frozen-input runs have identical pre-tail text within each presentation mode; native stacks are not normalized. |
| G8 | PASS | D19 contract: all 126 failure payloads retain original message/frame content. The only synthetic SECRET123 hit is the unchanged F16f message, log 20013; no item/Launch field hit. All 30 candidate Launches are final-source bound. |

The four QA content-comparison tests passed: 4 runs, 6 assertions, zero failures/errors/skips (`legacy_3778_test.rb`, seed 47972). Offline scoring is reproducible without credentials using `ruby spec/acceptance/ledger_qa/p1_1x/score_captures.rb`; it does not execute the SDK, contact RP or create Launches.

## Current Defects

None found in the scoped checks. No scoped checks remain blocked. The initial Stack trace heading-locator miss and the earlier pre-Cucumber F04 trace mismatch are retained as diagnostics in the JSON; neither was converted into a product defect or a waiver. Final native JSON is the correct final-event frame input and matches the ERROR tail exactly.

## Current Screenshots

All screenshots are unmodified native CUA JPEG captures. [UI observations](assets/1x-p1-20261101/screenshots/ui-observations.json) bind every screenshot to its actual page URL, 1100 x 780 viewport, Launch/item/log IDs and DOM results.

- [S01 C9 plain](assets/1x-p1-20261101/screenshots/S01-c9-plain-frozen-3811.jpg), [S02 C9 plain](assets/1x-p1-20261101/screenshots/S02-c9-plain-frozen-3811.jpg): Launch 3811, item 30497, log 19799.
- [S01 C10 plain](assets/1x-p1-20261101/screenshots/S01-c10-plain-frozen-3821.jpg), [S02 C10 plain](assets/1x-p1-20261101/screenshots/S02-c10-plain-frozen-3821.jpg): Launch 3821, item 30675, log 19901.
- Eight `P1.6-*.jpg` screenshots and corresponding DOM snapshots cover cases 1 and 10 in Launches 3827-3830; exact filenames and IDs are in the UI observations JSON.

## Current Decisions And Exit

Decision 19 at final runtime HEAD is authoritative: on 1.x the failure log carries the same text v1.3.1 sent, in the Ledger card. Failure-log redaction is not added; Decision 15's P1.2 exception is withdrawn; G8 means nothing is sent that v1.3.1 would not have sent. Historical Decisions 20-26 and old WP0-WP5 followups are not new gates. No new waiver was inferred.

Master-supplied four-cell matrix records and the retained first missing-jq attempt are archived separately under this dated asset directory as context, not independently executed or certified by this scoped QA review. Current P1/G8 exit is PASS. Master approved only the QA evidence commit covering [the exact path list](assets/1x-p1-20261101/review-paths.txt), with `Assisted-by: OpenAI Codex`. No push, release, protected-branch change, PR merge or tag is authorized.

<details>
<summary>Historical WP5 Report: Preserved Old Scope, Not Current Certification</summary>

Verdict: ACCEPT. Date: 2026-11-01 (Asia/Shanghai). Tester: Independent Ledger QA. Branch: `qa/presentation-ledger-1.3.2`. Candidate feature head: `01db2e42d70fc7ec2179198992fc00c1c55825bc`. Actually tested runtime head: `f41888a9fdd6896630765cbbf350353a7f803e59`. Baseline: `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`. RP UI 5.15.6 / server 26.0.7.

Documentation-only binding: [exact path/mode/blob fingerprints and fresh package member proof](assets/wp5-ci-final-20261101/docs-only-final-binding-r2.json) pass. Only the approved documentation delta is newly verified; matrix/live/fault/performance runs retain their original tested SHAs. No release authorization.

WP5 re-scores only G1-G12, P1.1-P1.10, P5.1-P5.8, P8.1-P8.9, P10.1-P10.11 and V1-V8 at the final runtime head. Other criterion states are explicitly historical, not new final-head executions. Every original Q check is preserved in the evidence JSON and prior report commits. Developer Launches are not acceptance evidence. No new waiver is inferred.

## Runs
| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |
| --- | --- | --- | --- | --- | --- | --- |
| M1 | ruby 3.1.7p261 (2025-03-26 revision 0a3704f218) [aarch64-linux] | 9.2.1 | offline plain | 1419/0/0 | 1/3 | Offline; PASS |
| M2 | ruby 3.1.7p261 (2025-03-26 revision 0a3704f218) [aarch64-linux] | 10.2.0 | offline plain | 1419/0/0 | 1/3 | Offline; PASS |
| M3 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | offline plain | 1419/0/0 | 1/3 | Offline; PASS |
| M4 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | offline plain | 1419/0/0 | 1/3 | Offline; PASS |
| wp5-ci-final-20261101-c10.2.0-authored-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3800 |
| wp5-ci-final-20261101-c10.2.0-authored-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3612, 3613 |
| wp5-ci-final-20261101-c10.2.0-authored-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3659, 3660 |
| wp5-ci-final-20261101-c10.2.0-authored-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3706, 3707 |
| wp5-ci-final-20261101-c10.2.0-authored-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3753, 3754 |
| wp5-ci-final-20261101-c10.2.0-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3755, 3756, 3757, 3758, 3759, 3760, 3761, 3762, 3763, 3764, 3765, 3766, 3767, 3768, 3769, 3770, 3771, 3772, 3773, 3774, 3775, 3776, 3777, 3778, 3779, 3780, 3781, 3782, 3783, 3784, 3785, 3786, 3787, 3788, 3789, 3790, 3791, 3792, 3793 |
| wp5-ci-final-20261101-c10.2.0-default-batch1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3801, 3802, 3803 |
| wp5-ci-final-20261101-c10.2.0-framework-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3799 |
| wp5-ci-final-20261101-c10.2.0-framework-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3611 |
| wp5-ci-final-20261101-c10.2.0-framework-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3658 |
| wp5-ci-final-20261101-c10.2.0-framework-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3705 |
| wp5-ci-final-20261101-c10.2.0-framework-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3752 |
| wp5-ci-final-20261101-c10.2.0-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3567, 3568, 3569, 3570, 3571, 3572, 3573, 3574, 3575, 3576, 3577, 3578, 3579, 3580, 3581, 3582, 3583, 3584, 3585, 3586, 3587, 3588, 3589, 3590, 3591, 3592, 3593, 3594, 3595, 3596, 3597, 3598, 3599, 3600, 3601, 3602, 3603, 3604, 3605 |
| wp5-ci-final-20261101-c10.2.0-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3614, 3615, 3616, 3617, 3618, 3619, 3620, 3621, 3622, 3623, 3624, 3625, 3626, 3627, 3628, 3629, 3630, 3631, 3632, 3633, 3634, 3635, 3636, 3637, 3638, 3639, 3640, 3641, 3642, 3643, 3644, 3645, 3646, 3647, 3648, 3649, 3650, 3651, 3652 |
| wp5-ci-final-20261101-c10.2.0-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3661, 3662, 3663, 3664, 3665, 3666, 3667, 3668, 3669, 3670, 3671, 3672, 3673, 3674, 3675, 3676, 3677, 3678, 3679, 3680, 3681, 3682, 3683, 3684, 3685, 3686, 3687, 3688, 3689, 3690, 3691, 3692, 3693, 3694, 3695, 3696, 3697, 3698, 3699 |
| wp5-ci-final-20261101-c10.2.0-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3708, 3709, 3710, 3711, 3712, 3713, 3714, 3715, 3716, 3717, 3718, 3719, 3720, 3721, 3722, 3723, 3724, 3725, 3726, 3727, 3728, 3729, 3730, 3731, 3732, 3733, 3734, 3735, 3736, 3737, 3738, 3739, 3740, 3741, 3742, 3743, 3744, 3745, 3746 |
| wp5-ci-final-20261101-c10.2.0-supplement-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3794, 3795, 3796, 3797, 3798 |
| wp5-ci-final-20261101-c10.2.0-supplement-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3606, 3607, 3608, 3609, 3610 |
| wp5-ci-final-20261101-c10.2.0-supplement-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3653, 3654, 3655, 3656, 3657 |
| wp5-ci-final-20261101-c10.2.0-supplement-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3700, 3701, 3702, 3703, 3704 |
| wp5-ci-final-20261101-c10.2.0-supplement-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | rich | Not a suite replacement | Fresh fixture outputs retained | 3747, 3748, 3749, 3750, 3751 |
| wp5-ci-final-20261101-c9.2.1-authored-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3563 |
| wp5-ci-final-20261101-c9.2.1-authored-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3309, 3311 |
| wp5-ci-final-20261101-c9.2.1-authored-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3381, 3382 |
| wp5-ci-final-20261101-c9.2.1-authored-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3461, 3462 |
| wp5-ci-final-20261101-c9.2.1-authored-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3516, 3517 |
| wp5-ci-final-20261101-c9.2.1-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3518, 3519, 3520, 3521, 3522, 3523, 3524, 3525, 3526, 3527, 3528, 3529, 3530, 3531, 3532, 3533, 3534, 3535, 3536, 3537, 3538, 3539, 3540, 3541, 3542, 3543, 3544, 3545, 3546, 3547, 3548, 3549, 3550, 3551, 3552, 3553, 3554, 3555, 3556 |
| wp5-ci-final-20261101-c9.2.1-default-batch1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3564, 3565, 3566 |
| wp5-ci-final-20261101-c9.2.1-framework-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3562 |
| wp5-ci-final-20261101-c9.2.1-framework-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3307 |
| wp5-ci-final-20261101-c9.2.1-framework-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3379 |
| wp5-ci-final-20261101-c9.2.1-framework-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3459 |
| wp5-ci-final-20261101-c9.2.1-framework-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3515 |
| wp5-ci-final-20261101-c9.2.1-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3237, 3239, 3240, 3242, 3243, 3246, 3248, 3249, 3250, 3252, 3253, 3254, 3255, 3257, 3258, 3260, 3261, 3263, 3264, 3265, 3267, 3268, 3270, 3273, 3275, 3277, 3278, 3280, 3281, 3283, 3284, 3286, 3287, 3289, 3290, 3292, 3293, 3295, 3296 |
| wp5-ci-final-20261101-c9.2.1-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3314, 3316, 3319, 3320, 3322, 3324, 3327, 3329, 3330, 3331, 3332, 3334, 3335, 3336, 3337, 3338, 3340, 3341, 3342, 3344, 3345, 3347, 3348, 3350, 3351, 3353, 3354, 3356, 3357, 3358, 3360, 3361, 3362, 3363, 3364, 3365, 3367, 3368, 3369 |
| wp5-ci-final-20261101-c9.2.1-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3384, 3385, 3388, 3390, 3391, 3393, 3397, 3399, 3401, 3402, 3404, 3405, 3407, 3408, 3410, 3412, 3413, 3415, 3416, 3418, 3419, 3421, 3422, 3424, 3425, 3427, 3428, 3430, 3431, 3433, 3434, 3436, 3437, 3439, 3440, 3442, 3443, 3445, 3446 |
| wp5-ci-final-20261101-c9.2.1-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3464, 3465, 3467, 3469, 3471, 3473, 3474, 3476, 3477, 3479, 3480, 3481, 3483, 3484, 3485, 3486, 3487, 3488, 3489, 3490, 3491, 3492, 3493, 3494, 3495, 3496, 3497, 3498, 3499, 3500, 3501, 3502, 3503, 3504, 3505, 3506, 3507, 3508, 3509 |
| wp5-ci-final-20261101-c9.2.1-supplement-baseline | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3557, 3558, 3559, 3560, 3561 |
| wp5-ci-final-20261101-c9.2.1-supplement-plain-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3298, 3300, 3301, 3303, 3304 |
| wp5-ci-final-20261101-c9.2.1-supplement-plain-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3371, 3372, 3373, 3375, 3376 |
| wp5-ci-final-20261101-c9.2.1-supplement-rich-1 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3449, 3451, 3453, 3455, 3456 |
| wp5-ci-final-20261101-c9.2.1-supplement-rich-2 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3510, 3511, 3512, 3513, 3514 |

The early contended timing attempt is retained but is not G11 acceptance proof. Native compound syntax is N/A on legacy only under Decision 4; explicit separate companions remain required. F06 is N/A on 1.x. Decision 8 applies only to the six named legacy NUL-preview files, not to other log/attachment losses.

## Results by criterion
| ID | Level | Verdict (PASS/FAIL/N/A/BLOCKED) | Evidence (log/item IDs, file, screenshot) | Note |
| --- | --- | --- | --- | --- |
| G1 | MUST | PASS | [1272 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 3696 item IDs](#g1-id-ranges) | Compared C10/F14 GET parameters as full multisets only under Decision18, all original ordered POST arrays byte-for-byte and every other item field strictly, retaining raw API-order FAILs; Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3551, 3555-3788, 3792-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G2 | MUST | PASS | [176 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1356 log / 1160 item IDs](#g2-id-ranges) | Compared F01 plain per-item levels/counts: expected Hash with 3 entries; SHA256 df97528031a28ffa (full value in JSON), actual Hash with 3 entries; SHA256 df97528031a28ffa (full value in JSON); 176 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3518-3551, 3555-3563, 3567-3600, 3604-3612, 3661-3694, 3698-3706, 3755-3788, 3792-3800; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G3 | MUST | PASS | [500 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 348 log / 1128 item IDs](#g3-id-ranges) | Compared F01 plain downloaded attachment bytes/MIME/count: expected Array with 3 entries; SHA256 12d08726472edd3c (full value in JSON), actual Array with 3 entries; SHA256 12d08726472edd3c (full value in JSON); 500 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3518-3551, 3555-3563, 3567-3600, 3604-3612, 3661-3694, 3698-3706, 3755-3788, 3792-3800; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G4 | MUST | PASS | [164 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1808 log / 1544 item IDs](#g4-id-ranges) | Compared F01 plain messages and metadata repeat: expected Array with 2 entries; SHA256 3aad1a4c0343ec47 (full value in JSON), actual Array with 2 entries; SHA256 3aad1a4c0343ec47 (full value in JSON); 164 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3298, 3300-3301, 3303-3304, 3307, 3309, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3363, 3371-3373, 3375-3376, 3379, 3381, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3504, 3510-3516, 3567-3600, 3606-3612, 3614-3647, 3653-3659, 3661-3694, 3700-3706, 3708-3741, 3747-3753; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G5 | MUST | PASS | [1534 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1876 log / 1600 item IDs](#g5-id-ranges) | Compared F01 API forbidden-prefix filter: expected 0, actual 0; 1534 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G6 | MUST | PASS | [92 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 462 log / 396 item IDs](#g6-id-ranges) | Compared F01 every plain HTML hit classified: expected [], actual []; 92 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3567-3612; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G7 | MUST | PASS | [576 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1876 log / 1600 item IDs](#g7-id-ranges) | Compared F01 forbidden-token scan: expected [], actual []; 576 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G8 | MUST | PASS | [1728 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1876 log / 1600 item IDs](#g8-id-ranges) | Compared F01 API secret-marker filter: expected 0, actual 0; 1728 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G9 | MUST | PASS | [48 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#g9-id-ranges) | Compared Cucumber 9.2.1 fault-Accent-details: baseline fallback bytes, one warning, unchanged native result: expected [1,1,1,true,true,"/Users/nick/Documents/crr-1.3.2"], actual [1,1,1,true,true,"/Users/nick/Documents/crr-1.3.2"]; 48 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G10 | MUST | PASS | [12 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#g10-id-ranges) | Compared M1: exact final runtime full suite plus offline Cucumber, no failures/pending: expected ["f41888a9fdd6896630765cbbf350353a7f803e59","PASS",0,0], actual ["f41888a9fdd6896630765cbbf350353a7f803e59","PASS",0,0]; 12 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G11 | SHOULD | FAIL | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#g11-id-ranges) | Compared F07 median-of-three wall time against baseline +10% and every F01-F18 Presentation p95 against <2 ms; Cucumber 9.2.1 baseline 1.301801 s, plain median 1.479991 s, +13.6880%, rich median 1.517827 s, +16.5944%, FailureCard p95 0.996624993 ms (2100 samples); Cucumber 10.2.0 baseline 1.513667 s, plain median 1.357370 s, -10.3258%, rich median 1.406820 s, -7.0588%, FailureCard p95 1.259124998 ms (2100 samples); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| G12 | MUST | PASS | [752 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 1480 item IDs](#g12-id-ranges) | Compared F01 native NDJSON diff (generated IDs and clocks normalized): expected Array with 35 entries; SHA256 cf2428570e46831f (full value in JSON), actual Array with 35 entries; SHA256 cf2428570e46831f (full value in JSON); 752 criterion-specific checks (PASS); Launches 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3661-3754; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.1 | MUST | PASS | [16 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 14 log / 14 item IDs](#p1-1-id-ranges) | Compared F04 raw baseline tail preserved: expected String with 5573 entries; SHA256 adb58ebd957ae316 (full value in JSON), actual String with 5573 entries; SHA256 adb58ebd957ae316 (full value in JSON); 16 criterion-specific checks (PASS); Launches 3242, 3301, 3373, 3453, 3512, 3521, 3559, 3570, 3608, 3655, 3702, 3749, 3758, 3796; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.2 | MUST | PASS | [72 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 68 log / 68 item IDs](#p1-2-id-ranges) | Compared all escaped exception titles, with only F14 back\slash full omission excepted by Decision15; Launches 3273, 3283-3284, 3303, 3350, 3375, 3455, 3513, 3590, 3596-3597, 3609, 3637, 3656, 3703, 3750; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.3 | MUST | PASS | [46 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 44 log / 44 item IDs](#p1-3-id-ranges) | Compared F04 tail frame total: expected 59, actual 59; 46 criterion-specific checks (PASS); Launches 3242, 3273, 3278, 3280-3281, 3283-3284, 3286, 3301, 3307, 3570, 3590, 3593-3598, 3608, 3611; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.4 | MUST | PASS | [96 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 50 log / 50 item IDs](#p1-4-id-ranges) | Compared Explicit framework-only input: first three framework frames, in input order: expected "first.rb:11   Framework.one\nsecond.rb:22  Framework.two\nthird.rb:33   Framework.three", actual "first.rb:11   Framework.one\nsecond.rb:22  Framework.two\nthird.rb:33   Framework.three"; 96 criterion-specific checks (PASS); Launches 3242, 3273, 3278, 3280-3281, 3283-3284, 3286, 3301, 3307, 3379, 3459, 3515, 3570, 3590, 3593-3598, 3608, 3611, 3658, 3705, 3752; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.5 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p1-5-id-ranges) | Compared F16a continuation fenced before labelled project frames: expected true, actual true; 2 criterion-specific checks (PASS); Launches 3280, 3594; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.6 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 4 log / 4 item IDs](#p1-6-id-ranges) | Compared 9.2.1: literal title text and no data-created script/b elements: expected {"title":"✗ RuntimeError: <b>x</b>","script":0,"bold":0}, actual {"bold":0,"script":0,"title":"✗ RuntimeError: <b>x</b>"}; 4 criterion-specific checks (PASS); Launches 3273, 3590; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.7 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p1-7-id-ranges) | Compared F16f redacted error: expected false, actual false; 2 criterion-specific checks (PASS); Launches 3286, 3598; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.8 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p1-8-id-ranges) | Compared 9.2.1 S01-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-outer-fold-untouched: independently judged fresh screenshot: expected "PASS", actual "PASS"; 2 criterion-specific checks (PASS); Launches 3301, 3608; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.9 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p1-9-id-ranges) | Compared 9.2.1 S02-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-stack-trace: independently judged fresh screenshot: expected "PASS", actual "PASS"; 2 criterion-specific checks (PASS); Launches 3301, 3608; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P1.10 | SHOULD | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p1-10-id-ranges) | Compared F04 stable card before tail caption: expected String with 279 entries; SHA256 2e61a4fb59491954 (full value in JSON), actual String with 279 entries; SHA256 2e61a4fb59491954 (full value in JSON); 2 criterion-specific checks (PASS); Launches 3242, 3570; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P2.1 | MUST | PASS | [19 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 14 log / 14 item IDs](#p2-1-id-ranges) | Historical-only, not a new execution: Compared Every escaping matrix cell independently inspected: expected 14, actual 14; 19 criterion-specific checks (PASS); Launches 762; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P2.2 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 30 log / 47 item IDs](#p2-2-id-ranges) | Historical-only, not a new execution: Compared Data outside code has entity &lt;other&gt;: expected true, actual true; 4 criterion-specific checks (PASS); Launches 762; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P2.3 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#p2-3-id-ranges) | Historical-only, not a new execution: Compared M1 focused assertion evidence from the FULL suite: expected "At least 5 matching examples, all passed", actual Array with 9 entries; SHA256 93d6dc9b2876e934 (full value in JSON); 4 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P2.4 | MUST | PASS | [68 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 570 item IDs](#p2-4-id-ranges) | Historical-only, not a new execution: Compared F01 plain raw non-hook names: expected Array with 3 entries; SHA256 4f10eb6d07afd55d (full value in JSON), actual Array with 3 entries; SHA256 4f10eb6d07afd55d (full value in JSON); 68 criterion-specific checks (PASS); Launches 740-742, 744-745, 747, 761-763, 767-773, 777-778, 818-820, 822-823, 825, 839-841, 845-851, 855-856, 1034-1045, 1060-1071, 1145-1148, 1159-1162; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P3.1 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 422 log / 666 item IDs](#p3-1-id-ranges) | Historical-only, not a new execution: Compared Complete nested read API evidence covers no-prefix rule: expected 0, actual 0; 1 criterion-specific checks (PASS); Launches 740-742, 744-748, 761-763, 767-778, 818-820, 822-826, 839-841, 845-856, 935-937, 1034-1045, 1060-1071, 1145-1148, 1159-1162; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P3.2 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 6 log / 6 item IDs](#p3-2-id-ranges) | Historical-only, not a new execution: Compared F16a raw continuation fence: expected true, actual true; 2 criterion-specific checks (PASS); Launches 767, 1045; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P3.3 | MUST | PASS | [26 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 110 log / 161 item IDs](#p3-3-id-ranges) | Historical-only, not a new execution: Compared F14 raw authored user log is byte-identical: expected 1, actual 1; 26 criterion-specific checks (PASS); Launches 762, 774-778, 918, 920-922, 930-934, 1091-1092, 1094, 1146-1148; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P3.4 | MUST | PASS | [10 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 7 log / 14 item IDs](#p3-4-id-ranges) | Historical-only, not a new execution: Compared Actual native Console observed for all four required families: expected ["F01","F04","F10a","F11a"], actual ["F01","F04","F10a","F11a"]; 10 criterion-specific checks (PASS); Launches 740, 749, 754, 961; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P4.1 | MUST | PASS | [8 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 20 item IDs](#p4-1-id-ranges) | Historical-only, not a new execution: Compared F02 plain/1 exact TABLE_ONLY_AMBER description: expected "`value` = `TABLE_ONLY_AMBER` · _Examples: Table-only substitution · line 12_", actual "`value` = `TABLE_ONLY_AMBER` · _Examples: Table-only substitution · line 12_"; 8 criterion-specific checks (PASS); Launches 963, 967, 971, 975; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P4.2 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 47 item IDs](#p4-2-id-ranges) | Historical-only, not a new execution: Compared All three Outline fallback shapes exercised: expected 3, actual 3; 4 criterion-specific checks (PASS); Launches 762; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P4.3 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 5 item IDs](#p4-3-id-ranges) | Historical-only, not a new execution: Compared Value/key chips each occupy one physical text line at 1100px: expected true, actual true; 2 criterion-specific checks (PASS); Launches 963; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P4.4 | MUST | PASS | [68 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 570 item IDs](#p4-4-id-ranges) | Historical-only, not a new execution: Compared F01 plain raw scenario names/parameters: expected [["features/presentation_ledger/qa_runtime/F01.feature:3","Scenario: F01",[]]], actual [["features/presentation_ledger/qa_runtime/F01.feature:3","Scenario: F01",[]]]; 68 criterion-specific checks (PASS); Launches 740-742, 744-745, 747, 761-763, 767-773, 777-778, 818-820, 822-823, 825, 839-841, 845-851, 855-856, 1034-1045, 1060-1071, 1145-1148, 1159-1162; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P5.1 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 6 log / 2 item IDs](#p5-1-id-ranges) | Compared F01 exact three caption/preview goldens: expected Array with 3 entries; SHA256 1b3d36d177c40565 (full value in JSON), actual Array with 3 entries; SHA256 1b3d36d177c40565 (full value in JSON); 2 criterion-specific checks (PASS); Launches 3237, 3567; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P5.2 | MUST | PASS | [6 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 20 log / 12 item IDs](#p5-2-id-ranges) | Compared F04 exact JPEG caption: expected "`after-failure.jpg` · JPEG · 754 × 790 · 36 KB", actual "`after-failure.jpg` · JPEG · 754 × 790 · 36 KB"; 6 criterion-specific checks (PASS); Launches 3242, 3249, 3287, 3570, 3574, 3599; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P5.3 | MUST | PASS | [384 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1876 log / 1600 item IDs](#p5-3-id-ranges) | Compared F12 caller message precedes meta line: expected true, actual true; 384 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P5.4 | MUST | PASS | [384 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1876 log / 1600 item IDs](#p5-4-id-ranges) | Compared F12 failure-evidence suffix: expected true, actual true; 384 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P5.5 | MUST | PASS | [6 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 8 log / 2 item IDs](#p5-5-id-ranges) | Compared F18 line truncation caption: expected true, actual true; 6 criterion-specific checks (PASS); Launches 3289, 3600; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P5.6 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 24 log / 8 item IDs](#p5-6-id-ranges) | Compared F17: batch size 1 and default emit identical owner-local filenames: expected Array with 6 entries; SHA256 83c883badfcabb5d (full value in JSON), actual Array with 6 entries; SHA256 83c883badfcabb5d (full value in JSON); 4 criterion-specific checks (PASS); Launches 3287, 3565, 3599, 3802; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P5.7 | MUST | PASS | [10 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 260 log / 1066 item IDs](#p5-7-id-ranges) | Compared Decision 8 F08 plain: every submitted attachment has exact downloaded bytes: expected 15, actual 15; 10 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3524, 3526, 3567-3600, 3604-3612, 3661-3694, 3698-3706, 3761, 3763; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P5.8 | MUST | PASS | [18 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 12 log / 4 item IDs](#p5-8-id-ranges) | Compared 9.2.1 S06-wp5-ci-final-20261101-c9.2.1-f01-plain-captions-preview-download: actual caption/preview visual observation: expected "PASS", actual "PASS"; 18 criterion-specific checks (PASS); Launches 3237, 3384, 3567, 3661; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P6.1 | MUST | PASS | [136 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 240 item IDs](#p6-1-id-ranges) | Historical-only, not a new execution: Compared M1 focused assertion evidence from the FULL suite: expected "At least 1 matching examples, all passed", actual Array with 17 entries; SHA256 7a4c80801046c18f (full value in JSON); 136 criterion-specific checks (PASS); Launches 1142-1144, 1146-1147, 1149-1151, 1154, 1156-1158, 1160-1161, 1163-1165, 1168, 1172-1174, 1176-1177, 1179-1181, 1184, 1186-1188, 1190-1191, 1193-1195, 1198; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P6.2 | MUST | PASS | [68 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 570 item IDs](#p6-2-id-ranges) | Historical-only, not a new execution: Compared F01 plain hook types: expected [], actual []; 68 criterion-specific checks (PASS); Launches 740-742, 744-745, 747, 761-763, 767-773, 777-778, 818-820, 822-823, 825, 839-841, 845-851, 855-856, 1034-1045, 1060-1071, 1145-1148, 1159-1162; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P6.3 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 5 item IDs](#p6-3-id-ranges) | Historical-only, not a new execution: Compared F04 JPEG belongs to After hook: expected ["AFTER_METHOD","After hook"], actual ["AFTER_METHOD","After hook"]; 1 criterion-specific checks (PASS); Launches 1145; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P6.4 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 12 item IDs](#p6-4-id-ranges) | Historical-only, not a new execution: Compared Judged native S07 screenshots: expected "At least one retained native image, all judged PASS", actual Array with 2 entries; SHA256 ca353845bfcd979f (full value in JSON); 1 criterion-specific checks (PASS); Launches 764, 1142; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P7.1 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 8 log / 17 item IDs](#p7-1-id-ranges) | Historical-only, not a new execution: Compared AMBER separated companion exact table content, both argument orders (Decision 4): expected Array with 2 entries; SHA256 5d7e3975d32e56b7 (full value in JSON), actual Array with 2 entries; SHA256 5d7e3975d32e56b7 (full value in JSON); 4 criterion-specific checks (PASS); Launches 742; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P7.2 | MUST | PASS | [5 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 4 item IDs](#p7-2-id-ranges) | Historical-only, not a new execution: Compared F13 eight-column alignment golden: expected true, actual true; 5 criterion-specific checks (PASS); Launches 761; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P7.3 | MUST | PASS | [5 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 52 item IDs](#p7-3-id-ranges) | Historical-only, not a new execution: Compared F07 all fifty argument-free steps omit descriptions: expected [50,[]], actual [50,[]]; 5 criterion-specific checks (PASS); Launches 745; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P7.4 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 9 log / 8 item IDs](#p7-4-id-ranges) | Historical-only, not a new execution: Compared Declared/detected JSON DocString caption: expected true, actual true; 4 criterion-specific checks (PASS); Launches 773; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P7.5 | MUST | PASS | [3 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 4 log / 8 item IDs](#p7-5-id-ranges) | Historical-only, not a new execution: Compared plain-1 numeric columns computed right alignment: expected true, actual true; 3 criterion-specific checks (PASS); Launches 761, 839; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P8.1 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 4 log / 4 item IDs](#p8-1-id-ranges) | Compared F10a exact passed assertion: expected ["✓ Assertion passed · Order is accepted · expected `ACCEPTED`"], actual ["✓ Assertion passed · Order is accepted · expected `ACCEPTED`"]; 4 criterion-specific checks (PASS); Launches 3252, 3254, 3576, 3578; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.2 | MUST | PASS | [8 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 6 log / 6 item IDs](#p8-2-id-ranges) | Compared F10b long expected omitted from chip: expected false, actual false; 8 criterion-specific checks (PASS); Launches 3253, 3255, 3257, 3577, 3579-3580; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.3 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p8-3-id-ranges) | Compared F10c multiline actual continuation: expected true, actual true; 2 criterion-specific checks (PASS); Launches 3254, 3578; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.4 | MUST | PASS | [10 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 8 log / 8 item IDs](#p8-4-id-ranges) | Compared F11b HTTP title: expected "## ⚠ GET /words → 404 · 31 ms", actual "## ⚠ GET /words → 404 · 31 ms"; 10 criterion-specific checks (PASS); Launches 3258, 3260-3261, 3263, 3581-3584; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.5 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 10 log / 2 item IDs](#p8-5-id-ranges) | Compared F12 empty action card title: expected true, actual true; 4 criterion-specific checks (PASS); Launches 3267, 3587; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.6 | MUST | PASS | [576 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1604 log / 1904 item IDs](#p8-6-id-ranges) | Compared F01 INFO headings: expected [], actual []; 576 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.7 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p8-7-id-ranges) | Compared F11f secret removed from title and URL chip: expected [false,true], actual [false,true]; 2 criterion-specific checks (PASS); Launches 3265, 3586; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.8 | MUST | PASS | [96 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 288 item IDs](#p8-8-id-ranges) | Compared F10a plain/1: baseline native/logger stdout bytes, excluding only Cucumber summary/stopwatch: expected String with 202 entries; SHA256 b72adc74b67a3429 (full value in JSON), actual String with 202 entries; SHA256 b72adc74b67a3429 (full value in JSON); 96 criterion-specific checks (PASS); Launches 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267, 3331-3332, 3334-3338, 3340-3342, 3344-3345, 3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3479-3481, 3483-3491, 3576-3587, 3623-3634, 3670-3681, 3717-3728; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P8.9 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#p8-9-id-ranges) | Compared M1: unchanged omission marker and public bounds verified by product and independent specs: expected "At least 2 matching examples, all passed", actual Array with 2 entries; SHA256 1d458e837c6a4ae3 (full value in JSON); 4 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P9.1 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 3 item IDs](#p9-1-id-ranges) | Historical-only, not a new execution: Compared F19d no generated context: expected ["",[]], actual ["",[]]; 1 criterion-specific checks (PASS); Launches 777; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P9.2 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 12 item IDs](#p9-2-id-ranges) | Historical-only, not a new execution: Compared F19a exact context attributes: expected [["ci.build","42"],["cucumber","10.2.0"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.3.12"],["sdk","1.3.2"]], actual [["ci.build","42"],["cucumber","10.2.0"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.3.12"],["sdk","1.3.2"]]; 4 criterion-specific checks (PASS); Launches 774, 776, 1093, 1095; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P9.3 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 3 item IDs](#p9-3-id-ranges) | Historical-only, not a new execution: Compared F19b exact context attributes: expected [["ci.build","42"],["cucumber","10.2.0"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.3.12"],["sdk","custom"]], actual [["ci.build","42"],["cucumber","10.2.0"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.3.12"],["sdk","custom"]]; 1 criterion-specific checks (PASS); Launches 775; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P9.4 | MUST | PASS | [9 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 15 item IDs](#p9-4-id-ranges) | Historical-only, not a new execution: Compared F19a context description: expected "Cucumber 10.2.0 · Ruby 3.3.12 · feature/ledger@e7dae2b", actual "Cucumber 10.2.0 · Ruby 3.3.12 · feature/ledger@e7dae2b"; 9 criterion-specific checks (PASS); Launches 774-776, 1093, 1095; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P9.5 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 3 item IDs](#p9-5-id-ranges) | Historical-only, not a new execution: Compared Judged native S10 screenshots: expected "At least one retained native image, all judged PASS", actual Array with 1 entries; SHA256 828eb3a0082100a5 (full value in JSON); 1 criterion-specific checks (PASS); Launches 774; runtime SHA c27510547ace0d4baaf964a0575e5bec4344e11a. |
| P10.1 | MUST | PASS | [6 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 20 log / 8 item IDs](#p10-1-id-ranges) | Compared F01: unset presentation adds no Tier 2 tags: expected [], actual []; 6 criterion-specific checks (PASS); Launches 3564-3566, 3801-3803; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.2 | MUST | PASS | [4 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 2 log / 2 item IDs](#p10-2-id-ranges) | Compared F20 fancy: exactly one presentation warning: expected 1, actual 1; 4 criterion-specific checks (PASS); Launches 3296, 3605; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.3 | MUST | PASS | [464 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 464 log / 398 item IDs](#p10-3-id-ranges) | Compared F01 log 17750 exact tag/style vocabulary: expected [], actual []; 464 criterion-specific checks (PASS); Launches 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3661-3707; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.4 | MUST | PASS | [66 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 66 log / 60 item IDs](#p10-4-id-ranges) | Compared F04 ERROR 0 first line: expected "## ✗ RuntimeError: INDEPENDENT\\_FULL\\_BACKTRACE\n", actual "## ✗ RuntimeError: INDEPENDENT\\_FULL\\_BACKTRACE\n"; 66 criterion-specific checks (PASS); Launches 3390, 3405, 3407-3408, 3413, 3415, 3419, 3424, 3428, 3430-3431, 3433-3434, 3436, 3453, 3455, 3459, 3664, 3672-3674, 3677-3678, 3681, 3684, 3687-3692, 3702-3703, 3705; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.5 | MUST | PASS | [464 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 464 log / 398 item IDs](#p10-5-id-ranges) | Compared F01 log 0 rich byte budget: expected "<= 1076 bytes", actual 241; 464 criterion-specific checks (PASS); Launches 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3661-3707; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.6 | MUST | PASS | [1116 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 1856 log / 1592 item IDs](#p10-6-id-ranges) | Compared Paired log ownership and level counts: expected Hash with 1 entries; SHA256 aed9e705ae1289aa (full value in JSON), actual Hash with 1 entries; SHA256 aed9e705ae1289aa (full value in JSON); 1116 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3567-3754; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.7 | MUST | PASS | [564 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 2960 item IDs](#p10-7-id-ranges) | Compared F01 unchanged item metadata plain/rich: expected Array with 3 entries; SHA256 402d550fe0229c49 (full value in JSON), actual Array with 3 entries; SHA256 402d550fe0229c49 (full value in JSON); 564 criterion-specific checks (PASS); Launches 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3567-3754; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.8 | MUST | PASS | [108 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 54 log / 102 item IDs](#p10-8-id-ranges) | Compared F04 log 17779 fence blank lines in details: expected true, actual true; 108 criterion-specific checks (PASS); Launches 3390, 3410, 3416, 3424, 3428, 3430-3431, 3433-3434, 3436, 3439, 3453, 3459, 3664, 3675, 3679, 3684, 3687-3692, 3694, 3702, 3705; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.9 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 4 log / 4 item IDs](#p10-9-id-ranges) | Compared F13 eight-column table has no TH span: expected false, actual false; 2 criterion-specific checks (PASS); Launches 3421, 3682; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.10 | MUST | PASS | [18 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 32 log / 18 item IDs](#p10-10-id-ranges) | Compared 9.2.1 S03-wp5-ci-final-20261101-c9.2.1-f04-frozen-rich-both-folds-expanded: visible rich pills/titles/folds, independently inspected: expected "PASS", actual "PASS"; 18 criterion-specific checks (PASS); Launches 3384, 3402, 3405, 3410, 3412-3413, 3419, 3421, 3453, 3661, 3670, 3672, 3675-3677, 3681-3682, 3702; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| P10.11 | SHOULD | PASS | [8 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 16 log / 8 item IDs](#p10-11-id-ranges) | Compared 9.2.1: computed pass pill contrast, WCAG sRGB relative luminance: expected ">= 4.5:1", actual 5.436358015569269; 8 criterion-specific checks (PASS); Launches 3402, 3405, 3412, 3419, 3670, 3672, 3676, 3681; runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V1 | MUST | PASS | [5 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v1-id-ranges) | Compared Every actual loaded SDK byte hash matches the exact final/baseline Git revision, not the QA branch: expected true, actual true; 5 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V2 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v2-id-ranges) | Compared Frozen-baseline lock diff contains only the gem's own PATH version: expected ["-    reportportal-cucumber-ruby (1.3.1)","+    reportportal-cucumber-ruby (1.3.2)"], actual ["-    reportportal-cucumber-ruby (1.3.1)","+    reportportal-cucumber-ruby (1.3.2)"]; 1 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V3 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v3-id-ranges) | Compared Fresh gem build from final feature tree, locally verified and never published: expected ["reportportal-cucumber-ruby-1.3.2.gem","1.3.2",true,"f41888a9fdd6896630765cbbf350353a7f803e59"], actual ["reportportal-cucumber-ruby-1.3.2.gem","1.3.2",true,"f41888a9fdd6896630765cbbf350353a7f803e59"]; 2 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V4 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v4-id-ranges) | Compared CHANGELOG begins with new patch release and owner SemVer rationale: expected true, actual true; 2 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V5 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v5-id-ranges) | Compared Both switches and Presentation section documented at final SHA: expected [true,true,true], actual [true,true,true]; 1 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V6 | MUST | PASS | [2 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v6-id-ranges) | Compared Decision16: baseline-to-final Helm is untouched and only the exactly audited validation workflow differs: expected ["f41888a9fdd6896630765cbbf350353a7f803e59","PASS",[".github/workflows/validate.yml"]], actual ["f41888a9fdd6896630765cbbf350353a7f803e59","PASS",[".github/workflows/validate.yml"]]; 2 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V7 | MUST | PASS | [3 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v7-id-ranges) | Compared Protected heads still equal original independent observations: expected Hash with 3 entries; SHA256 0dc182c26f5fbe8c (full value in JSON), actual Hash with 3 entries; SHA256 0dc182c26f5fbe8c (full value in JSON); 3 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |
| V8 | MUST | PASS | [1 checks](assets/presentation-ledger-1.3.2-acceptance.json); [all 0 log / 0 item IDs](#v8-id-ranges) | Compared C0-C8 semantic implementation order, P10 isolated stage retained: expected true, actual true; 1 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA f41888a9fdd6896630765cbbf350353a7f803e59. |

## Defects
Decision15 explicitly excepts only the named F14 backslash failure title while retaining complete fail-closed omission. Original title-comparison mismatches remain in the evidence; no golden/redaction change or broader exception is applied.

| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| WP5-D001 | S3 | G11 | Cucumber 9.2.1: unchanged F01-F18 wrapper-free replay, 10 warmups/50 samples; F07 medians of three | {"wall_ratio_max":1.1,"every_entry_p95_ms":"< 2","replay_errors":[]} | {"wall":{"baseline":{"samples_s":[1.4397960009955568,1.3018013760010945,1.2534520420012996],"median_s":1.3018013760010945},"plain":{"samples_s":[1.47084825100319,1.4980479170044418; full values in JSON | WP5-0bd5af41d4-11441 |

Retained earlier failures are not waived: the independent Ruby 3.1 focused run observed 0.1342089579993626 s against the unchanged <0.12 s assertion, without the handle_error diagnostic observer. Its original result and command provenance remain in `docs/reviews/assets/wp5-final-20261101/spec-repair-ruby31-focused.json` and `.provenance.json` on the 1.x QA branch. The original RSpec keyword-wrapper failures remain in their original matrix evidence. Fresh all-six-cell evidence is required for G10.

Original remote CI attempt-1 failures (2x SIGINT spooled=0 and frozen 1.3.1 SIGINT/HTTP-400 receipt failures) remain separately recorded in `docs/reviews/assets/wp5-ci-final-20261101/ci-attempt1-independent-review.json`. Unchanged attempt-2 success does not establish their cause or waive an assertion. Independent classification: the legacy failures predate Ledger; budget/scheduling sensitivity is a supported explanation, not proof of runner-only causation or a demonstrated repaired SDK defect.

Evidence-integrity findings, separate from SDK defects: the independent publication review found three S2 packaging gaps (quiet G11 root omitted, historical raw references not selected, and portable reproduction setup missing). The bounded curator/reproduction-guide correction passed 35 synthetic assertions and Master review; original findings remain in the publication-audit sidecar. Final selection and secret/size/path audit remain a publication gate, not an SDK waiver.

QA harness observations are retained separately: an initial package-binding helper rejected comma-formatted counts despite identical package/runtime bytes; its failed result remains on 1.x. Console replay attempt 1 performed only GET and stopped because list severity `error` differs from direct GET `ERROR`; identical 10,492-byte messages were independently hash-verified before attempt 2. Only severity casing is canonicalized, not message content.

Historical-index repair preserves every committed Q and WP5 object at its original ID; 17 later in-progress legacy variants are retained inline under unique `DRAFT-HISTORY-*` IDs with full original draft objects and explicit mappings. The Master before-repair witness is unchanged. No old failure, input, expected/actual value or verdict is discarded.

The fixture-only containment test correction additionally passes 37 unchanged-security assertions with a QA-local TMPDIR; the earlier host failure and separate unchanged-test container pass remain retained. Production curator source is unchanged by that fixture correction.

## Screenshots
Historical screenshots remain at their original Launches/runtime and are not relabelled final. Fresh final-head captures and DOM observations are indexed separately below.
- S01-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-outer-fold-untouched: Launch 3301; item 26547; log 17337; PASS; [image](assets/presentation-ledger-1.3.2/S01-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-outer-fold-untouched.png).
- S01-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-outer-fold-untouched: Launch 3608; item 28900; log 18801; PASS; [image](assets/presentation-ledger-1.3.2/S01-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-outer-fold-untouched.png).
- S02-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-stack-trace: Launch 3301; item 26547; log 17337; PASS; [image](assets/presentation-ledger-1.3.2/S02-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-stack-trace.png).
- S02-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-stack-trace: Launch 3608; item 28900; log 18801; PASS; [image](assets/presentation-ledger-1.3.2/S02-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-stack-trace.png).
- S03-wp5-ci-final-20261101-c9.2.1-f04-frozen-rich-both-folds-expanded: Launch 3453; item 27715; log 18067; PASS; [image](assets/presentation-ledger-1.3.2/S03-wp5-ci-final-20261101-c9.2.1-f04-frozen-rich-both-folds-expanded.png).
- S03-wp5-ci-final-20261101-c10.2.0-f04-frozen-rich-both-folds-expanded: Launch 3702; item 29640; log 19265; PASS; [image](assets/presentation-ledger-1.3.2/S03-wp5-ci-final-20261101-c10.2.0-f04-frozen-rich-both-folds-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f10a-plain-cards-expanded: Launch 3252; item 26212; log 17156; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f10a-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f10a-rich-cards-expanded: Launch 3402; item 27384; log 17877; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f10a-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f10c-plain-cards-expanded: Launch 3254; item 26235; log 17166; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f10c-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f10c-rich-cards-expanded: Launch 3405; item 27393; log 17880; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f10c-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f11a-plain-cards-expanded: Launch 3258; item 26251; log 17172; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f11a-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f11a-rich-cards-expanded: Launch 3410; item 27408; log 17885; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f11a-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f11b-plain-cards-expanded: Launch 3260; item 26257; log 17175; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f11b-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f11b-rich-cards-expanded: Launch 3412; item 27414; log 17887; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f11b-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f11c-plain-cards-expanded: Launch 3261; item 26260; log 17176; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f11c-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f11c-rich-cards-expanded: Launch 3413; item 27417; log 17888; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f11c-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f12-plain-cards-expanded: Launch 3267; item 26278; log 17182, 17183, 17184, 17185, 17186; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f12-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c9.2.1-f12-rich-cards-expanded: Launch 3419; item 27436; log 17899, 17900, 17901, 17902, 17903; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c9.2.1-f12-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f10a-plain-cards-expanded: Launch 3576; item 28708; log 18695; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f10a-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f10a-rich-cards-expanded: Launch 3670; item 29448; log 19159; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f10a-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f10c-plain-cards-expanded: Launch 3578; item 28714; log 18697; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f10c-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f10c-rich-cards-expanded: Launch 3672; item 29454; log 19161; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f10c-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f11a-plain-cards-expanded: Launch 3581; item 28723; log 18700; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f11a-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f11a-rich-cards-expanded: Launch 3675; item 29463; log 19164; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f11a-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f11b-plain-cards-expanded: Launch 3582; item 28726; log 18701; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f11b-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f11b-rich-cards-expanded: Launch 3676; item 29466; log 19165; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f11b-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f11c-plain-cards-expanded: Launch 3583; item 28729; log 18702; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f11c-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f11c-rich-cards-expanded: Launch 3677; item 29469; log 19166; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f11c-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f12-plain-cards-expanded: Launch 3587; item 28741; log 18706, 18707, 18708, 18709, 18710; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f12-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c10.2.0-f12-rich-cards-expanded: Launch 3681; item 29481; log 19170, 19171, 19172, 19173, 19174; PASS; [image](assets/presentation-ledger-1.3.2/S09-wp5-ci-final-20261101-c10.2.0-f12-rich-cards-expanded.png).
- S06-wp5-ci-final-20261101-c9.2.1-f01-plain-captions-preview-download: Launch 3237; item 25930; log 16950, 16951, 16952; PASS; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c9.2.1-f01-plain-captions-preview-download.png).
- S06-wp5-ci-final-20261101-c9.2.1-f01-rich-captions-preview-download: Launch 3384; item 27188; log 17750, 17751, 17752; PASS; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c9.2.1-f01-rich-captions-preview-download.png).
- S06-wp5-ci-final-20261101-c10.2.0-f01-plain-captions-preview-download: Launch 3567; item 28552; log 18584, 18585, 18586; PASS; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c10.2.0-f01-plain-captions-preview-download.png).
- S06-wp5-ci-final-20261101-c10.2.0-f01-rich-captions-preview-download: Launch 3661; item 29292; log 19048, 19049, 19050; PASS; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c10.2.0-f01-rich-captions-preview-download.png).
- S06-wp5-ci-final-20261101-c9.2.1-f01-plain-captions-preview-download-preview-modal: Launch 3237; item 25930; log 16950, 16951, 16952; N/A; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c9.2.1-f01-plain-captions-preview-download-preview-modal.png).
- S06-wp5-ci-final-20261101-c10.2.0-f01-plain-captions-preview-download-preview-modal: Launch 3567; item 28552; log 18584, 18585, 18586; N/A; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c10.2.0-f01-plain-captions-preview-download-preview-modal.png).
- S06-wp5-ci-final-20261101-c9.2.1-f01-plain-captions-preview-download-preview-modal-steady: Launch 3237; item 25930; log 16950, 16951, 16952; PASS; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c9.2.1-f01-plain-captions-preview-download-preview-modal-steady.png).
- S06-wp5-ci-final-20261101-c10.2.0-f01-plain-captions-preview-download-preview-modal-steady: Launch 3567; item 28552; log 18584, 18585, 18586; PASS; [image](assets/presentation-ledger-1.3.2/S06-wp5-ci-final-20261101-c10.2.0-f01-plain-captions-preview-download-preview-modal-steady.png).
- S08-wp5-ci-final-20261101-c9.2.1-f13-plain-numeric-table: Launch 3268; item 26281; log 17187, 17188; PASS; [image](assets/presentation-ledger-1.3.2/S08-wp5-ci-final-20261101-c9.2.1-f13-plain-numeric-table.png).
- S08-wp5-ci-final-20261101-c9.2.1-f13-rich-numeric-table: Launch 3421; item 27447; log 17909, 17911; PASS; [image](assets/presentation-ledger-1.3.2/S08-wp5-ci-final-20261101-c9.2.1-f13-rich-numeric-table.png).
- S08-wp5-ci-final-20261101-c10.2.0-f13-plain-numeric-table: Launch 3588; item 28744; log 18711, 18712; PASS; [image](assets/presentation-ledger-1.3.2/S08-wp5-ci-final-20261101-c10.2.0-f13-plain-numeric-table.png).
- S08-wp5-ci-final-20261101-c10.2.0-f13-rich-numeric-table: Launch 3682; item 29484; log 19175, 19176; PASS; [image](assets/presentation-ledger-1.3.2/S08-wp5-ci-final-20261101-c10.2.0-f13-rich-numeric-table.png).
- S04-wp5-ci-final-20261101-c9.2.1-f03-legacy-separate-plain-escaped-table: Launch 3240; item 25967; log 16969, 16970, 16971, 16972, 16974, 16975, 16977, 16980; N/A; [image](assets/presentation-ledger-1.3.2/S04-wp5-ci-final-20261101-c9.2.1-f03-legacy-separate-plain-escaped-table.png).
- S04-wp5-ci-final-20261101-c9.2.1-f14-plain-escaped-table: Launch 3270; item 26288; log 17190, 17191, 17192, 17193, 17194, 17195, 17196, 17197, 17198, 17199, 17200, 17201, 17202, 17203, 17204, 17205, 17207, 17208, 17209, 17210, 17211, 17212, 17213, 17214, 17215, 17216, 17217, 17218, 17219, 17220; PASS; [image](assets/presentation-ledger-1.3.2/S04-wp5-ci-final-20261101-c9.2.1-f14-plain-escaped-table.png).
- S04-wp5-ci-final-20261101-c9.2.1-f03-legacy-separate-plain-escaped-table-table-expanded: Launch 3240; item 25967; log 16969, 16970, 16971, 16972, 16974, 16975, 16977, 16980; PASS; [image](assets/presentation-ledger-1.3.2/S04-wp5-ci-final-20261101-c9.2.1-f03-legacy-separate-plain-escaped-table-table-expanded.png).
- S04-wp5-ci-final-20261101-c10.2.0-f03-legacy-separate-plain-escaped-table-table-expanded: Launch 3569; item 28572; log 18595, 18596, 18597, 18598, 18599, 18600, 18601, 18602; PASS; [image](assets/presentation-ledger-1.3.2/S04-wp5-ci-final-20261101-c10.2.0-f03-legacy-separate-plain-escaped-table-table-expanded.png).
- S04-wp5-ci-final-20261101-c10.2.0-f14-plain-escaped-table: Launch 3589; item 28748; log 18713, 18714, 18715, 18716, 18717, 18718, 18719, 18720, 18721, 18722, 18723, 18724, 18725, 18726, 18727, 18728, 18729, 18730, 18731, 18732, 18733, 18734, 18735, 18736, 18737, 18738, 18739, 18740, 18741, 18742; PASS; [image](assets/presentation-ledger-1.3.2/S04-wp5-ci-final-20261101-c10.2.0-f14-plain-escaped-table.png).
- S05-wp5-ci-final-20261101-c9.2.1-f02-description-only-golden-plain-suite-list: Launch 3304; item 26560; log 17344, 17345; PASS; [image](assets/presentation-ledger-1.3.2/S05-wp5-ci-final-20261101-c9.2.1-f02-description-only-golden-plain-suite-list.png).
- S05-wp5-ci-final-20261101-c10.2.0-f02-description-only-golden-plain-suite-list: Launch 3610; item 28907; log 18804, 18805; PASS; [image](assets/presentation-ledger-1.3.2/S05-wp5-ci-final-20261101-c10.2.0-f02-description-only-golden-plain-suite-list.png).
- S07-wp5-ci-final-20261101-c9.2.1-f15-plain-hook-rows: Launch 3275; item 26373; log 17237, 17238, 17239, 17240; PASS; [image](assets/presentation-ledger-1.3.2/S07-wp5-ci-final-20261101-c9.2.1-f15-plain-hook-rows.png).
- S07-wp5-ci-final-20261101-c10.2.0-f15-plain-hook-rows: Launch 3591; item 28824; log 18757, 18758, 18759, 18760; PASS; [image](assets/presentation-ledger-1.3.2/S07-wp5-ci-final-20261101-c10.2.0-f15-plain-hook-rows.png).
- S10-wp5-ci-final-20261101-c9.2.1-f19a-plain-launch-list: Launch 3290; item 26429; log 17270; PASS; [image](assets/presentation-ledger-1.3.2/S10-wp5-ci-final-20261101-c9.2.1-f19a-plain-launch-list.png).
- S10-wp5-ci-final-20261101-c10.2.0-f19a-plain-launch-list: Launch 3601; item 28865; log 18785; PASS; [image](assets/presentation-ledger-1.3.2/S10-wp5-ci-final-20261101-c10.2.0-f19a-plain-launch-list.png).
- S11-wp5-ci-final-20261101-c9.2.1-f01-plain-markdown-off-then-restored: Launch 3237; item 25930; log 16950, 16951, 16952; N/A; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c9.2.1-f01-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-markdown-off-then-restored: Launch 3301; item 26547; log 17337, 17338; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c10.2.0-f01-plain-markdown-off-then-restored: Launch 3567; item 28552; log 18584, 18585, 18586; N/A; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c10.2.0-f01-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-markdown-off-then-restored: Launch 3608; item 28900; log 18801, 18802; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c9.2.1-f01-plain-markdown-off-then-restored-expanded: Launch 3237; item 25930; log 16950, 16951, 16952; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c9.2.1-f01-plain-markdown-off-then-restored-expanded.png).
- S11-wp5-ci-final-20261101-c10.2.0-f01-plain-markdown-off-then-restored-expanded: Launch 3567; item 28552; log 18584, 18585, 18586; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c10.2.0-f01-plain-markdown-off-then-restored-expanded.png).
- S11-wp5-ci-final-20261101-c9.2.1-f10a-plain-markdown-off-then-restored: Launch 3252; item 26212; log 17156; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c9.2.1-f10a-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c9.2.1-f11a-plain-markdown-off-then-restored: Launch 3258; item 26251; log 17172; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c9.2.1-f11a-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c10.2.0-f10a-plain-markdown-off-then-restored: Launch 3576; item 28708; log 18695; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c10.2.0-f10a-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c10.2.0-f11a-plain-markdown-off-then-restored: Launch 3581; item 28723; log 18700; PASS; [image](assets/presentation-ledger-1.3.2/S11-wp5-ci-final-20261101-c10.2.0-f11a-plain-markdown-off-then-restored.png).
- S12-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-console-blocked-nested-ui: Launch 3301; item 26547; log 17337, 17338; BLOCKED; [image](assets/presentation-ledger-1.3.2/S12-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-console-blocked-nested-ui.png).
- S12-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-console-blocked-nested-ui: Launch 3608; item 28900; log 18801, 18802; BLOCKED; [image](assets/presentation-ledger-1.3.2/S12-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-console-blocked-nested-ui.png).
- S12-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-console-flat-Decision17: Launch 3805; item 30409; log 19748; PASS; [image](assets/presentation-ledger-1.3.2/S12-wp5-ci-final-20261101-c9.2.1-f04-frozen-plain-console-flat-Decision17.png).
- S12-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-console-flat-Decision17: Launch 3806; item 30410; log 19749; PASS; [image](assets/presentation-ledger-1.3.2/S12-wp5-ci-final-20261101-c10.2.0-f04-frozen-plain-console-flat-Decision17.png).

## Exact ID Ranges
Every range below is inclusive and round-trip checked; gaps and singletons are preserved, and the complete uncompressed arrays remain in the evidence JSON.

<a id="g1-id-ranges"></a>
<details>
<summary>G1: 468 Launch, 3696 item, 0 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3551, 3555-3788, 3792-3803

Items: 25929-25931, 25949-25971, 25973, 25975-25976, 25978-25979, 25981, 25983-25984, 25987, 25989, 25991, 26000-26009, 26012-26013, 26015-26016, 26019-26030, 26033-26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26124, 26126-26127, 26130-26131, 26134-26135, 26138-26139, 26142-26143, 26145, 26147, 26149-26150, 26153-26154, 26157-26158, 26161-26162, 26164-26165, 26168-26169, 26171-26172, 26175-26176, 26178, 26180, 26187-26196, 26210, 26212, 26214, 26231-26239, 26247-26252, 26256-26261, 26263, 26265-26266, 26268-26273, 26277-26282, 26285, 26287-26308, 26311-26313, 26315-26336, 26340-26368, 26372-26377, 26381-26388, 26392-26397, 26401-26406, 26410-26416, 26420-26429, 26431, 26434-26438, 26440, 26444-26449, 26497-26499, 26521, 26523, 26525, 26527, 26530, 26532-26533, 26536-26550, 26554-26555, 26557, 26560-26564, 26573-26575, 26579-26581, 26585-26587, 26594-26596, 26600-26616, 26628-26629, 26631-26650, 26654-26674, 26678-26692, 26695-26696, 26698-26732, 26736-26743, 26745, 26747-26748, 26750-26785, 26789-26803, 26818, 26820-26821, 26824-26829, 26835-26840, 26844-26856, 26859-26861, 26863, 26866-26934, 26941-26948, 26958, 26960, 26962-26968, 26975-26998, 27002-27010, 27028-27052, 27069-27070, 27072-27077, 27098-27099, 27101, 27135-27136, 27138, 27156-27157, 27159, 27186, 27188, 27190, 27199-27209, 27211, 27213, 27215-27216, 27219, 27221, 27226-27242, 27246-27261, 27264-27267, 27269-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27336-27366, 27370-27376, 27380-27385, 27389-27394, 27398-27403, 27407-27409, 27413-27418, 27422-27427, 27432-27437, 27445, 27447, 27449, 27451, 27476-27477, 27479, 27482, 27484, 27486, 27488, 27490, 27492, 27494, 27496, 27498-27499, 27502-27535, 27543, 27545, 27547, 27550-27551, 27554-27555, 27558, 27560, 27562, 27564, 27566, 27568, 27570, 27572, 27574, 27577, 27579, 27581, 27583-27584, 27586-27599, 27606-27613, 27618-27623, 27628-27633, 27637-27643, 27647-27657, 27661-27666, 27670-27675, 27683-27685, 27694-27710, 27714-27718, 27722-27729, 27736-27738, 27742-27747, 27751-27769, 27772, 27788-27795, 27798-27800, 27802, 27804, 27806-27814, 27818-27838, 27844-27926, 27933-27942, 27954-27962, 27969-28486, 28496-30343, 30353-30407

Logs: N/A

</details>

<a id="g2-id-ranges"></a>
<details>
<summary>G2: 258 Launch, 1160 item, 1356 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3518-3551, 3555-3563, 3567-3600, 3604-3612, 3661-3694, 3698-3706, 3755-3788, 3792-3800

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 28176, 28179-28180, 28183-28184, 28187-28188, 28191-28192, 28196-28197, 28200-28201, 28204-28205, 28208-28209, 28213, 28215, 28218, 28220, 28222, 28224, 28226, 28228, 28230, 28232, 28234, 28236, 28239-28288, 28291, 28293, 28295, 28297, 28299, 28311, 28313, 28315, 28317, 28319, 28322, 28324, 28326, 28329, 28332, 28335, 28338, 28341, 28344, 28347, 28350, 28353, 28356, 28359, 28362, 28365, 28368-28369, 28372-28373, 28375-28376, 28378-28379, 28381-28382, 28384-28385, 28387-28388, 28390-28391, 28393-28394, 28396-28397, 28399-28400, 28402-28403, 28405-28406, 28408-28409, 28411-28412, 28414, 28416, 28419, 28421, 28423, 28425, 28427, 28429, 28431, 28433, 28435, 28437, 28439, 28441, 28443, 28445, 28448-28451, 28454-28455, 28458-28459, 28462, 28465, 28468, 28471, 28474, 28477-28478, 28481-28486, 28498, 28501, 28504, 28507-28508, 28511-28512, 28515-28516, 28519-28520, 28524, 28526, 28529, 28532, 28534, 28537, 28540, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 30033, 30036-30037, 30040-30041, 30044-30045, 30048-30049, 30053-30054, 30057-30058, 30061-30062, 30065-30066, 30070, 30072, 30075, 30077, 30079, 30081, 30083, 30085, 30087, 30089, 30091, 30093, 30096-30145, 30148, 30150, 30152, 30154, 30156, 30168, 30170, 30172, 30174, 30176, 30179, 30181, 30183, 30186, 30189, 30192, 30195, 30198, 30201, 30204, 30207, 30210, 30213, 30216, 30219, 30222, 30225-30226, 30229-30230, 30232-30233, 30235-30236, 30238-30239, 30241-30242, 30244-30245, 30247-30248, 30250-30251, 30253-30254, 30256-30257, 30259-30260, 30262-30263, 30265-30266, 30268-30269, 30271, 30273, 30276, 30278, 30280, 30282, 30284, 30286, 30288, 30290, 30292, 30294, 30296, 30298, 30300, 30302, 30305-30308, 30311-30312, 30315-30316, 30319, 30322, 30325, 30328, 30331, 30334-30335, 30338-30343, 30355, 30358, 30361, 30364-30365, 30368-30369, 30372-30373, 30376-30377, 30381, 30383, 30386, 30389, 30391, 30394, 30397

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17269, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18031, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18084, 18349-18543, 18547-18573, 18584-18784, 18788-18814, 19048-19248, 19252-19278, 19512-19706, 19710-19736

</details>

<a id="g3-id-ranges"></a>
<details>
<summary>G3: 258 Launch, 1128 item, 348 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3518-3551, 3555-3563, 3567-3600, 3604-3612, 3661-3694, 3698-3706, 3755-3788, 3792-3800

Items: 25931, 25949-25971, 25973, 25975-25976, 25978-25979, 25981, 25983-25984, 25987, 25989, 25991, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26210, 26212, 26214, 26231-26239, 26247-26252, 26256-26261, 26263, 26265-26266, 26268-26273, 26279-26282, 26285, 26287-26308, 26311-26313, 26315-26336, 26340-26368, 26372-26377, 26381-26388, 26392-26397, 26401-26406, 26410-26412, 26415-26416, 26422, 26444-26449, 26499, 26521, 26523, 26525, 26527, 26530, 26532-26533, 26536-26545, 26550, 26554-26555, 26557, 26560-26564, 26573-26575, 26579-26581, 27190, 27199-27209, 27211, 27213, 27215-27216, 27219, 27221, 27226-27242, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27289, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382-27385, 27389-27394, 27398-27403, 27407-27409, 27413-27418, 27422-27427, 27432-27434, 27437, 27445, 27447, 27449, 27451, 27476-27477, 27479, 27482, 27484, 27486, 27488, 27490, 27492, 27494, 27496, 27498-27499, 27502-27535, 27543, 27545, 27547, 27550-27551, 27554-27555, 27558, 27560, 27562, 27564, 27566, 27568, 27570, 27572, 27574, 27577, 27579, 27581, 27583-27584, 27586-27599, 27606-27613, 27618-27623, 27628-27633, 27637-27639, 27642-27643, 27649, 27670-27675, 27685, 27694-27710, 27718, 27722-27729, 27736-27738, 27742-27744, 28176, 28215, 28218, 28220, 28222, 28224, 28226, 28228, 28230, 28232, 28234, 28236, 28239-28248, 28291, 28293, 28295, 28297, 28299, 28311, 28313, 28315, 28317, 28319, 28322, 28324, 28326-28329, 28365, 28477-28478, 28481, 28504, 28526, 28553-28587, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28625, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706-28739, 28742-28851, 28854-28855, 28858, 28873-28878, 28881-28898, 28903-28917, 29293-29327, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29365, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446-29479, 29482-29591, 29594-29595, 29598, 29613-29618, 29621-29638, 29643-29657, 30033, 30072, 30075, 30077, 30079, 30081, 30083, 30085, 30087, 30089, 30091, 30093, 30096-30105, 30148, 30150, 30152, 30154, 30156, 30168, 30170, 30172, 30174, 30176, 30179, 30181, 30183-30186, 30222, 30334-30335, 30338, 30361, 30383

Logs: 16950-16952, 16986-16989, 16991, 16993-16998, 17000, 17003, 17005, 17008, 17010, 17013, 17015, 17018, 17020, 17023, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17147, 17183-17184, 17186, 17254-17259, 17261-17264, 17312-17314, 17338, 17750-17752, 17780-17786, 17788-17791, 17793, 17795, 17797, 17799, 17802, 17804, 17806, 17808, 17810, 17812, 17855-17869, 17871-17873, 17875, 17900-17901, 17903, 18016-18021, 18023-18026, 18046-18048, 18068, 18349-18351, 18369-18379, 18381, 18383, 18385, 18387, 18389, 18391, 18393, 18395, 18397, 18399, 18440-18452, 18466-18467, 18469, 18529-18538, 18549-18551, 18561, 18584-18586, 18604-18614, 18616, 18618, 18620, 18622, 18624, 18626, 18628, 18630, 18632, 18634, 18675-18693, 18707-18708, 18710, 18770-18779, 18790-18792, 18802, 19048-19050, 19068-19078, 19080, 19082, 19084, 19086, 19088, 19090, 19092, 19094, 19096, 19098, 19139-19157, 19171-19172, 19174, 19234-19243, 19254-19256, 19266, 19512-19514, 19532-19542, 19544, 19546, 19548, 19550, 19552, 19554, 19556, 19558, 19560, 19562, 19603-19615, 19629-19630, 19632, 19692-19701, 19712-19714, 19724

</details>

<a id="g4-id-ranges"></a>
<details>
<summary>G4: 328 Launch, 1544 item, 1808 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3298, 3300-3301, 3303-3304, 3307, 3309, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3363, 3371-3373, 3375-3376, 3379, 3381, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3504, 3510-3516, 3567-3600, 3606-3612, 3614-3647, 3653-3659, 3661-3694, 3700-3706, 3708-3741, 3747-3753

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26648, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26791, 26794, 26797, 26800, 26803, 26821, 26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 26931-26934, 26943-26944, 26947-26948, 26962, 26965, 26968, 26977, 26980, 26983-26984, 26987-26992, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27050, 27052, 27072, 27075, 27077, 27101, 27138, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27812, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959, 27962, 27971, 27974, 27977, 27980, 27983, 27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046, 28049, 28051, 28053, 28055, 28057, 28059, 28061, 28063, 28065, 28067, 28069, 28071, 28073, 28075, 28078-28081, 28084-28085, 28088-28089, 28092, 28095, 28098, 28101, 28104, 28107-28108, 28111-28116, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28154, 28156, 28159, 28162, 28164, 28167, 28170, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28960, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082, 29085, 29088, 29091, 29094, 29097, 29100, 29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29195-29198, 29201-29202, 29205-29206, 29209, 29212, 29215, 29218, 29221, 29224-29225, 29228-29233, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29271, 29273, 29276, 29279, 29281, 29284, 29287, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29700, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822, 29825, 29828, 29831, 29834, 29837, 29840, 29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903, 29906, 29908, 29910, 29912, 29914, 29916, 29918, 29920, 29922, 29924, 29926, 29928, 29930, 29932, 29935-29938, 29941-29942, 29945-29946, 29949, 29952, 29955, 29958, 29961, 29964-29965, 29968-29973, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30011, 30013, 30016, 30019, 30021, 30024, 30027

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17269, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17364-17366, 17368-17375, 17391-17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17501-17505, 17513, 17515-17516, 17519-17524, 17526-17534, 17536, 17538-17577, 17582-17585, 17593-17595, 17600-17616, 17633-17645, 17654-17656, 17666, 17707-17714, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18031, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18084, 18089-18099, 18108-18112, 18114, 18116-18119, 18121-18130, 18133-18207, 18212-18216, 18224-18226, 18231-18317, 18323-18347, 18584-18784, 18790-18814, 18816-19016, 19022-19046, 19048-19248, 19254-19278, 19280-19480, 19486-19510

</details>

<a id="g5-id-ranges"></a>
<details>
<summary>G5: 382 Launch, 1600 item, 1876 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 26587, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26648, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26791, 26794, 26797, 26800, 26803, 26821, 26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 26931-26934, 26943-26944, 26947-26948, 26962, 26965, 26968, 26977, 26980, 26983-26984, 26987-26992, 26995, 26998, 27004, 27007, 27010, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27050, 27052, 27072, 27075, 27077, 27101, 27138, 27159, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27812, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959, 27962, 27971, 27974, 27977, 27980, 27983, 27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046, 28049, 28051, 28053, 28055, 28057, 28059, 28061, 28063, 28065, 28067, 28069, 28071, 28073, 28075, 28078-28081, 28084-28085, 28088-28089, 28092, 28095, 28098, 28101, 28104, 28107-28108, 28111-28116, 28119, 28122, 28125, 28128, 28131, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28154, 28156, 28159, 28162, 28164, 28167, 28170, 28173, 28543, 28546-28547, 28550, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 28920, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28960, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082, 29085, 29088, 29091, 29094, 29097, 29100, 29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29195-29198, 29201-29202, 29205-29206, 29209, 29212, 29215, 29218, 29221, 29224-29225, 29228-29233, 29236, 29239, 29242, 29245, 29248, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29271, 29273, 29276, 29279, 29281, 29284, 29287, 29290, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29700, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822, 29825, 29828, 29831, 29834, 29837, 29840, 29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903, 29906, 29908, 29910, 29912, 29914, 29916, 29918, 29920, 29922, 29924, 29926, 29928, 29930, 29932, 29935-29938, 29941-29942, 29945-29946, 29949, 29952, 29955, 29958, 29961, 29964-29965, 29968-29973, 29976, 29979, 29982, 29985, 29988, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30011, 30013, 30016, 30019, 30021, 30024, 30027, 30030, 30400, 30403-30404, 30407

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17361, 17364-17366, 17368-17375, 17391-17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17501-17505, 17513, 17515-17516, 17519-17524, 17526-17534, 17536, 17538-17577, 17582-17585, 17593-17595, 17600-17618, 17622-17624, 17633-17645, 17654-17656, 17666, 17707-17714, 17733, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 18089-18099, 18108-18112, 18114, 18116-18119, 18121-18130, 18133-18207, 18212-18216, 18224-18226, 18231-18348, 18574-19511, 19737-19746

</details>

<a id="g6-id-ranges"></a>
<details>
<summary>G6: 92 Launch, 396 item, 462 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3567-3612

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 18584-18814

</details>

<a id="g7-id-ranges"></a>
<details>
<summary>G7: 382 Launch, 1600 item, 1876 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 26587, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26648, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26791, 26794, 26797, 26800, 26803, 26821, 26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 26931-26934, 26943-26944, 26947-26948, 26962, 26965, 26968, 26977, 26980, 26983-26984, 26987-26992, 26995, 26998, 27004, 27007, 27010, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27050, 27052, 27072, 27075, 27077, 27101, 27138, 27159, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27812, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959, 27962, 27971, 27974, 27977, 27980, 27983, 27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046, 28049, 28051, 28053, 28055, 28057, 28059, 28061, 28063, 28065, 28067, 28069, 28071, 28073, 28075, 28078-28081, 28084-28085, 28088-28089, 28092, 28095, 28098, 28101, 28104, 28107-28108, 28111-28116, 28119, 28122, 28125, 28128, 28131, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28154, 28156, 28159, 28162, 28164, 28167, 28170, 28173, 28543, 28546-28547, 28550, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 28920, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28960, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082, 29085, 29088, 29091, 29094, 29097, 29100, 29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29195-29198, 29201-29202, 29205-29206, 29209, 29212, 29215, 29218, 29221, 29224-29225, 29228-29233, 29236, 29239, 29242, 29245, 29248, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29271, 29273, 29276, 29279, 29281, 29284, 29287, 29290, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29700, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822, 29825, 29828, 29831, 29834, 29837, 29840, 29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903, 29906, 29908, 29910, 29912, 29914, 29916, 29918, 29920, 29922, 29924, 29926, 29928, 29930, 29932, 29935-29938, 29941-29942, 29945-29946, 29949, 29952, 29955, 29958, 29961, 29964-29965, 29968-29973, 29976, 29979, 29982, 29985, 29988, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30011, 30013, 30016, 30019, 30021, 30024, 30027, 30030, 30400, 30403-30404, 30407

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17361, 17364-17366, 17368-17375, 17391-17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17501-17505, 17513, 17515-17516, 17519-17524, 17526-17534, 17536, 17538-17577, 17582-17585, 17593-17595, 17600-17618, 17622-17624, 17633-17645, 17654-17656, 17666, 17707-17714, 17733, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 18089-18099, 18108-18112, 18114, 18116-18119, 18121-18130, 18133-18207, 18212-18216, 18224-18226, 18231-18348, 18574-19511, 19737-19746

</details>

<a id="g8-id-ranges"></a>
<details>
<summary>G8: 382 Launch, 1600 item, 1876 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 26587, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26648, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26791, 26794, 26797, 26800, 26803, 26821, 26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 26931-26934, 26943-26944, 26947-26948, 26962, 26965, 26968, 26977, 26980, 26983-26984, 26987-26992, 26995, 26998, 27004, 27007, 27010, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27050, 27052, 27072, 27075, 27077, 27101, 27138, 27159, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27812, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959, 27962, 27971, 27974, 27977, 27980, 27983, 27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046, 28049, 28051, 28053, 28055, 28057, 28059, 28061, 28063, 28065, 28067, 28069, 28071, 28073, 28075, 28078-28081, 28084-28085, 28088-28089, 28092, 28095, 28098, 28101, 28104, 28107-28108, 28111-28116, 28119, 28122, 28125, 28128, 28131, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28154, 28156, 28159, 28162, 28164, 28167, 28170, 28173, 28543, 28546-28547, 28550, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 28920, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28960, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082, 29085, 29088, 29091, 29094, 29097, 29100, 29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29195-29198, 29201-29202, 29205-29206, 29209, 29212, 29215, 29218, 29221, 29224-29225, 29228-29233, 29236, 29239, 29242, 29245, 29248, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29271, 29273, 29276, 29279, 29281, 29284, 29287, 29290, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29700, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822, 29825, 29828, 29831, 29834, 29837, 29840, 29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903, 29906, 29908, 29910, 29912, 29914, 29916, 29918, 29920, 29922, 29924, 29926, 29928, 29930, 29932, 29935-29938, 29941-29942, 29945-29946, 29949, 29952, 29955, 29958, 29961, 29964-29965, 29968-29973, 29976, 29979, 29982, 29985, 29988, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30011, 30013, 30016, 30019, 30021, 30024, 30027, 30030, 30400, 30403-30404, 30407

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17361, 17364-17366, 17368-17375, 17391-17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17501-17505, 17513, 17515-17516, 17519-17524, 17526-17534, 17536, 17538-17577, 17582-17585, 17593-17595, 17600-17618, 17622-17624, 17633-17645, 17654-17656, 17666, 17707-17714, 17733, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 18089-18099, 18108-18112, 18114, 18116-18119, 18121-18130, 18133-18207, 18212-18216, 18224-18226, 18231-18348, 18574-19511, 19737-19746

</details>

<a id="g9-id-ranges"></a>
<details>
<summary>G9: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="g10-id-ranges"></a>
<details>
<summary>G10: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="g11-id-ranges"></a>
<details>
<summary>G11: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="g12-id-ranges"></a>
<details>
<summary>G12: 188 Launch, 1480 item, 0 log IDs</summary>

Launches: 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3661-3754

Items: 27186, 27188, 27190, 27199-27209, 27211, 27213, 27215-27216, 27219, 27221, 27226-27242, 27246-27261, 27264-27267, 27269-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27336-27366, 27370-27376, 27380-27385, 27389-27394, 27398-27403, 27407-27409, 27413-27418, 27422-27427, 27432-27437, 27445, 27447, 27449, 27451, 27476-27477, 27479, 27482, 27484, 27486, 27488, 27490, 27492, 27494, 27496, 27498-27499, 27502-27535, 27543, 27545, 27547, 27550-27551, 27554-27555, 27558, 27560, 27562, 27564, 27566, 27568, 27570, 27572, 27574, 27577, 27579, 27581, 27583-27584, 27586-27599, 27606-27613, 27618-27623, 27628-27633, 27637-27643, 27647-27657, 27661-27666, 27670-27675, 27683-27685, 27694-27710, 27714-27718, 27722-27729, 27736-27738, 27742-27747, 27751-27769, 27772, 27788-27795, 27798-27800, 27802, 27804, 27806-27814, 27818-27838, 27844-27926, 27933-27942, 27954-27962, 27969-28173, 29291-30030

Logs: N/A

</details>

<a id="p1-1-id-ranges"></a>
<details>
<summary>P1.1: 14 Launch, 14 item, 14 log IDs</summary>

Launches: 3242, 3301, 3373, 3453, 3512, 3521, 3559, 3570, 3608, 3655, 3702, 3749, 3758, 3796

Items: 26002, 26548, 27050, 27716, 28154, 28213, 28524, 28590, 28901, 29271, 29641, 30011, 30070, 30381

Logs: 16985, 17337, 17644, 18067, 18334, 18368, 18560, 18603, 18801, 19033, 19265, 19497, 19531, 19723

</details>

<a id="p1-2-id-ranges"></a>
<details>
<summary>P1.2: 16 Launch, 68 item, 68 log IDs</summary>

Launches: 3273, 3283-3284, 3303, 3350, 3375, 3455, 3513, 3590, 3596-3597, 3609, 3637, 3656, 3703, 3750

Items: 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26403, 26406, 26557, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 27072, 27724, 28159, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28845, 28848, 28906, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29276, 29646, 30016

Logs: 17222-17235, 17250-17251, 17341, 17560-17573, 17654, 18070, 18336, 18743-18756, 18767-18768, 18803, 18975-18988, 19035, 19267, 19499

</details>

<a id="p1-3-id-ranges"></a>
<details>
<summary>P1.3: 20 Launch, 44 item, 44 log IDs</summary>

Launches: 3242, 3273, 3278, 3280-3281, 3283-3284, 3286, 3301, 3307, 3570, 3590, 3593-3598, 3608, 3611

Items: 26002, 26342, 26344, 26346, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26388, 26394, 26397, 26403, 26406, 26412, 26548, 26575, 28590, 28796, 28798, 28800, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28836, 28839, 28842, 28845, 28848, 28851, 28901, 28914

Logs: 16985, 17222-17224, 17226-17235, 17245, 17247-17248, 17250-17251, 17253, 17337, 17350, 18603, 18743-18745, 18747-18756, 18764-18769, 18801, 18806

</details>

<a id="p1-4-id-ranges"></a>
<details>
<summary>P1.4: 26 Launch, 50 item, 50 log IDs</summary>

Launches: 3242, 3273, 3278, 3280-3281, 3283-3284, 3286, 3301, 3307, 3379, 3459, 3515, 3570, 3590, 3593-3598, 3608, 3611, 3658, 3705, 3752

Items: 26002, 26342, 26344, 26346, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26388, 26394, 26397, 26403, 26406, 26412, 26548, 26575, 27101, 27738, 28167, 28590, 28796, 28798, 28800, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28836, 28839, 28842, 28845, 28848, 28851, 28901, 28914, 29284, 29654, 30024

Logs: 16985, 17222-17224, 17226-17235, 17245, 17247-17248, 17250-17251, 17253, 17337, 17350, 17666, 18075, 18339, 18603, 18743-18745, 18747-18756, 18764-18769, 18801, 18806, 19038, 19270, 19502

</details>

<a id="p1-5-id-ranges"></a>
<details>
<summary>P1.5: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3280, 3594

Items: 26394, 28839

Logs: 17247, 18765

</details>

<a id="p1-6-id-ranges"></a>
<details>
<summary>P1.6: 2 Launch, 4 item, 4 log IDs</summary>

Launches: 3273, 3590

Items: 26343, 26361, 28797, 28815

Logs: 17223, 17232, 18744, 18753

</details>

<a id="p1-7-id-ranges"></a>
<details>
<summary>P1.7: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3286, 3598

Items: 26412, 28851

Logs: 17253, 18769

</details>

<a id="p1-8-id-ranges"></a>
<details>
<summary>P1.8: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3301, 3608

Items: 26547, 28900

Logs: 17337, 18801

</details>

<a id="p1-9-id-ranges"></a>
<details>
<summary>P1.9: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3301, 3608

Items: 26547, 28900

Logs: 17337, 18801

</details>

<a id="p1-10-id-ranges"></a>
<details>
<summary>P1.10: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3242, 3570

Items: 26002, 28590

Logs: 16985, 18603

</details>

<a id="p2-1-id-ranges"></a>
<details>
<summary>P2.1: 1 Launch, 14 item, 14 log IDs</summary>

Launches: 762

Items: 6732, 6735, 6738, 6741, 6744, 6747, 6750, 6753, 6756, 6759, 6762, 6765, 6768, 6771

Logs: 4609, 4611, 4613, 4615, 4617, 4619, 4621, 4623, 4625, 4627, 4629, 4631, 4633, 4635

</details>

<a id="p2-2-id-ranges"></a>
<details>
<summary>P2.2: 1 Launch, 47 item, 30 log IDs</summary>

Launches: 762

Items: 6729-6775

Logs: 4608-4637

</details>

<a id="p2-3-id-ranges"></a>
<details>
<summary>P2.3: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="p2-4-id-ranges"></a>
<details>
<summary>P2.4: 68 Launch, 570 item, 0 log IDs</summary>

Launches: 740-742, 744-745, 747, 761-763, 767-773, 777-778, 818-820, 822-823, 825, 839-841, 845-851, 855-856, 1034-1045, 1060-1071, 1145-1148, 1159-1162

Items: 6533-6569, 6575-6647, 6679-6685, 6725-6804, 6819-6845, 6855-6860, 7189-7225, 7231-7303, 7335-7341, 7381-7460, 7475-7501, 7511-7516, 8591-8626, 8669-8704, 9170-9188, 9254-9272

Logs: N/A

</details>

<a id="p3-1-id-ranges"></a>
<details>
<summary>P3.1: 81 Launch, 666 item, 422 log IDs</summary>

Launches: 740-742, 744-748, 761-763, 767-778, 818-820, 822-826, 839-841, 845-856, 935-937, 1034-1045, 1060-1071, 1145-1148, 1159-1162

Items: 6533-6569, 6575-6688, 6725-6804, 6819-6860, 7189-7225, 7231-7344, 7381-7460, 7475-7516, 8173-8182, 8591-8626, 8669-8704, 9170-9188, 9254-9272

Logs: 4479-4497, 4500-4589, 4606-4651, 4660-4684, 4891-4909, 4912-5001, 5018-5063, 5072-5096, 5503-5512, 5693-5708, 5727-5742, 6122-6131, 6172-6181

</details>

<a id="p3-2-id-ranges"></a>
<details>
<summary>P3.2: 2 Launch, 6 item, 6 log IDs</summary>

Launches: 767, 1045

Items: 6819-6821, 8624-8626

Logs: 4660, 5704-5708

</details>

<a id="p3-3-id-ranges"></a>
<details>
<summary>P3.3: 21 Launch, 161 item, 110 log IDs</summary>

Launches: 762, 774-778, 918, 920-922, 930-934, 1091-1092, 1094, 1146-1148

Items: 6729-6775, 6846-6860, 8041-8087, 8117-8130, 8158-8172, 8762-8767, 8771-8773, 9175-9188

Logs: 4608-4637, 4680-4684, 5426-5455, 5470-5477, 5498-5502, 5787-5802, 5804-5811, 6124-6131

</details>

<a id="p3-4-id-ranges"></a>
<details>
<summary>P3.4: 4 Launch, 14 item, 7 log IDs</summary>

Launches: 740, 749, 754, 961

Items: 6533-6535, 6689-6691, 6704-6706, 8296-8300

Logs: 4479-4481, 4590, 4595, 5562-5563

</details>

<a id="p4-1-id-ranges"></a>
<details>
<summary>P4.1: 4 Launch, 20 item, 0 log IDs</summary>

Launches: 963, 967, 971, 975

Items: 8304-8308, 8334-8338, 8364-8368, 8394-8398

Logs: N/A

</details>

<a id="p4-2-id-ranges"></a>
<details>
<summary>P4.2: 1 Launch, 47 item, 0 log IDs</summary>

Launches: 762

Items: 6729-6775

Logs: N/A

</details>

<a id="p4-3-id-ranges"></a>
<details>
<summary>P4.3: 1 Launch, 5 item, 0 log IDs</summary>

Launches: 963

Items: 8304-8308

Logs: N/A

</details>

<a id="p4-4-id-ranges"></a>
<details>
<summary>P4.4: 68 Launch, 570 item, 0 log IDs</summary>

Launches: 740-742, 744-745, 747, 761-763, 767-773, 777-778, 818-820, 822-823, 825, 839-841, 845-851, 855-856, 1034-1045, 1060-1071, 1145-1148, 1159-1162

Items: 6533-6569, 6575-6647, 6679-6685, 6725-6804, 6819-6845, 6855-6860, 7189-7225, 7231-7303, 7335-7341, 7381-7460, 7475-7501, 7511-7516, 8591-8626, 8669-8704, 9170-9188, 9254-9272

Logs: N/A

</details>

<a id="p5-1-id-ranges"></a>
<details>
<summary>P5.1: 2 Launch, 2 item, 6 log IDs</summary>

Launches: 3237, 3567

Items: 25931, 28553

Logs: 16950-16952, 18584-18586

</details>

<a id="p5-2-id-ranges"></a>
<details>
<summary>P5.2: 6 Launch, 12 item, 20 log IDs</summary>

Launches: 3242, 3249, 3287, 3570, 3574, 3599

Items: 26004, 26189, 26191, 26193, 26415-26416, 28592, 28699, 28701, 28703, 28854-28855

Logs: 16986, 17144-17146, 17254-17259, 18604, 18690-18692, 18770-18775

</details>

<a id="p5-3-id-ranges"></a>
<details>
<summary>P5.3: 382 Launch, 1600 item, 1876 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 26587, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26648, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26791, 26794, 26797, 26800, 26803, 26821, 26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 26931-26934, 26943-26944, 26947-26948, 26962, 26965, 26968, 26977, 26980, 26983-26984, 26987-26992, 26995, 26998, 27004, 27007, 27010, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27050, 27052, 27072, 27075, 27077, 27101, 27138, 27159, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27812, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959, 27962, 27971, 27974, 27977, 27980, 27983, 27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046, 28049, 28051, 28053, 28055, 28057, 28059, 28061, 28063, 28065, 28067, 28069, 28071, 28073, 28075, 28078-28081, 28084-28085, 28088-28089, 28092, 28095, 28098, 28101, 28104, 28107-28108, 28111-28116, 28119, 28122, 28125, 28128, 28131, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28154, 28156, 28159, 28162, 28164, 28167, 28170, 28173, 28543, 28546-28547, 28550, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 28920, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28960, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082, 29085, 29088, 29091, 29094, 29097, 29100, 29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29195-29198, 29201-29202, 29205-29206, 29209, 29212, 29215, 29218, 29221, 29224-29225, 29228-29233, 29236, 29239, 29242, 29245, 29248, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29271, 29273, 29276, 29279, 29281, 29284, 29287, 29290, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29700, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822, 29825, 29828, 29831, 29834, 29837, 29840, 29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903, 29906, 29908, 29910, 29912, 29914, 29916, 29918, 29920, 29922, 29924, 29926, 29928, 29930, 29932, 29935-29938, 29941-29942, 29945-29946, 29949, 29952, 29955, 29958, 29961, 29964-29965, 29968-29973, 29976, 29979, 29982, 29985, 29988, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30011, 30013, 30016, 30019, 30021, 30024, 30027, 30030, 30400, 30403-30404, 30407

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17361, 17364-17366, 17368-17375, 17391-17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17501-17505, 17513, 17515-17516, 17519-17524, 17526-17534, 17536, 17538-17577, 17582-17585, 17593-17595, 17600-17618, 17622-17624, 17633-17645, 17654-17656, 17666, 17707-17714, 17733, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 18089-18099, 18108-18112, 18114, 18116-18119, 18121-18130, 18133-18207, 18212-18216, 18224-18226, 18231-18348, 18574-19511, 19737-19746

</details>

<a id="p5-4-id-ranges"></a>
<details>
<summary>P5.4: 382 Launch, 1600 item, 1876 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 26587, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26648, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26791, 26794, 26797, 26800, 26803, 26821, 26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 26931-26934, 26943-26944, 26947-26948, 26962, 26965, 26968, 26977, 26980, 26983-26984, 26987-26992, 26995, 26998, 27004, 27007, 27010, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27050, 27052, 27072, 27075, 27077, 27101, 27138, 27159, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27812, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959, 27962, 27971, 27974, 27977, 27980, 27983, 27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046, 28049, 28051, 28053, 28055, 28057, 28059, 28061, 28063, 28065, 28067, 28069, 28071, 28073, 28075, 28078-28081, 28084-28085, 28088-28089, 28092, 28095, 28098, 28101, 28104, 28107-28108, 28111-28116, 28119, 28122, 28125, 28128, 28131, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28154, 28156, 28159, 28162, 28164, 28167, 28170, 28173, 28543, 28546-28547, 28550, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 28920, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28960, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082, 29085, 29088, 29091, 29094, 29097, 29100, 29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29195-29198, 29201-29202, 29205-29206, 29209, 29212, 29215, 29218, 29221, 29224-29225, 29228-29233, 29236, 29239, 29242, 29245, 29248, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29271, 29273, 29276, 29279, 29281, 29284, 29287, 29290, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29700, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822, 29825, 29828, 29831, 29834, 29837, 29840, 29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903, 29906, 29908, 29910, 29912, 29914, 29916, 29918, 29920, 29922, 29924, 29926, 29928, 29930, 29932, 29935-29938, 29941-29942, 29945-29946, 29949, 29952, 29955, 29958, 29961, 29964-29965, 29968-29973, 29976, 29979, 29982, 29985, 29988, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30011, 30013, 30016, 30019, 30021, 30024, 30027, 30030, 30400, 30403-30404, 30407

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17361, 17364-17366, 17368-17375, 17391-17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17501-17505, 17513, 17515-17516, 17519-17524, 17526-17534, 17536, 17538-17577, 17582-17585, 17593-17595, 17600-17618, 17622-17624, 17633-17645, 17654-17656, 17666, 17707-17714, 17733, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 18089-18099, 18108-18112, 18114, 18116-18119, 18121-18130, 18133-18207, 18212-18216, 18224-18226, 18231-18348, 18574-19511, 19737-19746

</details>

<a id="p5-5-id-ranges"></a>
<details>
<summary>P5.5: 2 Launch, 2 item, 8 log IDs</summary>

Launches: 3289, 3600

Items: 26422, 28858

Logs: 17261-17264, 18776-18779

</details>

<a id="p5-6-id-ranges"></a>
<details>
<summary>P5.6: 4 Launch, 8 item, 24 log IDs</summary>

Launches: 3287, 3565, 3599, 3802

Items: 26415-26416, 28546-28547, 28854-28855, 30403-30404

Logs: 17254-17259, 18577-18582, 18770-18775, 19740-19745

</details>

<a id="p5-7-id-ranges"></a>
<details>
<summary>P5.7: 176 Launch, 1066 item, 260 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461, 3524, 3526, 3567-3600, 3604-3612, 3661-3694, 3698-3706, 3761, 3763

Items: 25931, 25949-25971, 25973, 25975-25976, 25978-25979, 25981, 25983-25984, 25987, 25989, 25991, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26210, 26212, 26214, 26231-26239, 26247-26252, 26256-26261, 26263, 26265-26266, 26268-26273, 26279-26282, 26285, 26287-26308, 26311-26313, 26315-26336, 26340-26368, 26372-26377, 26381-26388, 26392-26397, 26401-26406, 26410-26412, 26415-26416, 26422, 26444-26449, 26499, 26521, 26523, 26525, 26527, 26530, 26532-26533, 26536-26545, 26550, 26554-26555, 26557, 26560-26564, 26573-26575, 26579-26581, 27190, 27199-27209, 27211, 27213, 27215-27216, 27219, 27221, 27226-27242, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27289, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382-27385, 27389-27394, 27398-27403, 27407-27409, 27413-27418, 27422-27427, 27432-27434, 27437, 27445, 27447, 27449, 27451, 27476-27477, 27479, 27482, 27484, 27486, 27488, 27490, 27492, 27494, 27496, 27498-27499, 27502-27535, 27543, 27545, 27547, 27550-27551, 27554-27555, 27558, 27560, 27562, 27564, 27566, 27568, 27570, 27572, 27574, 27577, 27579, 27581, 27583-27584, 27586-27599, 27606-27613, 27618-27623, 27628-27633, 27637-27639, 27642-27643, 27649, 27670-27675, 27685, 27694-27710, 27718, 27722-27729, 27736-27738, 27742-27744, 28291, 28293, 28295, 28297, 28299, 28311, 28313, 28315, 28317, 28319, 28327-28329, 28553-28587, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28625, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706-28739, 28742-28851, 28854-28855, 28858, 28873-28878, 28881-28898, 28903-28917, 29293-29327, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29365, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446-29479, 29482-29591, 29594-29595, 29598, 29613-29618, 29621-29638, 29643-29657, 30148, 30150, 30152, 30154, 30156, 30168, 30170, 30172, 30174, 30176, 30184-30186

Logs: 16950-16952, 16986-16989, 16991, 16993-16998, 17000, 17003, 17005, 17008, 17010, 17013, 17015, 17018, 17020, 17023, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17147, 17183-17184, 17186, 17254-17259, 17261-17264, 17312-17314, 17338, 17750-17752, 17780-17786, 17788-17791, 17793, 17795, 17797, 17799, 17802, 17804, 17806, 17808, 17810, 17812, 17855-17869, 17871-17873, 17875, 17900-17901, 17903, 18016-18021, 18023-18026, 18046-18048, 18068, 18440-18449, 18584-18586, 18604-18614, 18616, 18618, 18620, 18622, 18624, 18626, 18628, 18630, 18632, 18634, 18675-18693, 18707-18708, 18710, 18770-18779, 18790-18792, 18802, 19048-19050, 19068-19078, 19080, 19082, 19084, 19086, 19088, 19090, 19092, 19094, 19096, 19098, 19139-19157, 19171-19172, 19174, 19234-19243, 19254-19256, 19266, 19603-19612

</details>

<a id="p5-8-id-ranges"></a>
<details>
<summary>P5.8: 4 Launch, 4 item, 12 log IDs</summary>

Launches: 3237, 3384, 3567, 3661

Items: 25930, 27188, 28552, 29292

Logs: 16950-16952, 17750-17752, 18584-18586, 19048-19050

</details>

<a id="p6-1-id-ranges"></a>
<details>
<summary>P6.1: 36 Launch, 240 item, 0 log IDs</summary>

Launches: 1142-1144, 1146-1147, 1149-1151, 1154, 1156-1158, 1160-1161, 1163-1165, 1168, 1172-1174, 1176-1177, 1179-1181, 1184, 1186-1188, 1190-1191, 1193-1195, 1198

Items: 9147-9169, 9175-9184, 9189-9211, 9223-9226, 9231-9253, 9259-9268, 9273-9295, 9307-9310, 9332-9354, 9360-9369, 9374-9396, 9408-9411, 9416-9438, 9444-9453, 9458-9480, 9492-9495

Logs: N/A

</details>

<a id="p6-2-id-ranges"></a>
<details>
<summary>P6.2: 68 Launch, 570 item, 0 log IDs</summary>

Launches: 740-742, 744-745, 747, 761-763, 767-773, 777-778, 818-820, 822-823, 825, 839-841, 845-851, 855-856, 1034-1045, 1060-1071, 1145-1148, 1159-1162

Items: 6533-6569, 6575-6647, 6679-6685, 6725-6804, 6819-6845, 6855-6860, 7189-7225, 7231-7303, 7335-7341, 7381-7460, 7475-7501, 7511-7516, 8591-8626, 8669-8704, 9170-9188, 9254-9272

Logs: N/A

</details>

<a id="p6-3-id-ranges"></a>
<details>
<summary>P6.3: 1 Launch, 5 item, 2 log IDs</summary>

Launches: 1145

Items: 9170-9174

Logs: 6122-6123

</details>

<a id="p6-4-id-ranges"></a>
<details>
<summary>P6.4: 2 Launch, 12 item, 0 log IDs</summary>

Launches: 764, 1142

Items: 6805-6810, 9147-9152

Logs: N/A

</details>

<a id="p7-1-id-ranges"></a>
<details>
<summary>P7.1: 1 Launch, 17 item, 8 log IDs</summary>

Launches: 742

Items: 6553-6569

Logs: 4490-4497

</details>

<a id="p7-2-id-ranges"></a>
<details>
<summary>P7.2: 1 Launch, 4 item, 2 log IDs</summary>

Launches: 761

Items: 6725-6728

Logs: 4606-4607

</details>

<a id="p7-3-id-ranges"></a>
<details>
<summary>P7.3: 1 Launch, 52 item, 0 log IDs</summary>

Launches: 745

Items: 6596-6647

Logs: N/A

</details>

<a id="p7-4-id-ranges"></a>
<details>
<summary>P7.4: 1 Launch, 8 item, 9 log IDs</summary>

Launches: 773

Items: 6838-6845

Logs: 4671-4679

</details>

<a id="p7-5-id-ranges"></a>
<details>
<summary>P7.5: 2 Launch, 8 item, 4 log IDs</summary>

Launches: 761, 839

Items: 6725-6728, 7381-7384

Logs: 4606-4607, 5018-5019

</details>

<a id="p8-1-id-ranges"></a>
<details>
<summary>P8.1: 4 Launch, 4 item, 4 log IDs</summary>

Launches: 3252, 3254, 3576, 3578

Items: 26214, 26236, 28709, 28715

Logs: 17156, 17166, 18695, 18697

</details>

<a id="p8-2-id-ranges"></a>
<details>
<summary>P8.2: 6 Launch, 6 item, 6 log IDs</summary>

Launches: 3253, 3255, 3257, 3577, 3579-3580

Items: 26233, 26239, 26249, 28712, 28718, 28721

Logs: 17165, 17167, 17171, 18696, 18698-18699

</details>

<a id="p8-3-id-ranges"></a>
<details>
<summary>P8.3: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3254, 3578

Items: 26236, 28715

Logs: 17166, 18697

</details>

<a id="p8-4-id-ranges"></a>
<details>
<summary>P8.4: 8 Launch, 8 item, 8 log IDs</summary>

Launches: 3258, 3260-3261, 3263, 3581-3584

Items: 26252, 26258, 26261, 26266, 28724, 28727, 28730, 28733

Logs: 17172, 17175-17177, 18700-18703

</details>

<a id="p8-5-id-ranges"></a>
<details>
<summary>P8.5: 2 Launch, 2 item, 10 log IDs</summary>

Launches: 3267, 3587

Items: 26279, 28742

Logs: 17182-17186, 18706-18710

</details>

<a id="p8-6-id-ranges"></a>
<details>
<summary>P8.6: 382 Launch, 1904 item, 1604 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3564-3754, 3801-3803

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233-26239, 26247-26249, 26252, 26256-26261, 26263, 26265-26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26340-26368, 26374-26377, 26383-26384, 26387, 26392-26397, 26401-26406, 26410-26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26550, 26554-26555, 26557, 26562, 26564, 26573-26575, 26581, 26587, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26789-26797, 26800-26803, 26818, 26820-26821, 26824-26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899-26928, 26931-26934, 26943-26944, 26947, 26958, 26960, 26962-26968, 26975-26980, 26983-26984, 26987-26992, 26995, 26998, 27004, 27007, 27010, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27052, 27069-27070, 27072, 27075, 27077, 27098-27099, 27101, 27138, 27159, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391-27394, 27398-27403, 27409, 27413-27418, 27422-27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27543, 27545, 27547, 27550-27551, 27554-27555, 27558, 27560, 27562, 27564, 27566, 27568, 27570, 27572, 27574, 27577, 27579, 27581, 27583-27584, 27586-27593, 27596-27599, 27608-27609, 27612, 27618-27623, 27628-27633, 27637-27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27718, 27722-27724, 27727, 27729, 27736-27738, 27744, 27747, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959-27962, 27969-27974, 27977-27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046-28075, 28078-28081, 28084-28085, 28088, 28090-28104, 28107-28108, 28111-28116, 28119, 28122, 28125, 28128, 28131, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28156-28159, 28162, 28164-28167, 28170, 28173, 28543, 28546-28547, 28550, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712-28721, 28724-28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793-28822, 28825-28828, 28831-28832, 28835, 28837-28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28903-28906, 28909, 28911-28914, 28917, 28920, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082-29091, 29094-29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163-29192, 29195-29198, 29201-29202, 29205, 29207-29221, 29224-29225, 29228-29233, 29236, 29239, 29242, 29245, 29248, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29273-29276, 29279, 29281-29284, 29287, 29290, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452-29461, 29464-29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533-29562, 29565-29568, 29571-29572, 29575, 29577-29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29643-29646, 29649, 29651-29654, 29657, 29660, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822-29831, 29834-29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903-29932, 29935-29938, 29941-29942, 29945, 29947-29961, 29964-29965, 29968-29973, 29976, 29979, 29982, 29985, 29988, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30013-30016, 30019, 30021-30024, 30027, 30030, 30400, 30403-30404, 30407

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16986-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165, 17172, 17179-17180, 17186-17188, 17190-17205, 17207-17220, 17237-17240, 17242-17244, 17254-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17336, 17338, 17344-17345, 17352-17359, 17361, 17364-17366, 17368-17375, 17391-17398, 17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17504, 17516, 17519, 17524, 17526-17534, 17536, 17538-17559, 17574-17577, 17582-17584, 17602-17618, 17622-17624, 17633-17643, 17645, 17655-17656, 17707-17714, 17733, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17780-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879, 17885, 17895, 17898, 17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17994-17997, 18002-18004, 18016-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18068, 18071-18072, 18077-18085, 18089-18099, 18108-18112, 18114, 18116-18117, 18119, 18121-18130, 18133-18207, 18212-18216, 18224-18225, 18233, 18237-18238, 18243-18275, 18290-18296, 18303-18333, 18335, 18337-18338, 18340-18348, 18574-18602, 18604-18696, 18700, 18704-18705, 18710-18742, 18757-18763, 18770-18800, 18802, 18804-18805, 18807-18834, 18836-18928, 18932, 18936-18937, 18942-18974, 18989-18995, 19002-19032, 19034, 19036-19037, 19039-19066, 19068-19160, 19164, 19168-19169, 19174-19206, 19221-19227, 19234-19264, 19266, 19268-19269, 19271-19298, 19300-19392, 19396, 19400-19401, 19406-19438, 19453-19459, 19466-19496, 19498, 19500-19501, 19503-19511, 19737-19746

</details>

<a id="p8-7-id-ranges"></a>
<details>
<summary>P8.7: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3265, 3586

Items: 26273, 28739

Logs: 17180, 18705

</details>

<a id="p8-8-id-ranges"></a>
<details>
<summary>P8.8: 96 Launch, 288 item, 0 log IDs</summary>

Launches: 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267, 3331-3332, 3334-3338, 3340-3342, 3344-3345, 3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3479-3481, 3483-3491, 3576-3587, 3623-3634, 3670-3681, 3717-3728

Items: 26210, 26212, 26214, 26231-26239, 26247-26252, 26256-26261, 26263, 26265-26266, 26268-26273, 26277-26279, 26780-26785, 26789-26803, 26818, 26820-26821, 26824-26829, 26835-26840, 27383-27385, 27389-27394, 27398-27403, 27407-27409, 27413-27418, 27422-27427, 27432-27437, 27954-27962, 27969-27995, 28707-28742, 29077-29112, 29447-29482, 29817-29852

Logs: N/A

</details>

<a id="p8-9-id-ranges"></a>
<details>
<summary>P8.9: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="p9-1-id-ranges"></a>
<details>
<summary>P9.1: 1 Launch, 3 item, 0 log IDs</summary>

Launches: 777

Items: 6855-6857

Logs: N/A

</details>

<a id="p9-2-id-ranges"></a>
<details>
<summary>P9.2: 4 Launch, 12 item, 0 log IDs</summary>

Launches: 774, 776, 1093, 1095

Items: 6846-6848, 6852-6854, 8768-8770, 8774-8776

Logs: N/A

</details>

<a id="p9-3-id-ranges"></a>
<details>
<summary>P9.3: 1 Launch, 3 item, 0 log IDs</summary>

Launches: 775

Items: 6849-6851

Logs: N/A

</details>

<a id="p9-4-id-ranges"></a>
<details>
<summary>P9.4: 5 Launch, 15 item, 0 log IDs</summary>

Launches: 774-776, 1093, 1095

Items: 6846-6854, 8768-8770, 8774-8776

Logs: N/A

</details>

<a id="p9-5-id-ranges"></a>
<details>
<summary>P9.5: 1 Launch, 3 item, 0 log IDs</summary>

Launches: 774

Items: 6846-6848

Logs: N/A

</details>

<a id="p10-1-id-ranges"></a>
<details>
<summary>P10.1: 6 Launch, 8 item, 20 log IDs</summary>

Launches: 3564-3566, 3801-3803

Items: 28543, 28546-28547, 28550, 30400, 30403-30404, 30407

Logs: 18574-18583, 19737-19746

</details>

<a id="p10-2-id-ranges"></a>
<details>
<summary>P10.2: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 3296, 3605

Items: 26449, 28878

Logs: 17281, 18789

</details>

<a id="p10-3-id-ranges"></a>
<details>
<summary>P10.3: 94 Launch, 398 item, 464 log IDs</summary>

Launches: 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3661-3707

Items: 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660

Logs: 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 19048-19279

</details>

<a id="p10-4-id-ranges"></a>
<details>
<summary>P10.4: 34 Launch, 60 item, 66 log IDs</summary>

Launches: 3390, 3405, 3407-3408, 3413, 3415, 3419, 3424, 3428, 3430-3431, 3433-3434, 3436, 3453, 3455, 3459, 3664, 3672-3674, 3677-3678, 3681, 3684, 3687-3692, 3702-3703, 3705

Items: 27248, 27394, 27400, 27403, 27418, 27424, 27437, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27613, 27620, 27623, 27630, 27633, 27639, 27716, 27724, 27738, 29330, 29455, 29458, 29461, 29470, 29473, 29482, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29576, 29579, 29582, 29585, 29588, 29591, 29641, 29646, 29654

Logs: 17779, 17880, 17882-17883, 17888, 17894, 17899-17902, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17993, 18005, 18008-18009, 18012-18013, 18015, 18067, 18070, 18075, 19067, 19161-19163, 19166-19167, 19170-19173, 19207-19220, 19228-19233, 19265, 19267, 19270

</details>

<a id="p10-5-id-ranges"></a>
<details>
<summary>P10.5: 94 Launch, 398 item, 464 log IDs</summary>

Launches: 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3661-3707

Items: 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660

Logs: 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 19048-19279

</details>

<a id="p10-6-id-ranges"></a>
<details>
<summary>P10.6: 376 Launch, 1592 item, 1856 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3567-3754

Items: 25931, 25951-25952, 25955-25956, 25959-25960, 25963-25964, 25968-25969, 25973, 25975, 25979, 25981, 25987, 25989, 26002, 26004, 26007, 26009, 26013, 26016, 26020, 26022, 26024, 26026, 26028, 26030, 26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26127, 26131, 26135, 26139, 26143, 26147, 26150, 26154, 26158, 26162, 26165, 26169, 26172, 26176, 26180, 26189, 26191, 26193, 26196, 26214, 26233, 26236, 26239, 26249, 26252, 26258, 26261, 26266, 26270, 26273, 26279, 26282, 26285, 26289-26290, 26292-26293, 26295-26296, 26298-26299, 26301-26302, 26304-26305, 26307-26308, 26312-26313, 26316-26317, 26319-26320, 26322-26323, 26325-26326, 26328-26329, 26331-26332, 26334, 26336, 26342, 26344, 26346, 26348, 26350, 26352, 26354, 26356, 26358, 26360, 26362, 26364, 26366, 26368, 26374-26377, 26383-26384, 26387-26388, 26394, 26397, 26403, 26406, 26412, 26415-26416, 26422-26427, 26431, 26436, 26440, 26446, 26449, 26499, 26525, 26527, 26533, 26536, 26539-26540, 26543-26544, 26548, 26550, 26557, 26562, 26564, 26575, 26581, 26587, 26596, 26602-26603, 26606-26607, 26610-26611, 26614-26615, 26631-26632, 26635-26636, 26639-26640, 26643-26644, 26648, 26650, 26656, 26658, 26660, 26662, 26664, 26666, 26668, 26670, 26672, 26674, 26680-26692, 26695-26696, 26698-26732, 26738, 26740, 26742, 26745, 26748, 26751, 26753, 26755, 26757, 26759, 26761, 26763, 26765, 26767, 26769, 26772, 26774, 26776, 26779, 26782, 26785, 26791, 26794, 26797, 26800, 26803, 26821, 26826, 26829, 26837, 26840, 26846-26847, 26850-26851, 26853-26854, 26856, 26859, 26861, 26863, 26867-26868, 26870-26871, 26873-26874, 26876-26877, 26879-26880, 26882-26883, 26885-26886, 26888-26889, 26891-26892, 26894-26895, 26897, 26899, 26902, 26904, 26906, 26908, 26910, 26912, 26914, 26916, 26918, 26920, 26922, 26924, 26926, 26928, 26931-26934, 26943-26944, 26947-26948, 26962, 26965, 26968, 26977, 26980, 26983-26984, 26987-26992, 26995, 26998, 27004, 27007, 27010, 27030, 27033-27034, 27037-27038, 27041-27042, 27045-27046, 27050, 27052, 27072, 27075, 27077, 27101, 27138, 27159, 27190, 27201-27202, 27205-27206, 27209, 27211, 27216, 27219, 27228-27229, 27232-27233, 27236-27237, 27240-27241, 27248, 27250, 27253, 27255, 27257, 27259, 27261, 27265, 27267, 27270, 27272, 27274, 27277-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27338, 27340, 27342, 27344, 27346, 27348, 27350, 27352, 27354, 27356, 27358, 27360, 27362, 27364, 27366, 27372, 27374, 27376, 27382, 27385, 27391, 27394, 27400, 27403, 27409, 27415, 27418, 27424, 27427, 27434, 27437, 27449, 27451, 27479, 27482, 27486, 27488, 27492, 27494, 27498-27499, 27503-27504, 27506-27507, 27509-27510, 27512-27513, 27515-27516, 27518-27519, 27521-27522, 27524-27525, 27527-27528, 27530-27531, 27533, 27535, 27547, 27551, 27555, 27560, 27564, 27568, 27572, 27577, 27581, 27584, 27587, 27589, 27591, 27593, 27596-27599, 27608-27609, 27612-27613, 27620, 27623, 27630, 27633, 27639, 27642-27643, 27649-27654, 27657, 27663, 27666, 27672, 27675, 27685, 27696-27697, 27700-27701, 27704-27705, 27708-27709, 27716, 27718, 27724, 27727, 27729, 27738, 27744, 27747, 27753, 27756-27757, 27760-27761, 27764-27765, 27768-27769, 27790-27791, 27794-27795, 27800, 27802, 27807-27808, 27812, 27814, 27820, 27822, 27824, 27826, 27828, 27830, 27832, 27834, 27836, 27838, 27846-27895, 27898, 27900, 27902, 27904, 27906, 27908, 27910, 27912, 27914, 27916, 27918, 27920, 27922, 27924, 27926, 27935, 27937, 27939, 27942, 27956, 27959, 27962, 27971, 27974, 27977, 27980, 27983, 27986, 27989, 27992, 27995, 27998-27999, 28002-28003, 28005-28006, 28008-28009, 28011-28012, 28014-28015, 28017-28018, 28020-28021, 28023-28024, 28026-28027, 28029-28030, 28032-28033, 28035-28036, 28038-28039, 28041-28042, 28044, 28046, 28049, 28051, 28053, 28055, 28057, 28059, 28061, 28063, 28065, 28067, 28069, 28071, 28073, 28075, 28078-28081, 28084-28085, 28088-28089, 28092, 28095, 28098, 28101, 28104, 28107-28108, 28111-28116, 28119, 28122, 28125, 28128, 28131, 28134, 28137-28138, 28141-28142, 28145-28146, 28149-28150, 28154, 28156, 28159, 28162, 28164, 28167, 28170, 28173, 28553, 28556-28557, 28560-28561, 28564-28565, 28568-28569, 28573-28574, 28577-28578, 28581-28582, 28585-28586, 28590, 28592, 28595, 28597, 28599, 28601, 28603, 28605, 28607, 28609, 28611, 28613, 28616-28665, 28668, 28670, 28672, 28674, 28676, 28678, 28680, 28682, 28684, 28686, 28688, 28690, 28692, 28694, 28696, 28699, 28701, 28703, 28706, 28709, 28712, 28715, 28718, 28721, 28724, 28727, 28730, 28733, 28736, 28739, 28742, 28745-28746, 28749-28750, 28752-28753, 28755-28756, 28758-28759, 28761-28762, 28764-28765, 28767-28768, 28770-28771, 28773-28774, 28776-28777, 28779-28780, 28782-28783, 28785-28786, 28788-28789, 28791, 28793, 28796, 28798, 28800, 28802, 28804, 28806, 28808, 28810, 28812, 28814, 28816, 28818, 28820, 28822, 28825-28828, 28831-28832, 28835-28836, 28839, 28842, 28845, 28848, 28851, 28854-28855, 28858-28863, 28866, 28869, 28872, 28875, 28878, 28881, 28884-28885, 28888-28889, 28892-28893, 28896-28897, 28901, 28903, 28906, 28909, 28911, 28914, 28917, 28920, 28923, 28926-28927, 28930-28931, 28934-28935, 28938-28939, 28943-28944, 28947-28948, 28951-28952, 28955-28956, 28960, 28962, 28965, 28967, 28969, 28971, 28973, 28975, 28977, 28979, 28981, 28983, 28986-29035, 29038, 29040, 29042, 29044, 29046, 29048, 29050, 29052, 29054, 29056, 29058, 29060, 29062, 29064, 29066, 29069, 29071, 29073, 29076, 29079, 29082, 29085, 29088, 29091, 29094, 29097, 29100, 29103, 29106, 29109, 29112, 29115-29116, 29119-29120, 29122-29123, 29125-29126, 29128-29129, 29131-29132, 29134-29135, 29137-29138, 29140-29141, 29143-29144, 29146-29147, 29149-29150, 29152-29153, 29155-29156, 29158-29159, 29161, 29163, 29166, 29168, 29170, 29172, 29174, 29176, 29178, 29180, 29182, 29184, 29186, 29188, 29190, 29192, 29195-29198, 29201-29202, 29205-29206, 29209, 29212, 29215, 29218, 29221, 29224-29225, 29228-29233, 29236, 29239, 29242, 29245, 29248, 29251, 29254-29255, 29258-29259, 29262-29263, 29266-29267, 29271, 29273, 29276, 29279, 29281, 29284, 29287, 29290, 29293, 29296-29297, 29300-29301, 29304-29305, 29308-29309, 29313-29314, 29317-29318, 29321-29322, 29325-29326, 29330, 29332, 29335, 29337, 29339, 29341, 29343, 29345, 29347, 29349, 29351, 29353, 29356-29405, 29408, 29410, 29412, 29414, 29416, 29418, 29420, 29422, 29424, 29426, 29428, 29430, 29432, 29434, 29436, 29439, 29441, 29443, 29446, 29449, 29452, 29455, 29458, 29461, 29464, 29467, 29470, 29473, 29476, 29479, 29482, 29485-29486, 29489-29490, 29492-29493, 29495-29496, 29498-29499, 29501-29502, 29504-29505, 29507-29508, 29510-29511, 29513-29514, 29516-29517, 29519-29520, 29522-29523, 29525-29526, 29528-29529, 29531, 29533, 29536, 29538, 29540, 29542, 29544, 29546, 29548, 29550, 29552, 29554, 29556, 29558, 29560, 29562, 29565-29568, 29571-29572, 29575-29576, 29579, 29582, 29585, 29588, 29591, 29594-29595, 29598-29603, 29606, 29609, 29612, 29615, 29618, 29621, 29624-29625, 29628-29629, 29632-29633, 29636-29637, 29641, 29643, 29646, 29649, 29651, 29654, 29657, 29660, 29663, 29666-29667, 29670-29671, 29674-29675, 29678-29679, 29683-29684, 29687-29688, 29691-29692, 29695-29696, 29700, 29702, 29705, 29707, 29709, 29711, 29713, 29715, 29717, 29719, 29721, 29723, 29726-29775, 29778, 29780, 29782, 29784, 29786, 29788, 29790, 29792, 29794, 29796, 29798, 29800, 29802, 29804, 29806, 29809, 29811, 29813, 29816, 29819, 29822, 29825, 29828, 29831, 29834, 29837, 29840, 29843, 29846, 29849, 29852, 29855-29856, 29859-29860, 29862-29863, 29865-29866, 29868-29869, 29871-29872, 29874-29875, 29877-29878, 29880-29881, 29883-29884, 29886-29887, 29889-29890, 29892-29893, 29895-29896, 29898-29899, 29901, 29903, 29906, 29908, 29910, 29912, 29914, 29916, 29918, 29920, 29922, 29924, 29926, 29928, 29930, 29932, 29935-29938, 29941-29942, 29945-29946, 29949, 29952, 29955, 29958, 29961, 29964-29965, 29968-29973, 29976, 29979, 29982, 29985, 29988, 29991, 29994-29995, 29998-29999, 30002-30003, 30006-30007, 30011, 30013, 30016, 30019, 30021, 30024, 30027, 30030

Logs: 16950-16952, 16961-16972, 16974-16975, 16977, 16980, 16985-16989, 16991, 16993-17001, 17003-17005, 17007-17010, 17012-17015, 17017-17020, 17022-17024, 17026, 17028-17029, 17031-17032, 17034-17035, 17037-17068, 17098, 17101, 17104, 17107, 17110, 17113, 17116, 17118, 17121, 17124, 17126, 17129, 17132, 17134, 17137, 17144-17148, 17156, 17165-17167, 17171-17172, 17175-17177, 17179-17180, 17182-17188, 17190-17205, 17207-17220, 17222-17235, 17237-17240, 17242-17245, 17247-17248, 17250-17251, 17253-17259, 17261-17270, 17276-17277, 17280-17281, 17312-17314, 17326, 17328, 17330, 17332-17338, 17341, 17344-17345, 17350, 17352-17359, 17361, 17364-17366, 17368-17375, 17391-17400, 17402-17411, 17413-17437, 17439-17473, 17475-17479, 17481-17497, 17501-17505, 17513, 17515-17516, 17519-17524, 17526-17534, 17536, 17538-17577, 17582-17585, 17593-17595, 17600-17618, 17622-17624, 17633-17645, 17654-17656, 17666, 17707-17714, 17733, 17750-17752, 17757-17762, 17764, 17766, 17770-17777, 17779-17786, 17788-17799, 17801-17848, 17850-17853, 17855-17869, 17871-17873, 17875-17877, 17879-17880, 17882-17883, 17885, 17887-17888, 17894-17895, 17898-17903, 17909, 17911, 17928, 17931, 17933, 17935-17936, 17939, 17941-17942, 17944-17965, 17970, 17972, 17974, 17976, 17978, 17980, 17983-17984, 17986, 17989-17997, 18002-18005, 18008-18009, 18012-18013, 18015-18021, 18023-18032, 18034-18035, 18037-18038, 18046-18048, 18058-18065, 18067-18068, 18070-18072, 18075, 18077-18085, 18089-18099, 18108-18112, 18114, 18116-18119, 18121-18130, 18133-18207, 18212-18216, 18224-18226, 18231-18348, 18584-19511

</details>

<a id="p10-7-id-ranges"></a>
<details>
<summary>P10.7: 376 Launch, 2960 item, 0 log IDs</summary>

Launches: 3237, 3239-3240, 3242-3243, 3246, 3248-3250, 3252-3255, 3257-3258, 3260-3261, 3263-3265, 3267-3268, 3270, 3273, 3275, 3277-3278, 3280-3281, 3283-3284, 3286-3287, 3289-3290, 3292-3293, 3295-3296, 3298, 3300-3301, 3303-3304, 3307, 3309, 3311, 3314, 3316, 3319-3320, 3322, 3324, 3327, 3329-3332, 3334-3338, 3340-3342, 3344-3345, 3347-3348, 3350-3351, 3353-3354, 3356-3358, 3360-3365, 3367-3369, 3371-3373, 3375-3376, 3379, 3381-3382, 3384-3385, 3388, 3390-3391, 3393, 3397, 3399, 3401-3402, 3404-3405, 3407-3408, 3410, 3412-3413, 3415-3416, 3418-3419, 3421-3422, 3424-3425, 3427-3428, 3430-3431, 3433-3434, 3436-3437, 3439-3440, 3442-3443, 3445-3446, 3449, 3451, 3453, 3455-3456, 3459, 3461-3462, 3464-3465, 3467, 3469, 3471, 3473-3474, 3476-3477, 3479-3481, 3483-3517, 3567-3754

Items: 25929-25931, 25949-25971, 25973, 25975-25976, 25978-25979, 25981, 25983-25984, 25987, 25989, 25991, 26000-26009, 26012-26013, 26015-26016, 26019-26030, 26033-26035, 26037-26038, 26041-26042, 26045, 26047, 26049, 26052-26053, 26055, 26057, 26060-26061, 26064-26065, 26068-26069, 26072-26103, 26124, 26126-26127, 26130-26131, 26134-26135, 26138-26139, 26142-26143, 26145, 26147, 26149-26150, 26153-26154, 26157-26158, 26161-26162, 26164-26165, 26168-26169, 26171-26172, 26175-26176, 26178, 26180, 26187-26196, 26210, 26212, 26214, 26231-26239, 26247-26252, 26256-26261, 26263, 26265-26266, 26268-26273, 26277-26282, 26285, 26287-26308, 26311-26313, 26315-26336, 26340-26368, 26372-26377, 26381-26388, 26392-26397, 26401-26406, 26410-26416, 26420-26429, 26431, 26434-26438, 26440, 26444-26449, 26497-26499, 26521, 26523, 26525, 26527, 26530, 26532-26533, 26536-26550, 26554-26555, 26557, 26560-26564, 26573-26575, 26579-26581, 26585-26587, 26594-26596, 26600-26616, 26628-26629, 26631-26650, 26654-26674, 26678-26692, 26695-26696, 26698-26732, 26736-26743, 26745, 26747-26748, 26750-26785, 26789-26803, 26818, 26820-26821, 26824-26829, 26835-26840, 26844-26856, 26859-26861, 26863, 26866-26934, 26941-26948, 26958, 26960, 26962-26968, 26975-26998, 27002-27010, 27028-27052, 27069-27070, 27072-27077, 27098-27099, 27101, 27135-27136, 27138, 27156-27157, 27159, 27186, 27188, 27190, 27199-27209, 27211, 27213, 27215-27216, 27219, 27221, 27226-27242, 27246-27261, 27264-27267, 27269-27278, 27281-27282, 27284-27322, 27324, 27326-27327, 27329-27332, 27336-27366, 27370-27376, 27380-27385, 27389-27394, 27398-27403, 27407-27409, 27413-27418, 27422-27427, 27432-27437, 27445, 27447, 27449, 27451, 27476-27477, 27479, 27482, 27484, 27486, 27488, 27490, 27492, 27494, 27496, 27498-27499, 27502-27535, 27543, 27545, 27547, 27550-27551, 27554-27555, 27558, 27560, 27562, 27564, 27566, 27568, 27570, 27572, 27574, 27577, 27579, 27581, 27583-27584, 27586-27599, 27606-27613, 27618-27623, 27628-27633, 27637-27643, 27647-27657, 27661-27666, 27670-27675, 27683-27685, 27694-27710, 27714-27718, 27722-27729, 27736-27738, 27742-27747, 27751-27769, 27772, 27788-27795, 27798-27800, 27802, 27804, 27806-27814, 27818-27838, 27844-27926, 27933-27942, 27954-27962, 27969-28173, 28551-30030

Logs: N/A

</details>

<a id="p10-8-id-ranges"></a>
<details>
<summary>P10.8: 26 Launch, 102 item, 54 log IDs</summary>

Launches: 3390, 3410, 3416, 3424, 3428, 3430-3431, 3433-3434, 3436, 3439, 3453, 3459, 3664, 3675, 3679, 3684, 3687-3692, 3694, 3702, 3705

Items: 27247-27248, 27408-27409, 27426-27427, 27545, 27547, 27550-27551, 27554-27555, 27562, 27564, 27566, 27568, 27570, 27572, 27574, 27577, 27579, 27581, 27583-27584, 27586-27593, 27611, 27613, 27619-27620, 27622-27623, 27629-27630, 27632-27633, 27638-27639, 27648-27649, 27654, 27715-27716, 27737-27738, 29329-29330, 29463-29464, 29475-29476, 29535-29540, 29543-29562, 29574, 29576, 29578-29579, 29581-29582, 29584-29585, 29587-29588, 29590-29591, 29597-29598, 29603, 29640-29641, 29653-29654

Logs: 17779, 17885, 17895, 17970, 17972, 17974, 17978, 17980, 17983-17984, 17986, 17989-17993, 18005, 18008-18009, 18012-18013, 18015, 18023-18024, 18031, 18067, 18075, 19067, 19164, 19168, 19207-19209, 19211-19220, 19228-19233, 19240-19241, 19248, 19265, 19270

</details>

<a id="p10-9-id-ranges"></a>
<details>
<summary>P10.9: 2 Launch, 4 item, 4 log IDs</summary>

Launches: 3421, 3682

Items: 27449, 27451, 29485-29486

Logs: 17909, 17911, 19175-19176

</details>

<a id="p10-10-id-ranges"></a>
<details>
<summary>P10.10: 18 Launch, 18 item, 32 log IDs</summary>

Launches: 3384, 3402, 3405, 3410, 3412-3413, 3419, 3421, 3453, 3661, 3670, 3672, 3675-3677, 3681-3682, 3702

Items: 27188, 27384, 27393, 27408, 27414, 27417, 27436, 27447, 27715, 29292, 29448, 29454, 29463, 29466, 29469, 29481, 29484, 29640

Logs: 17750-17752, 17877, 17880, 17885, 17887-17888, 17899-17903, 17909, 17911, 18067, 19048-19050, 19159, 19161, 19164-19166, 19170-19176, 19265

</details>

<a id="p10-11-id-ranges"></a>
<details>
<summary>P10.11: 8 Launch, 8 item, 16 log IDs</summary>

Launches: 3402, 3405, 3412, 3419, 3670, 3672, 3676, 3681

Items: 27384, 27393, 27414, 27436, 29448, 29454, 29466, 29481

Logs: 17877, 17880, 17887, 17899-17903, 19159, 19161, 19165, 19170-19174

</details>

<a id="v1-id-ranges"></a>
<details>
<summary>V1: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="v2-id-ranges"></a>
<details>
<summary>V2: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="v3-id-ranges"></a>
<details>
<summary>V3: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="v4-id-ranges"></a>
<details>
<summary>V4: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="v5-id-ranges"></a>
<details>
<summary>V5: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="v6-id-ranges"></a>
<details>
<summary>V6: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="v7-id-ranges"></a>
<details>
<summary>V7: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

<a id="v8-id-ranges"></a>
<details>
<summary>V8: 0 Launch, 0 item, 0 log IDs</summary>

Launches: N/A

Items: N/A

Logs: N/A

</details>

## Waivers
Owner Decisions 1-18 and recorded clarifications apply only within their explicit scopes; Decision15's title-only exception and Decisions16-18 are detailed below.

Decision15, received 2026-11-01: F14 `back\slash` failure title only; retain the exact complete fail-closed omission. All other title/escaping checks remain strict.

> 保留安全省略，记录这一项例外（推荐）

The following supplied Decisions 1-14 are quoted from the original final-runtime documents. Decision15's product-doc append and docs-only binding are separate follow-up evidence.

Decision16, received 2026-11-01: only bounded, independently reviewed test/CI diagnostics are authorized; Helm, runtime budgets and existing assertions remain protected. V6 still needs an exact new-head diff audit, and G10 is not waived.

> Question: 远端 CI 的未改动 1.3.1 基线出现 SIGINT/Spool 和超时失败。是否允许把这些既有 CI 稳定性问题纳入独立排查，必要时另作修复提交？保持全部断言，不推受保护分支、不合并或发布。
> Owner answer: 允许独立排查与必要修复（推荐）

Decision17: the owner explicitly approved an exact-byte F04 flat replay in new independent QA Launches solely for Console rendering. Original runtime logs and topology remain unchanged. S12 source/replay mappings and active Console screenshots are labelled renderer-only; this is not a replacement runtime or wire-contract run.

> Owner answer: 允许补充平铺回放（推荐）

Decision18: [pinned protocol review](assets/wp5-ci-final-20261101/parameter-order-protocol-review.json) records Set persistence but List request/response DTOs; no unordered API contract is inferred. Only C10/F14 GET parameter order uses a complete multiset, retaining duplicate multiplicity and raw FAILs; ordered POST bytes and every other field remain strict.

> Owner answer: 接受这项窄范围调整， 继续

> # Ledger presentation: owner decisions and implementation checkpoint
>
> Date: 2026-10-31. These decisions supplement, but do not rewrite, the two
> original design documents committed unchanged in C0.
>
> ## Confirmed baselines
>
> - SDK 1.x: `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`.
> - SDK 2.x: `79e5e9cfde4be6d29ca2293e549460c6c71fe87a`.
> - Frozen corrected Gem SHA-256:
>   `c6bf0aae1fa9bd1e356fa116934cebebd582353afd381ec4b16bf9fc67ca62f3`.
>   It was originally built from an uncommitted tree based on `e7dae2b`.
>   Reading the actual Gem archive and its original manifest confirmed that all
>   203 packaged files match commit `79e5e9c` byte for byte; `e7dae2b` differs
>   in five files and is not the corrected baseline. This is a source-content
>   attribution, not a claim that the artifact was built after that commit.
> - The subsequently published `v2.0.0` remains untouched. Its release-document
>   updates are not substituted for the explicitly requested frozen baseline.
>
> ## Owner-approved adjustments
>
> ### Independent SDK and Chart versions
>
> Owner instruction: "移除这个限制" in response to the finding that 1.x release
> tooling required the Gem and Helm versions to match.
>
> SDK 1.3.2 and subsequent releases may use unchanged Chart 1.3.1. The Gem must
> still match its release tag. Chart filenames, archive metadata and manifest
> `chartVersion` must match the separately committed Chart version. Historical
> 1.x manifests through 1.3.1 retain their original identity and title so existing
> assets still verify unchanged. This does not authorize publication, ancestry
> changes, CI workflow changes or a Chart update.
>
> ### Trusted table line breaks (P2.3)
>
> Owner approval: "允许客户端生成的 <br>（推荐）"
>
> The raw-angle-bracket property permits only the client's generated `<br>`
> line-break token. All angle brackets originating in user data remain escaped.
> This is not permission to pass through arbitrary user HTML.
>
> ### Rich examples take precedence over strict word order (P10.6)
>
> Owner approval: "按 Rich 样例呈现，调整 P10.6 允许这些差异"
>
> The explicit P10 rich examples may move an attachment's kind before its name,
> replace the passed-assertion label with a PASS pill, and use the specified HTTP
> status/title presentation. P10.6 must allow these specified decorative changes,
> rather than require their plain labels and word order. Evidence values must not
> be lost or changed. ERROR first-line equality, byte budgets, channel separation
> and the closed HTML/style vocabulary remain mandatory. This is not a blanket
> waiver for other missing or reordered evidence.
>
> ### Temporary Chart archives in existing tests
>
> Owner approval: "允许测试中的临时打包（推荐）"
>
> Existing isolated regression tests may create and remove temporary Chart
> archives. No deliverable Chart, deployment, upload, release or tag is authorized.
>
> ### Decision 4: Cucumber 9 compound arguments
>
> Question: 已实测 Cucumber 9 的解析器拒绝同一步同时包含 DocString 和 DataTable，而 F02/F03 要求两条发布线都跑这类语法。是否允许 1.x 将“原生复合语法”标为 N/A，并用分开的参数步骤验证同样的表格、描述和 Outline 展示；2.x 仍严格验收原生复合语法？
>
> Owner answer: 允许，保留解析失败证据（推荐）
>
> The Cucumber 9 native compound-syntax check alone is N/A. Retain the parser
> failure and verify both argument types with separate steps; this does not waive
> presentation, ownership, description or Outline checks. SDK 2.x retains native
> compound-argument validation.
>
> ### Decision 5: Preserve native global-hook topology
>
> Question: 还有一处验收口径需要确认：现有原生 BeforeAll/AfterAll 并不生成独立 Hook Item（2.x 的日志归属 Launch，1.x 的 BeforeAll 甚至早于 formatter 创建）。为遵守“不改变节点拓扑”，是否保留这些行为，将全局钩子的 Item 名称检查标为 N/A，同时继续验证日志/异常与退出闭合，并用单测覆盖已有 class-hook 名称映射？
>
> Owner answer: 保留基线行为并记录 N/A（推荐）
>
> Only native global-hook Item-name checks are N/A. Do not create synthetic Hook
> Items or change Launch ownership. Continue validating logs, exceptions and
> finalization, and unit-test existing class-hook name mappings. The full Q/A for
> Decisions 4 and 5 is also retained in both authoritative design documents.
>
> ### Decision 6: Forward target synchronization on the 2.x feature branch
>
> Question: 为消除 2.x 文档冲突，是否允许仅将 PR 目标分支 codex/cucumber-12 同步合并进功能分支，并保留目标分支已发布的 2.0.0 CHANGELOG 内容？不合并 PR、不推受保护分支、不强推、不发布。
>
> Owner answer: 允许仅同步目标分支，并保留正式发布历史（推荐）
>
> This is an operational authorization only. Master may merge the PR target
> `codex/cucumber-12` forward into the 2.x feature branch after C8 handoff, retaining
> the target's officially published 2.0.0 CHANGELOG history. C8 itself preserves the
> frozen historical body; the separately audited synchronization may retain the
> legitimate target release prose and date. RSpec checks candidate versions and
> contracts rather than pinning a historical-body digest in synthetic PR checkouts.
>
> This does not authorize merging the PR, pushing protected branches, force-pushing,
> publication, or a target synchronization on 1.x. It grants no code, topology,
> ownership, presentation, or other acceptance waiver. Master owns the authorized
> 2.x synchronization and records the resulting feature HEAD for final validation.
>
> ### Decision 7: Correct contradictory golden examples
>
> Question: 独立 QA 发现验收金样与明确规则有三处冲突：P1 标题下划线未转义；P8 金样遗漏了 F11a 要求的 4 个请求 Header；同一 Hash 报文实际输入长度为 55/51 B，而金样写成 212/148 B。是否按明确规则修正金样，继续逐字节比较，并完整保留 P1 的 62 帧原始基线栈，不放宽帧数要求？
>
> Owner answer: 按规则修正金样，保留严格逐字节验收（推荐）
>
> Golden examples follow the explicit escaping, header and input-byte rules.
> Keep byte-for-byte comparison and all 62 original baseline stack frames.
>
> ### Decision 8: Six legacy NUL-preview persistence exceptions
>
> Question: 独立 QA 确认：1.x 旧基线有 6 个含 NUL 字符的文本附件未落库，新版则完整保存，且上传字节、MIME 和归属均不变。是否允许仅这 6 项改用旧版实际提交的报文作对照，并要求新版完整读回；其余 G2/G3 仍严格比较 API 基线？另有一条原生 NUL 用户日志在新旧版均未落库，将明确列为既有限制，暂不改变其语义。
>
> Owner answer: 允许这 6 项基线例外，记录既有限制（推荐）
>
> Only 1.x F08's five text attachments and F09's `nul-repro.txt` use the
> baseline's submitted per-Item log counts/levels and attachment counts, MIME
> types and SHA-256 digests as their comparison source. Preserve the baseline's
> missing-persistence evidence; the candidate must fully read back all six files
> and their logs. All other G2/G3 comparisons retain the persisted API baseline.
> The separately observed native NUL user-log loss is an unchanged 1.x limitation,
> not a newly passing case. No payload semantics or attachment bytes are changed
> by this decision.
>
> ## Historical C0 Checkpoint
>
> C0 is committed on both isolated feature branches:
> `codex/presentation-ledger-2.0.1` (`9ea7f1f`) and
> `maintenance/presentation-ledger-1.3.2` (`eb17e54`).
>
> The owner subsequently authorized the independent-version patch as a separate
> commit before C1-C8, pushed immediately to both feature branches. C0 remains a
> separate, unchanged commit; the three approved adjustments are appended verbatim
> as a Decisions section in both source-of-truth documents. Only draft pull
> requests are authorized. No merge, tag, release or publication is authorized.
> No presentation implementation or independent acceptance is claimed here.
>
> Developer release-tooling regression on Ruby 3.4.2:
> - 2.x feature worktree: 61 examples, 0 failures, 6.65 seconds.
> - 1.x feature worktree: 45 examples, 0 failures, 2.50 seconds.
>
> These are focused developer checks, not the full Ruby/Cucumber matrix or an
> independent acceptance verdict. Publication calls in these tests are mocked.
> Chart files, CI workflows, protected branches, tags and remote releases were
> not changed.
>
> ## Decisions 9-10
>
> 9. 独立 QA 发现 P10.6 的 strip-tags 定义（删除所有 <[^>]+>）会把原始 Ruby 堆栈里的 `<top (required)>` 也删除，与 P1 要求完整保留堆栈冲突。是否改为仅剥离客户端生成的展示 HTML，保留代码块、代码片段和用户原文中的尖括号，再严格检查文字顺序（仅沿用已批准的 Rich 样例差异）？
>
> Owner answer: 按此澄清规则，保留原始内容（推荐）
>
> 10. V7 的“开始前完整 ls-remote Tag 清单”未保存；我找到了本任务开始前 GitHub CI 的完整 Tag 拉取记录，8 个 Tag 与当前远端清单完全一致，三个受保护分支也均未变。是否允许用该历史 CI 记录与当前 ls-remote 对照作为替代证据，并在报告中注明来源？不会改变“禁止创建 Tag”的要求。
>
> Owner answer: 接受历史 CI 记录作为替代证据（推荐）
>
> ## Final Release Preparation Decisions
>
> Decisions 11-14 were owner-confirmed on 2026-11-01.
>
> 11. P1 display refinements are approved: displayed frame locations (meta line
>     and project-frame block) are capped at 40 characters by eliding middle
>     directories; the raw backtrace tail is unchanged. When three frame kinds
>     are hidden, the tail caption reads "a, b and c frames not shown above".
>     Goldens may be updated for these two rules only.
> 12. Remote Ruby 3.1 / Cucumber 9 CI is not required for 1.3.2. The local
>     four-cell matrix (Ruby 3.1/3.3 x Cucumber 9/10), re-run on the final
>     tagged code, is the accepted evidence and is recorded in the release notes.
> 13. 1.3.2 is published through the release pipeline after a separate,
>     approved backport of the 1.x release-ancestry rule. Manual asset upload is
>     not used.
> 14. F2 (intraword underscore escaping in titles) and F3 (Unicode attachment
>     slugs) are NOT approved for 1.3.2 / 2.0.1. Current behaviour stays.
>
> Operational clarification: the owner confirmed that only the three named draft
> PRs (#5, #6 and the separate WP3 PR) are required. No fourth PR is authorized.
>
> F1 boundary clarification (owner-confirmed on 2026-11-01):
>
> Question: F1 要求显示位置不超过 40 字符；若无目录的 file:line 本身已超过 40，是否允许仅对显示文件名做中间省略，保留扩展名和行号，原始堆栈不变？
>
> Owner answer: 允许显示文件名中间省略（推荐）
>
> ## Decision 15: Existing F14 Safety Omission
>
> Owner-confirmed on 2026-11-01.
>
> 15. 是否仅对 F14 的 `back\slash` 故障输入保留既有的整条安全省略行为，并将 P1.2 的标题检查记录为明确例外？旧、新 Ledger 对同一真实输入都返回 `[REDACTED] [evidence omitted: unsafe or oversized input]`。其他标题及转义要求仍严格验收，不放宽脱敏。
>
> Owner answer: 保留安全省略，记录这一项例外（推荐）
>
> This exception applies only to the P1.2 title check for this exact F14 failure
> input. It does not waive other title, escaping, redaction, wire-equivalence or
> regression requirements, and does not authorize weakening the safety filter.
>
> ## Decision 16: Independent CI Stability Investigation
>
> Owner-confirmed on 2026-11-01.
>
> 16. 远端 CI 的未改动 1.3.1 基线出现 SIGINT/Spool 和超时失败。是否允许把这些既有 CI 稳定性问题纳入独立排查，必要时另作修复提交？保持全部断言，不推受保护分支、不合并或发布。
>
> Owner answer: 允许独立排查与必要修复（推荐）
>
> This authorizes separately reviewed CI diagnostics and regression coverage,
> including narrowly scoped validation-workflow changes under V6. It does not
> authorize weakening existing assertions, changing Helm, modifying protected
> branches, merging, tagging or publishing. A successful unchanged retry does
> not establish the cause of an earlier failure or demonstrate a runtime fix.
>
> ## Decision 17: Scoped Console Renderer Replay
>
> Owner-confirmed on 2026-11-01.
>
> Question: S12 要求查看 F04 的 Console View，但 RP UI 5.15.6 对嵌套步骤隐藏该入口。是否允许在新建的独立 QA Launch 中，对同一条 F04 日志做字节完全一致的平铺回放，仅验证 Console 展示？原始测试拓扑和证据保持不变，补充证据会明确标注其范围。
>
> Owner answer: 允许补充平铺回放（推荐）
>
> S12 may use a new, independently owned flat-log QA Launch containing the exact
> F04 message bytes. Record the original runtime SHA and Launch/item/log IDs,
> message checksum, supplemental IDs and Console screenshot. This is renderer-only
> proof: retain the original F04 topology and observations, and do not use the
> supplement to certify or change the SDK's item hierarchy, ownership or wire
> contract. Markdown-off is not a substitute for Console View. All other
> acceptance and no-merge/no-tag/no-publication requirements remain unchanged.
>
> ## Decision 18: Scoped F14 API Parameter Ordering
>
> Owner-confirmed on 2026-11-01 after an explanation of the user-visible impact.
>
> Question: 最终审查发现：Cucumber 10 的 F14 基线 API 把参数返回为 e,a,b,c,d，新版为 a,b,c,d,e，但双方发出的参数顺序和值逐字节一致。服务端内部使用无序 Set，API 却声明 List。是否仅对这项 API 读回按完整参数集合（保留重复计数）比较，保留原始差异；所有请求报文仍严格逐字节验收？
>
> Owner answer: 接受这项窄范围调整， 继续
>
> Only the observed Cucumber 10 F14 GET parameter-array ordering difference may be
> compared as a complete multiset, preserving duplicate multiplicities. Retain
> the original API-order FAIL observations and the independently reviewed server
> source explanation. Exact ordered POST parameter bytes must still match.
> No parameter name, value, count, identity, topology or other field is excluded.
>
> This is an acceptance-comparison clarification, not an SDK behavior change or
> a guarantee of fixed parameter ordering in the ReportPortal UI. The request and
> response DTOs declare Lists; server persistence uses a Set. Do not describe the
> response contract as an unordered Set. All other acceptance and
> no-merge/no-tag/no-publication requirements remain unchanged.

</details>
