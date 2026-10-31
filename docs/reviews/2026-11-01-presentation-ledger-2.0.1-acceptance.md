# Ledger presentation acceptance — 2.0.1

Verdict: BLOCKED. Date: 2026-11-01 (Asia/Shanghai). Tester: Independent Ledger QA. Branch: `qa/presentation-ledger-2.0.1`. Candidate head: `ecf8c5aade5b6982f96083cb21c758db56b81b3f`. Baseline: `79e5e9cfde4be6d29ca2293e549460c6c71fe87a`. RP UI 5.15.6 / server 26.0.7.

Final technical evidence is complete; this is NOT ACCEPT. P10.6 and V7 require explicit owner decisions; neither is waived or PASS. Actual October 31 capture stamps remain unchanged. Underlying product suites contain 1345 examples on 1.x and 1402 on 2.x; the independent QA property file adds 16, giving 1361/1418 total examples. Actual per-cell counts below are authoritative.

## Runs
| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |
| --- | --- | --- | --- | --- | --- | --- |
| M5, final-hooks-20261101 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 12.0.1 | offline plain; live plain/rich separately | 1418/0/0 (1402 product + 16 QA) | 7/21 | Offline stub; see live evidence |
| M6, final-hooks-20261101 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | offline plain; live plain/rich separately | 1418/0/0 (1402 product + 16 QA) | 7/21 | Offline stub; see live evidence |
| 20261031T072147Z, independent live captures | Recorded per source probe | 12.0.1 | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 532, 533, 534, 535, 536, 537, 538, 539, 540, 541, 542, 543, 544, 545, 546, 547, 548, 549, 550, 551, 552, 553, 554, 555, 556, 557, 558, 559, 560, 561, 562, 563, 564, 565, 566, 567, 568, 569, 570, 571, 572, 573, 574, 575, 576, 577, 578, 579, 580, 581, 582, 583, 584, 585, 586, 587, 588, 589, 590, 591, 592, 593, 594, 595, 596, 597, 598, 599, 600, 601, 602, 603, 604, 605, 606, 607, 608, 609, 610, 611, 612, 613, 614, 615, 616, 617, 618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628, 629, 630, 631, 632, 633, 634, 635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649, 650, 651, 652, 653, 654, 655, 656, 657, 658, 659, 660, 661, 662, 663, 664, 665, 666, 667, 668, 669, 670, 671, 672, 673, 674, 675, 676, 677, 678, 679, 680, 681, 682, 683, 684, 685, 686, 687, 688, 689, 690, 691, 692, 693, 694, 695, 696, 697, 698, 699, 700, 701, 702, 703, 704, 705, 706, 707, 708, 709, 710, 711, 712, 713, 714, 715, 716, 717, 718, 719, 720, 721, 722, 723, 724, 725, 726, 727, 728, 729, 730, 731, 732, 733, 734, 735, 736, 737, 738, 739, 938, 939, 940, 941, 942, 943, 944, 945, 946, 947, 948, 949, 950, 951, 952, 953, 954, 955, 956, 957, 958, 959 |
| 20261031T173014Z, independent live captures | Recorded per source probe | 12.0.1 | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 982, 983, 984, 985, 986, 987, 988, 989, 990, 991, 992, 993, 994, 995, 996, 997, 998, 999, 1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1010, 1011, 1012, 1013, 1014, 1015, 1016, 1017, 1018, 1019, 1020, 1021, 1022, 1023, 1024, 1025, 1026, 1027, 1028, 1029, 1030, 1031, 1032, 1033 |
| 20261031T174824Z, independent live captures | Recorded per source probe | 12.0.1 | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 1086, 1087, 1088, 1089, 1090 |
| 20261031T180948Z, independent live captures | Recorded per source probe | 12.0.1 | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 1102, 1103, 1104, 1105, 1106, 1107, 1108, 1109, 1110, 1111, 1112, 1113, 1114, 1115, 1116, 1117, 1118, 1119, 1120, 1121, 1122, 1123, 1124, 1125, 1126, 1127, 1128, 1129, 1130, 1131, 1132, 1133, 1134, 1135, 1136, 1137, 1138, 1139 |

