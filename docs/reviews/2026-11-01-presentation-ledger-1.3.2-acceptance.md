# Ledger presentation acceptance — 1.3.2

Verdict: BLOCKED. Date: 2026-11-01 (Asia/Shanghai). Tester: Independent Ledger QA. Branch: `qa/presentation-ledger-1.3.2`. Candidate head: `c27510547ace0d4baaf964a0575e5bec4344e11a`. Baseline: `4ca2f770e0a84e83688f165ba04b4db8ef855cf9`. RP UI 5.15.6 / server 26.0.7.

Final technical evidence is complete; this is NOT ACCEPT. P10.6 and V7 require explicit owner decisions; neither is waived or PASS. Actual October 31 capture stamps remain unchanged. Underlying product suites contain 1345 examples on 1.x and 1402 on 2.x; the independent QA property file adds 16, giving 1361/1418 total examples. Actual per-cell counts below are authoritative.

## Runs
| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |
| --- | --- | --- | --- | --- | --- | --- |
| M1, final-hooks-20261101 | ruby 3.1.7p261 (2025-03-26 revision 0a3704f218) [aarch64-linux] | 9.2.1 | offline plain; live plain/rich separately | 1361/0/0 (1345 product + 16 QA) | 1/3 | Offline stub; see live evidence |
| M2, final-hooks-20261101 | ruby 3.1.7p261 (2025-03-26 revision 0a3704f218) [aarch64-linux] | 10.2.0 | offline plain; live plain/rich separately | 1361/0/0 (1345 product + 16 QA) | 1/3 | Offline stub; see live evidence |
| M3, final-hooks-20261101 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 9.2.1 | offline plain; live plain/rich separately | 1361/0/0 (1345 product + 16 QA) | 1/3 | Offline stub; see live evidence |
| M4, final-hooks-20261101 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 10.2.0 | offline plain; live plain/rich separately | 1361/0/0 (1345 product + 16 QA) | 1/3 | Offline stub; see live evidence |
| 20261031T072147Z, independent live captures | Recorded per source probe | 9/10 as indexed | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 740, 741, 742, 743, 744, 745, 746, 747, 748, 749, 750, 751, 752, 753, 754, 755, 756, 757, 758, 759, 760, 761, 762, 763, 764, 765, 766, 767, 768, 769, 770, 771, 772, 773, 774, 775, 776, 777, 778, 779, 780, 781, 782, 783, 784, 785, 786, 787, 788, 789, 790, 791, 792, 793, 794, 795, 796, 797, 798, 799, 800, 801, 802, 803, 804, 805, 806, 807, 808, 809, 810, 811, 812, 813, 814, 815, 816, 817, 818, 819, 820, 821, 822, 823, 824, 825, 826, 827, 828, 829, 830, 831, 832, 833, 834, 835, 836, 837, 838, 839, 840, 841, 842, 843, 844, 845, 846, 847, 848, 849, 850, 851, 852, 853, 854, 855, 856, 857, 858, 859, 860, 861, 862, 863, 864, 865, 866, 867, 868, 869, 870, 871, 872, 873, 874, 875, 876, 877, 878, 879, 880, 881, 882, 883, 884, 885, 886, 887, 888, 889, 890, 891, 892, 893, 894, 895, 896, 897, 898, 899, 900, 901, 902, 903, 904, 905, 906, 907, 908, 909, 910, 911, 912, 913, 914, 915, 916, 917, 918, 919, 920, 921, 922, 923, 924, 925, 926, 927, 928, 929, 930, 931, 932, 933, 934, 935, 936, 937, 960, 961, 962, 963, 964, 965, 966, 967, 968, 969, 970, 971, 972, 973, 974, 975, 976, 977, 978, 979, 980, 981 |
| 20261031T173014Z, independent live captures | Recorded per source probe | 9/10 as indexed | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 1034, 1035, 1036, 1037, 1038, 1039, 1040, 1041, 1042, 1043, 1044, 1045, 1046, 1047, 1048, 1049, 1050, 1051, 1052, 1053, 1054, 1055, 1056, 1057, 1058, 1059, 1060, 1061, 1062, 1063, 1064, 1065, 1066, 1067, 1068, 1069, 1070, 1071, 1072, 1073, 1074, 1075, 1076, 1077, 1078, 1079, 1080, 1081, 1082, 1083, 1084, 1085 |
| 20261031T174824Z, independent live captures | Recorded per source probe | 9/10 as indexed | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 1091, 1092, 1093, 1094, 1095, 1096, 1097, 1098, 1099, 1100, 1101 |
| 20261031T180948Z, independent live captures | Recorded per source probe | 9/10 as indexed | baseline/plain/rich as indexed | Not a replacement for full suites | Native JSON retained | 1140, 1141, 1142, 1143, 1144, 1145, 1146, 1147, 1148, 1149, 1150, 1151, 1152, 1153, 1154, 1155, 1156, 1157, 1158, 1159, 1160, 1161, 1162, 1163, 1164, 1165, 1166, 1167, 1168, 1169, 1170, 1171, 1172, 1173, 1174, 1175, 1176, 1177, 1178, 1179, 1180, 1181, 1182, 1183, 1184, 1185, 1186, 1187, 1188, 1189, 1190, 1191, 1192, 1193, 1194, 1195, 1196, 1197, 1198, 1199 |

Superseded six-cell `final-fixed-20261031` and `final-p88-20261101` runs are retained with full outputs, not reused as final-head suite proof. Original `20261031T065500Z` baseline captures are UNUSABLE: Cucumber loaded candidate source from the current directory. Corrected baseline captures assert loaded-source provenance. Earlier infrastructure/recorder failures and the stopped superseded terminal-repair matrix are preserved, not hidden.

Native Cucumber compound syntax is N/A on 1.x only under Decision 4, with parser rejection and separate companions. F06 is N/A on 1.x. Global-hook Item names are N/A under Decision 5; lifecycle/error/log closure remains checked. No broader fixture or criterion waiver is inferred.

## Results by criterion
| ID | Level | Verdict (PASS/FAIL/N/A/BLOCKED) | Evidence (log/item IDs, file, screenshot) | Note |
| --- | --- | --- | --- | --- |
| G1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 276 checks; logs 5304,5303,5305,4480,4479,4481; items 7845,7846,7847,6533 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 112 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 240 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 80 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 455 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G6 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 39 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G7 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 493 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G8 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 536 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G9 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 57 checks; logs 6218,6219,6220,6221,6222,6223; items 9332,9333,9334,9335 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G10 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| G11 | SHOULD | FAIL | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | SHOULD timing target not met; nonblocking, no threshold relaxed. |
| G12 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 271 checks; logs 4891,4893,4892,4894,4895,4896; items 7189,7190,7191,7192 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 6 checks; logs 6122,6123,5562,5563,5575,5576; items 9170,9171,9172,9173 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 6 checks; logs 4662,4663,5564,5577,5590,5603; items 6825,6826,6827,6828 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 29 checks; logs 6122,6123,5562,5563,5709,5575; items 9170,9171,9172,9173 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 28 checks; logs 5709,5726,5743,5760,6122,6123; items 8627,8628,8629,8666 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 4660; items 6819,6820,6821 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.6 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 4664; items 6831,6832,6833 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.9 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P1.10 | SHOULD | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 6122,6123; items 9170,9171,9172,9173 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 19 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks; logs 4608,4609,4610,4611,4612,4613; items 6729,6730,6731,6732 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P2.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 68 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks; logs 4660,5704,5705,5706,5707,5708; items 6819,6820,6821,8624 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 26 checks; logs 4608,4609,4610,4611,4612,4613; items 6729,6730,6731,6732 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P3.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 10 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 8 checks; logs 5565,5566,5578,5579,5591,5592; items 8304,8305,8306,8307 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks; logs 4608,4609,4610,4611,4612,4613; items 6729,6730,6731,6732 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P4.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 68 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 4480,4479,4481; items 6533,6534,6535 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 3 checks; logs 6122,6123,4665,4667,4666,4668; items 9170,9171,9172,9173 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1189 checks; logs 5704,5705,5706,5707,5708,5503; items 8624,8625,8626,8173 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1189 checks; logs 5704,5705,5706,5707,5708,5503; items 8624,8625,8626,8173 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 3 checks; logs 4671,4672,4673,4674,4675,4676; items 6838,6839,6840,6841 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.6 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks; logs 4665,4667,4666,4668,4669,4670; items 6834,6835,6836,6837 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 5 checks; logs 4570,4571,4572,4573,4574,4575; items 6648,6649,6650,6651 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P5.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P6.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 136 checks; logs 6124,6125,6126,6127,6128,6129; items 9175,9176,9177,9178 | Resolved D03: C9/C10/C12 native Before/After/AfterStep names, real retry, fault fallback and final cache cleanup independently verified in both modes twice. Original failures remain in the historical ledger. |
| P6.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 68 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P6.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 6122,6123; items 9170,9171,9172,9173 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P6.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks; logs 4490,4491,4492,4493,4494,4495; items 6553,6554,6555,6556 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 5 checks; logs 4606,4607; items 6725,6726,6727,6728 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 5 checks; logs 4510,4511,4512,4513,4514,4515; items 6596,6597,6598,6599 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks; logs 4671,4672,4673,4674,4675,4676; items 6838,6839,6840,6841 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P7.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 3 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks; logs 5693,5695; items 8591,8592,8593,8597 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks; logs 5694,5696,5697; items 8594,8595,8596,8600 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 5695; items 8597,8598,8599 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 5 checks; logs 5699,5700,5701,5698; items 8609,8610,8611,8612 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks; logs 5704,5705,5706,5707,5708; items 8624,8625,8626 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.6 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 81 checks; logs 4480,4479,4481,4482,4483,4484; items 6533,6534,6535,6536 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 5703; items 8621,8622,8623 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 49 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P8.9 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 4683; items 6855,6856,6857 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 4 checks; logs 4680,4682,5803,5812; items 6846,6847,6848,6852 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks; logs 4681; items 6849,6850,6851 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 9 checks; logs 4680,4681,4682,5803,5812; items 6846,6847,6848,6849 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P9.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 3 checks; logs 5503,5504,5505,5506,5507,5508; items 8173,8174,8175,8176 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 6 checks; logs 4684; items 6858,6859,6860 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 206 checks; logs 4891,4893,4892,4894,4895,4896; items 7189,7190,7191,7192 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 30 checks; logs 6172,6173,5729,5730,5731,5734; items 9254,9255,9256,9257 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 206 checks; logs 4891,4893,4892,4894,4895,4896; items 7189,7190,7191,7192 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.6 | MUST | BLOCKED | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 207 checks; logs 4891,4893,4892,4894,4895,4896; items 7189,7190,7191,7192 | Literal strip-tags removes <top (required)> and <main> inside byte-frozen F04 fences; owner clarification pending |
| P10.7 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 262 checks; logs 4891,4893,4892,4894,4895,4896; items 7189,7190,7191,7192 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.8 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 31 checks; logs 6172,6173,5732,5736,5050,5051; items 9254,9255,9256,9257 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.9 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 3 checks; logs 5018,5019; items 7381,7382,7383,7384 | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.10 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 49 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| P10.11 | SHOULD | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 5 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V1 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V2 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V3 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V4 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V5 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V6 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |
| V7 | MUST | BLOCKED | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 2 checks | Authentic complete pre-task public CI tag fetch-list and unchanged protected refs retained. Original full ls-remote before snapshot is unavailable; owner approval of alternative evidence is pending. |
| V8 | MUST | PASS | [Complete checks](assets/presentation-ledger-1.3.2-acceptance.json), 1 checks | All recorded subchecks pass; see exact inputs/expected/actual and source references. |