Superseded six-cell `final-fixed-20261031` and `final-p88-20261101` runs are retained with full outputs, not reused as final-head suite proof. Original `20261031T065500Z` baseline captures are UNUSABLE: Cucumber loaded candidate source from the current directory. Corrected baseline captures assert loaded-source provenance. Earlier infrastructure/recorder failures and the stopped superseded terminal-repair matrix are preserved, not hidden.

Native Cucumber compound syntax is N/A on 1.x only under Decision 4, with parser rejection and separate companions. F06 is N/A on 1.x. Global-hook Item names are N/A under Decision 5; lifecycle/error/log closure remains checked. No broader fixture or criterion waiver is inferred.

## Results by criterion
| ID | Level | Verdict (PASS/FAIL/N/A/BLOCKED) | Evidence (log/item IDs, file, screenshot) | Note |
| --- | --- | --- | --- | --- |
| G1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 275 checks; logs 4232,4231,4233,3279,3280,3281; items 6176,6177,6178,4788 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 110 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 254 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 78 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 445 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G6 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 41 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G7 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 561 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G8 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 530 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G9 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 41 checks; logs 5840,5841,5842,5843,5844,5845; items 8822,8823,8824,8825 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G10 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G11 | SHOULD | FAIL | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | SHOULD timing target not met; nonblocking, no threshold relaxed. |
| G12 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 276 checks; logs 3755,3756,3757,3758,3759,3760; items 5482,5483,5484,5485 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 6 checks; logs 5855,5856,5515,5516,5522,5523; items 8845,8846,8847,8848 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 6 checks; logs 3458,3459,5517,5524,5531,5538; items 5067,5068,5069,5070 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 29 checks; logs 5855,5856,5515,5516,5641,5522; items 8845,8846,8847,8848 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 26 checks; logs 5641,5658,5675,5692,5855,5856; items 8471,8472,8473,8510 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 3456; items 5061,5062,5063 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.6 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 3460; items 5073,5074,5075 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.9 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.10 | SHOULD | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 5855,5856; items 8845,8846,8847,8848 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 19 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 4 checks; logs 3401,3402,3403,3404,3405,3406; items 4968,4969,4970,4971 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 76 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks; logs 3456,5636,5637,5638,5639,5640; items 5061,5062,5063,8468 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 27 checks; logs 3401,3402,3403,3404,3405,3406; items 4968,4969,4970,4971 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 10 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 8 checks; logs 5513,5514,5520,5521,5527,5528; items 8183,8184,8185,8186 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 4 checks; logs 3401,3402,3403,3404,3405,3406; items 4968,4969,4970,4971 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 76 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 3279,3280,3281; items 4788,4789,4790 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 3 checks; logs 5855,5856,3461,3462,3463,3464; items 8845,8846,8847,8848 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1333 checks; logs 5636,5637,5638,5639,5640,4469; items 8468,8469,8470,6523 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1333 checks; logs 5636,5637,5638,5639,5640,4469; items 8468,8469,8470,6523 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 3 checks; logs 3467,3468,3469,3470,3471,3472; items 5080,5081,5082,5083 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.6 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks; logs 3461,3462,3463,3464,3465,3466; items 5076,5077,5078,5079 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P6.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 68 checks; logs 5857,5858,5859,5860,5864,5865; items 8850,8851,8852,8853 | Resolved D03: C9/C10/C12 native Before/After/AfterStep names, real retry, fault fallback and final cache cleanup independently verified in both modes twice. Original failures remain in the historical ledger. |
| P6.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 76 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P6.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 5855,5856; items 8845,8846,8847,8848 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P6.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks; logs 3286,3287,3288,3289; items 4800,4801,4802,4803 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 3 checks; logs 3399,3400; items 4964,4965,4966,4967 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 3 checks; logs 3302,3303,3304,3305,3306,3307; items 4835,4836,4837,4838 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 4 checks; logs 3467,3468,3469,3470,3471,3472; items 5080,5081,5082,5083 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 3 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks; logs 5625,5627; items 8435,8436,8437,8441 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 4 checks; logs 5626,5628,5629; items 8438,8439,8440,8444 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 5627; items 8441,8442,8443 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 5 checks; logs 5631,5632,5633,5630; items 8453,8454,8455,8456 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks; logs 5636,5637,5638,5639,5640; items 8468,8469,8470 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.6 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 85 checks; logs 3279,3280,3281,3282,3283,3284; items 4788,4789,4790,4791 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 5635; items 8465,8466,8467 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 49 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.9 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 3479; items 5097,5098,5099 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 4 checks; logs 3476,3478,5777,5786; items 5088,5089,5090,5094 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks; logs 3477; items 5091,5092,5093 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 7 checks; logs 3476,3477,3478,5777,5786; items 5088,5089,5090,5091 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 3 checks; logs 4469,4470,4471,4472,4473,4474; items 6523,6524,6525,6526 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 4 checks; logs 3480; items 5100,5101,5102 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 238 checks; logs 3755,3756,3757,3758,3759,3760; items 5482,5483,5484,5485 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 30 checks; logs 5983,5984,5661,5662,5663,5666; items 8999,9000,9001,9002 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 238 checks; logs 3755,3756,3757,3758,3759,3760; items 5482,5483,5484,5485 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.6 | MUST | BLOCKED | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 239 checks; logs 3755,3756,3757,3758,3759,3760; items 5482,5483,5484,5485 | Literal strip-tags removes <top (required)> and <main> inside byte-frozen F04 fences; owner clarification pending |
| P10.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 271 checks; logs 3755,3756,3757,3758,3759,3760; items 5482,5483,5484,5485 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 31 checks; logs 5983,5984,5664,5668,3907,3908; items 8999,9000,9001,9002 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.9 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 3 checks; logs 3875,3876; items 5658,5659,5660,5661 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.10 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 49 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.11 | SHOULD | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 5 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V1 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V2 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V3 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V4 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V5 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V6 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V7 | MUST | BLOCKED | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 2 checks | Authentic complete pre-task public CI tag fetch-list and unchanged protected refs retained. Original full ls-remote before snapshot is unavailable; owner approval of alternative evidence is pending. |
| V8 | MUST | PASS | [Complete checks](assets/presentation-ledger-2.0.1-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |

## Defects
| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| D01 | S2, resolved | P2.1 | F14 | Literal table punctuation | Original star/underscore/backtick delimiters disappeared. Repaired DOM checks retain all 14 literals. | Original and repaired S04; complete DOM JSON |
| D02 | S2, resolved | P8.8 | ALL F10/F11, F12 control | Baseline native/terminal body | Tier 1 presentation leaked into terminal/native body. Fresh 48 comparisons per line pass after repair; RP payload hashes/owners unchanged. | terminal-audit-20261031T173014Z.json; original failing process files retained |
| D03 | S2, resolved by final native/API retest | P6.1 | F15-named | Preserve declared native hook names | Original native Hook.name existed but RP lost it. Final 178 checks on 2.x and 284 on 1.x pass, including all three kinds, real retry, fault fallback and actual-completion cache cleanup. | Historical ledger; hooks-audit JSON; final S07 |
| D04 | S3, open | G11 | F01-F18 corpus | Every formatter p95 below 2 ms | FailureCard.format p95 8.31 ms in wrapper-free replay (2,100 calls). Wall medians remain within +10%; full samples/runtime retained. | ledger-qa-performance-2.0.1.json |
| D05 | S3, cosmetic | Outside P4.3 | F02 | Compact Examples metadata | Examples metadata wraps at 1100px. Key/value chips each have one physical line; P4.3 passes. | S05 and chip getClientRects proof |

P10.6 is a specification-algorithm conflict, not permission to alter frozen backtrace bytes or raw user logs. The literal prescribed regex deletes three `top` words from Ruby `<top (required)>` code labels. The proposed code-aware comparison passes, but owner approval is pending. V7 retains authentic public pre-task CI fetch-list evidence, not a fabricated original remote before snapshot.

On 1.x, six baseline NUL-preview attachment losses use only the exact Decision 8 exception: baseline accepted wire plus complete candidate per-item download, with matching owner/name/MIME/bytes/hash. The unchanged raw-NUL native user log is absent from both versions. HTTP 201 is submission acceptance, not persistence proof; the read API gives no server rejection reason. The old baseline F16f SECRET123 probe hit is not a candidate G8 failure.

The final GET audit initially omitted 15 first-attempt Scenarios because the normal API item page nests them in the latest Scenario's retries array. Original mismatches are retained. The separate immutable supplement discovers those actual nested IDs, directly reads each attempt, verifies UUID/real parent/closed status/Suite-to-Launch lineage and per-item filters, and proves the expanded item/log sets equal the snapshots. This is an explicit query-model correction, not a topology or persistence waiver.

The supplied pre-fix Master M4 wall-clock assertion failure (0.817765 s versus <0.5 s under concurrent load) is not erased or labelled proven baseline flakiness. Its helper includes bootstrap/business work; separate timing instrumentation records actual finalization while retaining every original assertion. All six final isolated cells pass unchanged bounds. No timeout increase or timing waiver was used.

Evidence checkout/extraction and path mapping: [artifact guide](assets/presentation-ledger-2.0.1-evidence.md). Raw captures are losslessly archived with per-file SHA256 manifests; SDK mirrors, caches and temporary package binaries are excluded.

## Screenshots
- [S01-failure-plain](assets/presentation-ledger-2.0.1/S01-failure-plain.png), plain; Launch 939; context Item 8189; PASS.
- [S02-stack-trace](assets/presentation-ledger-2.0.1/S02-stack-trace.png), plain; Launch 939; context Item 8189; PASS.
- [S04-angle-table](assets/presentation-ledger-2.0.1/S04-angle-table.png), plain; Launch 534; context Item 4801; PASS.
- [S04-literal-star-repaired](assets/presentation-ledger-2.0.1/S04-literal-star-repaired.png), plain; Launch 554; context Item 4981; PASS.
- [S05-outline-chips](assets/presentation-ledger-2.0.1/S05-outline-chips.png), plain; Launch 938; context Item 8183; PASS.
- [S06-preview-modal](assets/presentation-ledger-2.0.1/S06-preview-modal.png), plain; Launch 532; context Item 4789; PASS.
- [S06-attachments-plain](assets/presentation-ledger-2.0.1/S06-attachments-plain.png), plain; Launch 532; context Item 4789; PASS.
- [S06-attachments-rich](assets/presentation-ledger-2.0.1/S06-attachments-rich.png), rich; Launch 614; context Item 5483; PASS.
- [S07-hook-rows](assets/presentation-ledger-2.0.1/S07-hook-rows.png), plain; Launch 556; context Item 5045; PASS.
- [S08-numeric-plain](assets/presentation-ledger-2.0.1/S08-numeric-plain.png), plain; Launch 553; context Item 4965; PASS.
- [S08-numeric-rich](assets/presentation-ledger-2.0.1/S08-numeric-rich.png), rich; Launch 635; context Item 5659; PASS.
- [S09-f10a-plain](assets/presentation-ledger-2.0.1/S09-f10a-plain.png), plain; Launch 541; context Item 4929; PASS.
- [S09-f10c-plain](assets/presentation-ledger-2.0.1/S09-f10c-plain.png), plain; Launch 543; context Item 4935; PASS.
- [S09-f11a-plain](assets/presentation-ledger-2.0.1/S09-f11a-plain.png), plain; Launch 546; context Item 4944; PASS.
- [S09-f11b-plain](assets/presentation-ledger-2.0.1/S09-f11b-plain.png), plain; Launch 547; context Item 4947; PASS.
- [S09-f11c-plain](assets/presentation-ledger-2.0.1/S09-f11c-plain.png), plain; Launch 548; context Item 4950; PASS.
- [S09-f12-plain](assets/presentation-ledger-2.0.1/S09-f12-plain.png), plain; Launch 552; context Item 4962; PASS.
- [S09-f10a-rich](assets/presentation-ledger-2.0.1/S09-f10a-rich.png), rich; Launch 623; context Item 5623; PASS.
- [S09-f10c-rich](assets/presentation-ledger-2.0.1/S09-f10c-rich.png), rich; Launch 625; context Item 5629; PASS.
- [S09-f11a-rich](assets/presentation-ledger-2.0.1/S09-f11a-rich.png), rich; Launch 628; context Item 5638; PASS.
- [S09-f11b-rich](assets/presentation-ledger-2.0.1/S09-f11b-rich.png), rich; Launch 629; context Item 5641; PASS.
- [S09-f11c-rich](assets/presentation-ledger-2.0.1/S09-f11c-rich.png), rich; Launch 630; context Item 5644; PASS.
- [S09-f12-rich](assets/presentation-ledger-2.0.1/S09-f12-rich.png), rich; Launch 634; context Item 5656; PASS.
- [S10-launch-context-chips](assets/presentation-ledger-2.0.1/S10-launch-context-chips.png), plain; Launch 567; context Item N/A Launch list; PASS.
- [S11-f01-markdown-off](assets/presentation-ledger-2.0.1/S11-f01-markdown-off.png), plain; Launch 532; context Item 4789; PASS.
- [S11-f04-frozen-markdown-off](assets/presentation-ledger-2.0.1/S11-f04-frozen-markdown-off.png), plain; Launch 939; context Item 8189; PASS.
- [S11-f10a-markdown-off](assets/presentation-ledger-2.0.1/S11-f10a-markdown-off.png), plain; Launch 541; context Item 4929; PASS.
- [S11-f11a-markdown-off](assets/presentation-ledger-2.0.1/S11-f11a-markdown-off.png), plain; Launch 546; context Item 4944; PASS.
- [S12-console-scope-blocked](assets/presentation-ledger-2.0.1/S12-console-scope-blocked.png), plain; Launch 939; context Item 8188; HISTORICAL_BLOCKED_NOT_EXIT_EVIDENCE.
- [S12-f04-console](assets/presentation-ledger-2.0.1/S12-f04-console.png), plain; Launch 939; context Item 8189; PASS.
- [S12-f01-console](assets/presentation-ledger-2.0.1/S12-f01-console.png), plain; Launch 532; context Item 4789; PASS.
- [S12-f04-frozen-console](assets/presentation-ledger-2.0.1/S12-f04-frozen-console.png), plain; Launch 939; context Item 8189; PASS.
- [S12-f10a-console](assets/presentation-ledger-2.0.1/S12-f10a-console.png), plain; Launch 541; context Item 4929; PASS.
- [S12-f11a-console](assets/presentation-ledger-2.0.1/S12-f11a-console.png), plain; Launch 546; context Item 4944; PASS.
- [S06-download-gallery](assets/presentation-ledger-2.0.1/S06-download-gallery.png), plain; Launch 532; context Item 4789; PASS_DOWNLOAD_CONTROL_ONLY.
- [S03-failure-rich-open](assets/presentation-ledger-2.0.1/S03-failure-rich-open.png), rich; Launch 947; context Item 8225; PASS.
- [S07-named-hooks-final](assets/presentation-ledger-2.0.1/S07-named-hooks-final.png), plain; Launch 1104; context Item 8823; PASS.

S12 is genuine native Console via ordinary Log Message search, not Markdown-off. Pagination was already ON and not changed; Console/search/Markdown state was restored. Historical empty-scope blocked shots remain labelled historical and are not exit evidence. S03 was re-captured using a fixed 1100 x 780 viewport clip; metadata records the actual method. Native download filenames are proved by real UI clicks and separately statted/hashed files, not headers alone.

## Waivers
Only the owner-confirmed Decisions below apply. Master review/QA-artifact archival instructions are not user waivers. P10.6/V7 pending questions are not approvals.

>
> Owner-confirmed on 2026-10-31. The following questions and answers are reproduced
> word for word. These decisions take precedence over conflicting text above;
> the independent tester must assess against them.
>
> 1. Question: 还有一处验收冲突需要确认：规范要求表格换行生成 <br>，P2.3 却禁止任何原始尖括号。是否允许唯一例外：由客户端生成的 <br>，用户输入的尖括号仍必须转义？
>
>    Owner answer: 允许客户端生成的 <br>（推荐）
>
> 2. Question: Rich 样例会把 PNG 移到文件名前、把“Assertion passed”换成“PASS”，但 P10.6 要求所有原文字词顺序不变。你希望以哪项为准？
>
>    Owner answer: 按 Rich 样例呈现，调整 P10.6 允许这些差异
>
> 3. Question: 现有完整回归测试会在临时目录调用 Helm 打包，与你要求“不得打包 Helm”冲突。是否允许仅运行这些现有隔离测试，不生成交付 Chart、不部署、不上传？
>
>    Owner answer: 允许测试中的临时打包（推荐）
>
> 4. Question: 已实测 Cucumber 9 的解析器拒绝同一步同时包含 DocString 和 DataTable，而 F02/F03 要求两条发布线都跑这类语法。是否允许 1.x 将“原生复合语法”标为 N/A，并用分开的参数步骤验证同样的表格、描述和 Outline 展示；2.x 仍严格验收原生复合语法？
>
>    Owner answer: 允许，保留解析失败证据（推荐）
>
> 5. Question: 还有一处验收口径需要确认：现有原生 BeforeAll/AfterAll 并不生成独立 Hook Item（2.x 的日志归属 Launch，1.x 的 BeforeAll 甚至早于 formatter 创建）。为遵守“不改变节点拓扑”，是否保留这些行为，将全局钩子的 Item 名称检查标为 N/A，同时继续验证日志/异常与退出闭合，并用单测覆盖已有 class-hook 名称映射？
>
>    Owner answer: 保留基线行为并记录 N/A（推荐）
>
> 6. Question: 为消除 2.x 文档冲突，是否允许仅将 PR 目标分支 codex/cucumber-12 同步合并进功能分支，并保留目标分支已发布的 2.0.0 CHANGELOG 内容？不合并 PR、不推受保护分支、不强推、不发布。
>
>    Owner answer: 允许仅同步目标分支，并保留正式发布历史（推荐）
>
> 7. Question: 独立 QA 发现验收金样与明确规则有三处冲突：P1 标题下划线未转义；P8 金样遗漏了 F11a 要求的 4 个请求 Header；同一 Hash 报文实际输入长度为 55/51 B，而金样写成 212/148 B。是否按明确规则修正金样，继续逐字节比较，并完整保留 P1 的 62 帧原始基线栈，不放宽帧数要求？
>
>    Owner answer: 按规则修正金样，保留严格逐字节验收（推荐）
>
> 8. Question: 独立 QA 确认：1.x 旧基线有 6 个含 NUL 字符的文本附件未落库，新版则完整保存，且上传字节、MIME 和归属均不变。是否允许仅这 6 项改用旧版实际提交的报文作对照，并要求新版完整读回；其余 G2/G3 仍严格比较 API 基线？另有一条原生 NUL 用户日志在新旧版均未落库，将明确列为既有限制，暂不改变其语义。
>
>    Owner answer: 允许这 6 项基线例外，记录既有限制（推荐）
>