## Defects
| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| D01 | S2, resolved | P2.1 | F14 | Literal table punctuation | Original star/underscore/backtick delimiters disappeared. Repaired DOM checks retain all 14 literals. | Original and repaired S04; complete DOM JSON |
| D02 | S2, resolved | P8.8 | ALL F10/F11, F12 control | Baseline native/terminal body | Tier 1 presentation leaked into terminal/native body. Fresh 48 comparisons per line pass after repair; RP payload hashes/owners unchanged. | terminal-audit-20261031T173014Z.json; original failing process files retained |
| D03 | S2, resolved by final native/API retest | P6.1 | F15-named | Preserve declared native hook names | Original native Hook.name existed but RP lost it. Final 178 checks on 2.x and 284 on 1.x pass, including all three kinds, real retry, fault fallback and actual-completion cache cleanup. | Historical ledger; hooks-audit JSON; final S07 |
| D04 | S3, open | G11 | F01-F18 corpus | Every formatter p95 below 2 ms | FailureCard.format p95 7.34 ms in wrapper-free replay (2,100 calls). Wall medians remain within +10%; full samples/runtime retained. | ledger-qa-performance-1.3.2.json |
| D05 | S3, cosmetic | Outside P4.3 | F02 | Compact Examples metadata | Examples metadata wraps at 1100px. Key/value chips each have one physical line; P4.3 passes. | S05 and chip getClientRects proof |

P10.6 is a specification-algorithm conflict, not permission to alter frozen backtrace bytes or raw user logs. The literal prescribed regex deletes three `top` words from Ruby `<top (required)>` code labels. The proposed code-aware comparison passes, but owner approval is pending. V7 retains authentic public pre-task CI fetch-list evidence, not a fabricated original remote before snapshot.

On 1.x, six baseline NUL-preview attachment losses use only the exact Decision 8 exception: baseline accepted wire plus complete candidate per-item download, with matching owner/name/MIME/bytes/hash. The unchanged raw-NUL native user log is absent from both versions. HTTP 201 is submission acceptance, not persistence proof; the read API gives no server rejection reason. The old baseline F16f SECRET123 probe hit is not a candidate G8 failure.

The final GET audit initially omitted 15 first-attempt Scenarios because the normal API item page nests them in the latest Scenario's retries array. Original mismatches are retained. The separate immutable supplement discovers those actual nested IDs, directly reads each attempt, verifies UUID/real parent/closed status/Suite-to-Launch lineage and per-item filters, and proves the expanded item/log sets equal the snapshots. This is an explicit query-model correction, not a topology or persistence waiver.

The supplied pre-fix Master M4 wall-clock assertion failure (0.817765 s versus <0.5 s under concurrent load) is not erased or labelled proven baseline flakiness. Its helper includes bootstrap/business work; separate timing instrumentation records actual finalization while retaining every original assertion. All six final isolated cells pass unchanged bounds. No timeout increase or timing waiver was used.

Evidence checkout/extraction and path mapping: [artifact guide](assets/presentation-ledger-1.3.2-evidence.md). Raw captures are losslessly archived with per-file SHA256 manifests; SDK mirrors, caches and temporary package binaries are excluded.

## Screenshots
- [S01-failure-plain](assets/presentation-ledger-1.3.2/S01-failure-plain.png), plain; Launch 961; context Item 8297; PASS.
- [S02-stack-trace](assets/presentation-ledger-1.3.2/S02-stack-trace.png), plain; Launch 961; context Item 8297; PASS.
- [S04-literal-star-repaired](assets/presentation-ledger-1.3.2/S04-literal-star-repaired.png), plain; Launch 762; context Item 6742; PASS.
- [S04-angle-table](assets/presentation-ledger-1.3.2/S04-angle-table.png), plain; Launch 742; context Item 6554; PASS.
- [S05-outline-chips](assets/presentation-ledger-1.3.2/S05-outline-chips.png), plain; Launch 963; context Item 8304; PASS.
- [S06-attachments-plain](assets/presentation-ledger-1.3.2/S06-attachments-plain.png), plain; Launch 740; context Item 6534; PASS.
- [S06-attachments-rich](assets/presentation-ledger-1.3.2/S06-attachments-rich.png), rich; Launch 818; context Item 7190; PASS.
- [S07-hook-rows](assets/presentation-ledger-1.3.2/S07-hook-rows.png), plain; Launch 764; context Item 6806; PASS.
- [S08-numeric-plain](assets/presentation-ledger-1.3.2/S08-numeric-plain.png), plain; Launch 761; context Item 6726; PASS.
- [S08-numeric-rich](assets/presentation-ledger-1.3.2/S08-numeric-rich.png), rich; Launch 839; context Item 7382; PASS.
- [S09-f10a-plain](assets/presentation-ledger-1.3.2/S09-f10a-plain.png), plain; Launch 749; context Item 6690; PASS.
- [S09-f10c-plain](assets/presentation-ledger-1.3.2/S09-f10c-plain.png), plain; Launch 751; context Item 6696; PASS.
- [S09-f11a-plain](assets/presentation-ledger-1.3.2/S09-f11a-plain.png), plain; Launch 754; context Item 6705; PASS.
- [S09-f11b-plain](assets/presentation-ledger-1.3.2/S09-f11b-plain.png), plain; Launch 755; context Item 6708; PASS.
- [S09-f11c-plain](assets/presentation-ledger-1.3.2/S09-f11c-plain.png), plain; Launch 756; context Item 6711; PASS.
- [S09-f12-plain](assets/presentation-ledger-1.3.2/S09-f12-plain.png), plain; Launch 760; context Item 6723; PASS.
- [S09-f10a-rich](assets/presentation-ledger-1.3.2/S09-f10a-rich.png), rich; Launch 827; context Item 7346; PASS.
- [S09-f10c-rich](assets/presentation-ledger-1.3.2/S09-f10c-rich.png), rich; Launch 829; context Item 7352; PASS.
- [S09-f11a-rich](assets/presentation-ledger-1.3.2/S09-f11a-rich.png), rich; Launch 832; context Item 7361; PASS.
- [S09-f11b-rich](assets/presentation-ledger-1.3.2/S09-f11b-rich.png), rich; Launch 833; context Item 7364; PASS.
- [S09-f11c-rich](assets/presentation-ledger-1.3.2/S09-f11c-rich.png), rich; Launch 834; context Item 7367; PASS.
- [S09-f12-rich](assets/presentation-ledger-1.3.2/S09-f12-rich.png), rich; Launch 838; context Item 7379; PASS.
- [S10-launch-context-chips](assets/presentation-ledger-1.3.2/S10-launch-context-chips.png), plain; Launch 774; context Item N/A Launch list; PASS.
- [S11-f01-markdown-off](assets/presentation-ledger-1.3.2/S11-f01-markdown-off.png), plain; Launch 740; context Item 6534; PASS.
- [S11-f04-frozen-markdown-off](assets/presentation-ledger-1.3.2/S11-f04-frozen-markdown-off.png), plain; Launch 961; context Item 8297; PASS.
- [S11-f10a-markdown-off](assets/presentation-ledger-1.3.2/S11-f10a-markdown-off.png), plain; Launch 749; context Item 6690; PASS.
- [S11-f11a-markdown-off](assets/presentation-ledger-1.3.2/S11-f11a-markdown-off.png), plain; Launch 754; context Item 6705; PASS.
- [S12-console-scope-blocked](assets/presentation-ledger-1.3.2/S12-console-scope-blocked.png), plain; Launch 961; context Item 8296; HISTORICAL_BLOCKED_NOT_EXIT_EVIDENCE.
- [S12-f01-console](assets/presentation-ledger-1.3.2/S12-f01-console.png), plain; Launch 740; context Item 6534; PASS.
- [S12-f04-frozen-console](assets/presentation-ledger-1.3.2/S12-f04-frozen-console.png), plain; Launch 961; context Item 8297; PASS.
- [S12-f10a-console](assets/presentation-ledger-1.3.2/S12-f10a-console.png), plain; Launch 749; context Item 6690; PASS.
- [S12-f11a-console](assets/presentation-ledger-1.3.2/S12-f11a-console.png), plain; Launch 754; context Item 6705; PASS.
- [S06-preview-modal](assets/presentation-ledger-1.3.2/S06-preview-modal.png), plain; Launch 740; context Item 6534; PASS.
- [S03-failure-rich-open](assets/presentation-ledger-1.3.2/S03-failure-rich-open.png), rich; Launch 969; context Item 8357; PASS.
- [S07-named-hooks-final](assets/presentation-ledger-1.3.2/S07-named-hooks-final.png), plain; Launch 1142; context Item 9148; PASS.

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
