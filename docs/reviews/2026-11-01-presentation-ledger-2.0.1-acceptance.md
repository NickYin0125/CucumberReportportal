# Ledger presentation acceptance - 2.0.1

Verdict: ACCEPT. Date: 2026-11-01 (Asia/Shanghai). Tester: Independent Ledger QA. Branch: `qa/presentation-ledger-2.0.1`. Candidate feature head: `173c6038b417e86aeb4f268649ce4c81aa30888e`. Actually tested runtime head: `3f20313c20b25071fbc49b31e1c6bc772bd599e4`. Baseline: `79e5e9cfde4be6d29ca2293e549460c6c71fe87a`. RP UI 5.15.6 / server 26.0.7.

Documentation-only binding: [exact path/mode/blob fingerprints and fresh package member proof](assets/wp5-ci-final-20261101/docs-only-final-binding-r2.json) pass. Only the approved documentation delta is newly verified; matrix/live/fault/performance runs retain their original tested SHAs. No release authorization.

WP5 re-scores only G1-G12, P1.1-P1.10, P5.1-P5.8, P8.1-P8.9, P10.1-P10.11 and V1-V8 at the final runtime head. Other criterion states are explicitly historical, not new final-head executions. Every original Q check is preserved in the evidence JSON and prior report commits. Developer Launches are not acceptance evidence. No new waiver is inferred.

## Runs
| Run | Ruby | Cucumber | Mode | RSpec (examples/failures/pending) | Cucumber (scenarios/steps) | Launch IDs |
| --- | --- | --- | --- | --- | --- | --- |
| M5 | ruby 3.3.12 (2026-07-16 revision 0581089df9) [aarch64-linux] | 12.0.1 | offline plain | 1479/0/0 | 7/21 | Offline; PASS |
| M6 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | offline plain | 1479/0/0 | 7/21 | Offline; PASS |
| wp5-ci-final-20261101-c12.0.1-authored-baseline | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3229 |
| wp5-ci-final-20261101-c12.0.1-authored-plain-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2932, 2933 |
| wp5-ci-final-20261101-c12.0.1-authored-plain-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2998, 3000 |
| wp5-ci-final-20261101-c12.0.1-authored-rich-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3078, 3079 |
| wp5-ci-final-20261101-c12.0.1-authored-rich-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3151, 3152 |
| wp5-ci-final-20261101-c12.0.1-baseline | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3159, 3161, 3162, 3164, 3165, 3166, 3168, 3171, 3172, 3174, 3175, 3177, 3178, 3179, 3181, 3182, 3184, 3185, 3187, 3188, 3190, 3191, 3193, 3196, 3198, 3200, 3201, 3203, 3204, 3206, 3207, 3208, 3209, 3210, 3211, 3213, 3214, 3215, 3216, 3217 |
| wp5-ci-final-20261101-c12.0.1-default-batch1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3233, 3234, 3236 |
| wp5-ci-final-20261101-c12.0.1-framework-baseline | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3227 |
| wp5-ci-final-20261101-c12.0.1-framework-plain-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2929 |
| wp5-ci-final-20261101-c12.0.1-framework-plain-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2996 |
| wp5-ci-final-20261101-c12.0.1-framework-rich-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3077 |
| wp5-ci-final-20261101-c12.0.1-framework-rich-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3148 |
| wp5-ci-final-20261101-c12.0.1-plain-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2857, 2859, 2860, 2862, 2863, 2865, 2868, 2871, 2872, 2874, 2875, 2877, 2878, 2880, 2881, 2883, 2884, 2886, 2887, 2888, 2889, 2890, 2892, 2893, 2896, 2897, 2899, 2900, 2902, 2903, 2905, 2906, 2908, 2909, 2911, 2912, 2914, 2915, 2917, 2918 |
| wp5-ci-final-20261101-c12.0.1-plain-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2938, 2939, 2941, 2942, 2944, 2945, 2947, 2949, 2950, 2952, 2953, 2954, 2955, 2956, 2958, 2959, 2960, 2961, 2962, 2963, 2964, 2965, 2966, 2968, 2969, 2970, 2971, 2973, 2974, 2975, 2976, 2977, 2978, 2979, 2981, 2982, 2984, 2985, 2986, 2988 |
| wp5-ci-final-20261101-c12.0.1-rich-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3005, 3007, 3008, 3010, 3011, 3013, 3017, 3019, 3021, 3022, 3024, 3025, 3027, 3028, 3029, 3031, 3032, 3033, 3034, 3035, 3037, 3038, 3039, 3042, 3044, 3045, 3047, 3048, 3049, 3051, 3052, 3054, 3055, 3057, 3058, 3060, 3061, 3063, 3064, 3066 |
| wp5-ci-final-20261101-c12.0.1-rich-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3084, 3086, 3087, 3089, 3090, 3091, 3094, 3096, 3097, 3098, 3099, 3100, 3101, 3102, 3104, 3105, 3106, 3107, 3108, 3109, 3111, 3112, 3113, 3115, 3117, 3118, 3119, 3121, 3122, 3123, 3125, 3126, 3127, 3128, 3129, 3131, 3132, 3133, 3134, 3136 |
| wp5-ci-final-20261101-c12.0.1-supplement-baseline | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 3219, 3221, 3222, 3224, 3225 |
| wp5-ci-final-20261101-c12.0.1-supplement-plain-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2921, 2922, 2924, 2925, 2927 |
| wp5-ci-final-20261101-c12.0.1-supplement-plain-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | plain/default/baseline as named | Not a suite replacement | Fresh fixture outputs retained | 2990, 2991, 2992, 2993, 2994 |
| wp5-ci-final-20261101-c12.0.1-supplement-rich-1 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3068, 3070, 3072, 3073, 3075 |
| wp5-ci-final-20261101-c12.0.1-supplement-rich-2 | ruby 3.4.12 (2026-10-23 revision 366f5fdc00) +PRISM [aarch64-linux] | 12.0.1 | rich | Not a suite replacement | Fresh fixture outputs retained | 3138, 3140, 3141, 3143, 3144 |

The early contended timing attempt is retained but is not G11 acceptance proof. Native compound syntax is N/A on legacy only under Decision 4; explicit separate companions remain required. F06 is N/A on 1.x. Decision 8 applies only to the six named legacy NUL-preview files, not to other log/attachment losses.

## Results by criterion
| ID | Level | Verdict (PASS/FAIL/N/A/BLOCKED) | Evidence (log/item IDs, file, screenshot) | Note |
| --- | --- | --- | --- | --- |
| G1 | MUST | PASS | [668 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 1883 item IDs](#g1-id-ranges) | Compared F01 recursive parent graph is complete and acyclic: expected 3, actual 3; 668 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3159, 3161-3162, 3164-3166, 3168, 3171-3172, 3174-3175, 3177-3179, 3181-3182, 3184-3185, 3187-3188, 3190-3191, 3193, 3196, 3198, 3200-3201, 3203-3204, 3206-3211, 3216-3217, 3219, 3221-3222, 3224-3225, 3227, 3229, 3231, 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G2 | MUST | PASS | [90 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 762 log / 618 item IDs](#g2-id-ranges) | Compared F01 plain per-item levels/counts: expected Hash with 3 entries; SHA256 df97528031a28ffa (full value in JSON), actual Hash with 3 entries; SHA256 df97528031a28ffa (full value in JSON); 90 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081, 3159, 3161-3162, 3164-3166, 3168, 3171-3172, 3174-3175, 3177-3179, 3181-3182, 3184-3185, 3187-3188, 3190-3191, 3193, 3196, 3198, 3200-3201, 3203-3204, 3206-3211, 3216-3217, 3219, 3221-3222, 3224-3225, 3227, 3229, 3231; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G3 | MUST | PASS | [268 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 192 log / 529 item IDs](#g3-id-ranges) | Compared F01 plain downloaded attachment bytes/MIME/count: expected Array with 3 entries; SHA256 12d08726472edd3c (full value in JSON), actual Array with 3 entries; SHA256 12d08726472edd3c (full value in JSON); 268 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081, 3159, 3161-3162, 3164-3166, 3168, 3171-3172, 3174-3175, 3177-3179, 3181-3182, 3184-3185, 3187-3188, 3190-3191, 3193, 3196, 3198, 3200-3201, 3203-3204, 3206-3211, 3216-3217, 3219, 3221-3222, 3224-3225, 3227, 3229, 3231; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G4 | MUST | PASS | [86 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1008 log / 816 item IDs](#g4-id-ranges) | Compared F01 plain messages and metadata repeat: expected Array with 2 entries; SHA256 3aad1a4c0343ec47 (full value in JSON), actual Array with 2 entries; SHA256 3aad1a4c0343ec47 (full value in JSON); 86 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981, 2990-2994, 2996, 2998, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3138, 3140-3141, 3143-3144, 3148, 3151, 3155; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G5 | MUST | PASS | [799 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1042 log / 844 item IDs](#g5-id-ranges) | Compared F01 API forbidden-prefix filter: expected 0, actual 0; 799 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G6 | MUST | PASS | [48 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 257 log / 209 item IDs](#g6-id-ranges) | Compared F01 every plain HTML hit classified: expected [], actual []; 48 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G7 | MUST | PASS | [300 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1042 log / 844 item IDs](#g7-id-ranges) | Compared F01 forbidden-token scan: expected [], actual []; 300 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G8 | MUST | PASS | [900 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1042 log / 844 item IDs](#g8-id-ranges) | Compared F01 API secret-marker filter: expected 0, actual 0; 900 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G9 | MUST | PASS | [24 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#g9-id-ranges) | Compared Cucumber 12.0.1 fault-Accent-details: baseline fallback bytes, one warning, unchanged native result: expected [1,1,1,true,true,"/Users/nick/Documents/crr-2.0.1"], actual [1,1,1,true,true,"/Users/nick/Documents/crr-2.0.1"]; 24 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G10 | MUST | PASS | [6 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#g10-id-ranges) | Compared M5: exact final runtime full suite plus offline Cucumber, no failures/pending: expected ["3f20313c20b25071fbc49b31e1c6bc772bd599e4","PASS",0,0], actual ["3f20313c20b25071fbc49b31e1c6bc772bd599e4","PASS",0,0]; 6 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G11 | SHOULD | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#g11-id-ranges) | Compared F07 median-of-three wall time against baseline +10% and every F01-F18 Presentation p95 against <2 ms; Cucumber 12.0.1 baseline 1.429304 s, plain median 1.375825 s, -3.7417%, rich median 1.404972 s, -1.7024%, FailureCard p95 1.612124994 ms (2100 samples); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| G12 | MUST | PASS | [384 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 690 item IDs](#g12-id-ranges) | Compared F01 native NDJSON diff (generated IDs and clocks normalized): expected Array with 35 entries; SHA256 06e2cc72b5d56a2a (full value in JSON), actual Array with 35 entries; SHA256 06e2cc72b5d56a2a (full value in JSON); 384 criterion-specific checks (PASS); Launches 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.1 | MUST | PASS | [8 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 7 log / 7 item IDs](#p1-1-id-ranges) | Compared F04 raw baseline tail preserved: expected String with 7334 entries; SHA256 53bb9bbf3614517f (full value in JSON), actual String with 7334 entries; SHA256 53bb9bbf3614517f (full value in JSON); 8 criterion-specific checks (PASS); Launches 2862, 2924, 2992, 3072, 3141, 3164, 3222; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.2 | MUST | PASS | [36 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 34 log / 34 item IDs](#p1-2-id-ranges) | Compared all escaped exception titles, with only F14 back\slash full omission excepted by Decision15; Launches 2893, 2905-2906, 2925, 2968, 2993, 3073, 3143; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.3 | MUST | PASS | [23 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 22 log / 22 item IDs](#p1-3-id-ranges) | Compared F04 tail frame total: expected 62, actual 62; 23 criterion-specific checks (PASS); Launches 2862, 2893, 2900, 2902-2903, 2905-2906, 2908, 2924, 2929; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.4 | MUST | PASS | [48 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 25 log / 25 item IDs](#p1-4-id-ranges) | Compared Explicit framework-only input: first three framework frames, in input order: expected "first.rb:11   Framework.one\nsecond.rb:22  Framework.two\nthird.rb:33   Framework.three", actual "first.rb:11   Framework.one\nsecond.rb:22  Framework.two\nthird.rb:33   Framework.three"; 48 criterion-specific checks (PASS); Launches 2862, 2893, 2900, 2902-2903, 2905-2906, 2908, 2924, 2929, 2996, 3077, 3148; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.5 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p1-5-id-ranges) | Compared F16a continuation fenced before labelled project frames: expected true, actual true; 1 criterion-specific checks (PASS); Launches 2902; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.6 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 2 log / 2 item IDs](#p1-6-id-ranges) | Compared 12.0.1: literal title text and no data-created script/b elements: expected {"title":"✗ RuntimeError: <b>x</b>","script":0,"bold":0}, actual {"bold":0,"script":0,"title":"✗ RuntimeError: <b>x</b>"}; 2 criterion-specific checks (PASS); Launches 2893; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.7 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p1-7-id-ranges) | Compared F16f redacted error: expected false, actual false; 1 criterion-specific checks (PASS); Launches 2908; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.8 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p1-8-id-ranges) | Compared 12.0.1 S01-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-outer-fold-untouched: independently judged fresh screenshot: expected "PASS", actual "PASS"; 1 criterion-specific checks (PASS); Launches 2924; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.9 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p1-9-id-ranges) | Compared 12.0.1 S02-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-stack-trace: independently judged fresh screenshot: expected "PASS", actual "PASS"; 1 criterion-specific checks (PASS); Launches 2924; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P1.10 | SHOULD | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p1-10-id-ranges) | Compared F04 stable card before tail caption: expected String with 325 entries; SHA256 bee20d609d30790f (full value in JSON), actual String with 325 entries; SHA256 bee20d609d30790f (full value in JSON); 1 criterion-specific checks (PASS); Launches 2862; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P2.1 | MUST | PASS | [19 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 14 log / 14 item IDs](#p2-1-id-ranges) | Historical-only, not a new execution: Compared Every escaping matrix cell independently inspected: expected 14, actual 14; 19 criterion-specific checks (PASS); Launches 554; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P2.2 | MUST | PASS | [4 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 30 log / 47 item IDs](#p2-2-id-ranges) | Historical-only, not a new execution: Compared Data outside code has entity &lt;other&gt;: expected true, actual true; 4 criterion-specific checks (PASS); Launches 554; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P2.3 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#p2-3-id-ranges) | Historical-only, not a new execution: Compared M5 focused assertion evidence from the FULL suite: expected "At least 5 matching examples, all passed", actual Array with 9 entries; SHA256 93d6dc9b2876e934 (full value in JSON); 2 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P2.4 | MUST | PASS | [76 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 676 item IDs](#p2-4-id-ranges) | Historical-only, not a new execution: Compared F01 plain raw non-hook names: expected Array with 3 entries; SHA256 4f10eb6d07afd55d (full value in JSON), actual Array with 3 entries; SHA256 4f10eb6d07afd55d (full value in JSON); 76 criterion-specific checks (PASS); Launches 532-534, 536-540, 553-555, 560-566, 570-571, 614-616, 618-622, 635-637, 642-648, 652-653, 982-993, 1008-1019, 1107-1112, 1125-1130; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P3.1 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 486 log / 704 item IDs](#p3-1-id-ranges) | Historical-only, not a new execution: Compared Complete nested read API evidence covers no-prefix rule: expected 0, actual 0; 1 criterion-specific checks (PASS); Launches 532-534, 536-540, 553-555, 560-571, 614-616, 618-622, 635-637, 642-653, 737-739, 982-993, 1008-1019, 1107-1112, 1125-1130; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P3.2 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 6 log / 6 item IDs](#p3-2-id-ranges) | Historical-only, not a new execution: Compared F16a raw continuation fence: expected true, actual true; 2 criterion-specific checks (PASS); Launches 560, 993; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P3.3 | MUST | PASS | [27 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 116 log / 167 item IDs](#p3-3-id-ranges) | Historical-only, not a new execution: Compared F14 raw authored user log is byte-identical: expected 1, actual 1; 27 criterion-specific checks (PASS); Launches 554, 567-571, 718, 720-723, 731-735, 1086-1087, 1089, 1108-1111; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P3.4 | MUST | PASS | [10 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 7 log / 14 item IDs](#p3-4-id-ranges) | Historical-only, not a new execution: Compared Actual native Console observed for all four required families: expected ["F01","F04","F10a","F11a"], actual ["F01","F04","F10a","F11a"]; 10 criterion-specific checks (PASS); Launches 532, 541, 546, 939; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P4.1 | MUST | PASS | [8 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 20 item IDs](#p4-1-id-ranges) | Historical-only, not a new execution: Compared F02 plain/1 exact TABLE_ONLY_AMBER description: expected "`value` = `TABLE_ONLY_AMBER` · _Examples: Table-only substitution · line 12_", actual "`value` = `TABLE_ONLY_AMBER` · _Examples: Table-only substitution · line 12_"; 8 criterion-specific checks (PASS); Launches 938, 942, 946, 950; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P4.2 | MUST | PASS | [4 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 47 item IDs](#p4-2-id-ranges) | Historical-only, not a new execution: Compared All three Outline fallback shapes exercised: expected 3, actual 3; 4 criterion-specific checks (PASS); Launches 554; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P4.3 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 5 item IDs](#p4-3-id-ranges) | Historical-only, not a new execution: Compared Value/key chips each occupy one physical text line at 1100px: expected true, actual true; 2 criterion-specific checks (PASS); Launches 938; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P4.4 | MUST | PASS | [76 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 676 item IDs](#p4-4-id-ranges) | Historical-only, not a new execution: Compared F01 plain raw scenario names/parameters: expected [["features/presentation_ledger/qa_runtime/F01.feature:3","Scenario: F01",[]]], actual [["features/presentation_ledger/qa_runtime/F01.feature:3","Scenario: F01",[]]]; 76 criterion-specific checks (PASS); Launches 532-534, 536-540, 553-555, 560-566, 570-571, 614-616, 618-622, 635-637, 642-648, 652-653, 982-993, 1008-1019, 1107-1112, 1125-1130; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P5.1 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 3 log / 1 item IDs](#p5-1-id-ranges) | Compared F01 exact three caption/preview goldens: expected Array with 3 entries; SHA256 1b3d36d177c40565 (full value in JSON), actual Array with 3 entries; SHA256 1b3d36d177c40565 (full value in JSON); 1 criterion-specific checks (PASS); Launches 2857; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P5.2 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 10 log / 6 item IDs](#p5-2-id-ranges) | Compared F04 exact JPEG caption: expected "`after-failure.jpg` · JPEG · 754 × 790 · 36 KB", actual "`after-failure.jpg` · JPEG · 754 × 790 · 36 KB"; 3 criterion-specific checks (PASS); Launches 2862, 2871, 2909; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P5.3 | MUST | PASS | [200 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1042 log / 844 item IDs](#p5-3-id-ranges) | Compared F12 caller message precedes meta line: expected true, actual true; 200 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P5.4 | MUST | PASS | [200 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1042 log / 844 item IDs](#p5-4-id-ranges) | Compared F12 failure-evidence suffix: expected true, actual true; 200 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P5.5 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 4 log / 1 item IDs](#p5-5-id-ranges) | Compared F18 line truncation caption: expected true, actual true; 3 criterion-specific checks (PASS); Launches 2911; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P5.6 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 12 log / 4 item IDs](#p5-6-id-ranges) | Compared F17: batch size 1 and default emit identical owner-local filenames: expected Array with 6 entries; SHA256 83c883badfcabb5d (full value in JSON), actual Array with 6 entries; SHA256 83c883badfcabb5d (full value in JSON); 2 criterion-specific checks (PASS); Launches 2909, 3234; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P5.7 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 128 log / 478 item IDs](#p5-7-id-ranges) | Compared Owned API downloads match baseline count, MIME, filenames and SHA256: expected 0, actual 0; 1 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P5.8 | MUST | PASS | [7 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 6 log / 2 item IDs](#p5-8-id-ranges) | Compared 12.0.1 S06-wp5-ci-final-20261101-c12.0.1-f01-plain-captions-preview-download: actual caption/preview visual observation: expected "PASS", actual "PASS"; 7 criterion-specific checks (PASS); Launches 2857, 3005; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P6.1 | MUST | PASS | [68 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 120 item IDs](#p6-1-id-ranges) | Historical-only, not a new execution: Compared M5 focused assertion evidence from the FULL suite: expected "At least 1 matching examples, all passed", actual Array with 18 entries; SHA256 1842699a2573eb56 (full value in JSON); 68 criterion-specific checks (PASS); Launches 1104-1106, 1108, 1110, 1113-1115, 1119, 1122-1124, 1126, 1128, 1131-1133, 1137; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P6.2 | MUST | PASS | [76 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 676 item IDs](#p6-2-id-ranges) | Historical-only, not a new execution: Compared F01 plain hook types: expected [], actual []; 76 criterion-specific checks (PASS); Launches 532-534, 536-540, 553-555, 560-566, 570-571, 614-616, 618-622, 635-637, 642-648, 652-653, 982-993, 1008-1019, 1107-1112, 1125-1130; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P6.3 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 2 log / 5 item IDs](#p6-3-id-ranges) | Historical-only, not a new execution: Compared F04 JPEG belongs to After hook: expected ["AFTER_METHOD","After hook"], actual ["AFTER_METHOD","After hook"]; 1 criterion-specific checks (PASS); Launches 1107; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P6.4 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 12 item IDs](#p6-4-id-ranges) | Historical-only, not a new execution: Compared Judged native S07 screenshots: expected "At least one retained native image, all judged PASS", actual Array with 2 entries; SHA256 340a7d8f9a9f7792 (full value in JSON); 1 criterion-specific checks (PASS); Launches 556, 1104; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P7.1 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 4 log / 9 item IDs](#p7-1-id-ranges) | Historical-only, not a new execution: Compared AMBER native doc-first/table-first steps each equal exact P7 golden: expected Array with 2 entries; SHA256 07fe9ec18c682b44 (full value in JSON), actual Array with 2 entries; SHA256 07fe9ec18c682b44 (full value in JSON); 2 criterion-specific checks (PASS); Launches 534; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P7.2 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 2 log / 4 item IDs](#p7-2-id-ranges) | Historical-only, not a new execution: Compared F13 eight-column alignment golden: expected true, actual true; 3 criterion-specific checks (PASS); Launches 553; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P7.3 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 52 item IDs](#p7-3-id-ranges) | Historical-only, not a new execution: Compared F07 all fifty argument-free steps omit descriptions: expected [50,[]], actual [50,[]]; 3 criterion-specific checks (PASS); Launches 537; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P7.4 | MUST | PASS | [4 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 9 log / 8 item IDs](#p7-4-id-ranges) | Historical-only, not a new execution: Compared Declared/detected JSON DocString caption: expected true, actual true; 4 criterion-specific checks (PASS); Launches 566; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P7.5 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 4 log / 8 item IDs](#p7-5-id-ranges) | Historical-only, not a new execution: Compared plain-1 numeric columns computed right alignment: expected true, actual true; 3 criterion-specific checks (PASS); Launches 553, 635; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P8.1 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 2 log / 2 item IDs](#p8-1-id-ranges) | Compared F10a exact passed assertion: expected ["✓ Assertion passed · Order is accepted · expected `ACCEPTED`"], actual ["✓ Assertion passed · Order is accepted · expected `ACCEPTED`"]; 2 criterion-specific checks (PASS); Launches 2874, 2877; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.2 | MUST | PASS | [4 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 3 log / 3 item IDs](#p8-2-id-ranges) | Compared F10b long expected omitted from chip: expected false, actual false; 4 criterion-specific checks (PASS); Launches 2875, 2878, 2880; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.3 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p8-3-id-ranges) | Compared F10c multiline actual continuation: expected true, actual true; 1 criterion-specific checks (PASS); Launches 2877; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.4 | MUST | PASS | [5 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 4 log / 4 item IDs](#p8-4-id-ranges) | Compared F11b HTTP title: expected "## ⚠ GET /words → 404 · 31 ms", actual "## ⚠ GET /words → 404 · 31 ms"; 5 criterion-specific checks (PASS); Launches 2881, 2883-2884, 2886; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.5 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 5 log / 1 item IDs](#p8-5-id-ranges) | Compared F12 empty action card title: expected true, actual true; 2 criterion-specific checks (PASS); Launches 2889; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.6 | MUST | PASS | [300 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 906 log / 996 item IDs](#p8-6-id-ranges) | Compared F01 INFO headings: expected [], actual []; 300 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.7 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p8-7-id-ranges) | Compared F11f secret removed from title and URL chip: expected [false,true], actual [false,true]; 1 criterion-specific checks (PASS); Launches 2888; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.8 | MUST | PASS | [48 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 144 item IDs](#p8-8-id-ranges) | Compared F10a plain/1: baseline native/logger stdout bytes, excluding only Cucumber summary/stopwatch: expected String with 202 entries; SHA256 b72adc74b67a3429 (full value in JSON), actual String with 202 entries; SHA256 b72adc74b67a3429 (full value in JSON); 48 criterion-specific checks (PASS); Launches 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2889, 2952-2956, 2958-2964, 3022, 3024-3025, 3027-3029, 3031-3035, 3037, 3098-3102, 3104-3109, 3111; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P8.9 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#p8-9-id-ranges) | Compared M5: unchanged omission marker and public bounds verified by product and independent specs: expected "At least 2 matching examples, all passed", actual Array with 2 entries; SHA256 1d458e837c6a4ae3 (full value in JSON); 2 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P9.1 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 3 item IDs](#p9-1-id-ranges) | Historical-only, not a new execution: Compared F19d no generated context: expected ["",[]], actual ["",[]]; 1 criterion-specific checks (PASS); Launches 570; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P9.2 | MUST | PASS | [4 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 12 item IDs](#p9-2-id-ranges) | Historical-only, not a new execution: Compared F19a exact context attributes: expected [["ci.build","42"],["cucumber","12.0.1"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.4.12"],["sdk","2.0.1"],["workers","4"]], actual [["ci.build","42"],["cucumber","12.0.1"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.4.12"],["sdk","2.0.1"],["workers","4"]]; 4 criterion-specific checks (PASS); Launches 567, 569, 1088, 1090; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P9.3 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 3 item IDs](#p9-3-id-ranges) | Historical-only, not a new execution: Compared F19b exact context attributes: expected [["ci.build","42"],["cucumber","12.0.1"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.4.12"],["sdk","custom"],["workers","4"]], actual [["ci.build","42"],["cucumber","12.0.1"],["git.branch","feature/ledger"],["git.sha","e7dae2b"],["ruby","3.4.12"],["sdk","custom"],["workers","4"]]; 1 criterion-specific checks (PASS); Launches 568; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P9.4 | MUST | PASS | [7 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 15 item IDs](#p9-4-id-ranges) | Historical-only, not a new execution: Compared F19a context description: expected "Cucumber 12.0.1 · Ruby 3.4.12 · 4 workers · feature/ledger@e7dae2b", actual "Cucumber 12.0.1 · Ruby 3.4.12 · 4 workers · feature/ledger@e7dae2b"; 7 criterion-specific checks (PASS); Launches 567-569, 1088, 1090; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P9.5 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 3 item IDs](#p9-5-id-ranges) | Historical-only, not a new execution: Compared Judged native S10 screenshots: expected "At least one retained native image, all judged PASS", actual Array with 1 entries; SHA256 2ee69171ae7db78c (full value in JSON); 1 criterion-specific checks (PASS); Launches 567; runtime SHA ecf8c5aade5b6982f96083cb21c758db56b81b3f. |
| P10.1 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 10 log / 4 item IDs](#p10-1-id-ranges) | Compared F01: unset presentation adds no Tier 2 tags: expected [], actual []; 3 criterion-specific checks (PASS); Launches 3233-3234, 3236; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.2 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 1 log / 1 item IDs](#p10-2-id-ranges) | Compared F20 fancy: exactly one presentation warning: expected 1, actual 1; 2 criterion-specific checks (PASS); Launches 2918; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.3 | MUST | PASS | [258 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 258 log / 210 item IDs](#p10-3-id-ranges) | Compared F01 log 15804 exact tag/style vocabulary: expected [], actual []; 258 criterion-specific checks (PASS); Launches 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.4 | MUST | PASS | [33 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 33 log / 30 item IDs](#p10-4-id-ranges) | Compared F04 ERROR 0 first line: expected "## ✗ RuntimeError: INDEPENDENT\\_FULL\\_BACKTRACE\n", actual "## ✗ RuntimeError: INDEPENDENT\\_FULL\\_BACKTRACE\n"; 33 criterion-specific checks (PASS); Launches 3010, 3025, 3027-3028, 3032-3033, 3037, 3042, 3048-3049, 3051-3052, 3054-3055, 3072-3073, 3077; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.5 | MUST | PASS | [258 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 258 log / 210 item IDs](#p10-5-id-ranges) | Compared F01 log 0 rich byte budget: expected "<= 1076 bytes", actual 241; 258 criterion-specific checks (PASS); Launches 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.6 | MUST | PASS | [540 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 888 log / 744 item IDs](#p10-6-id-ranges) | Compared Paired log ownership and level counts: expected Hash with 1 entries; SHA256 aed9e705ae1289aa (full value in JSON), actual Hash with 1 entries; SHA256 aed9e705ae1289aa (full value in JSON); 540 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2933, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.7 | MUST | PASS | [290 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 1444 item IDs](#p10-7-id-ranges) | Compared F01 unchanged item metadata plain/rich: expected Array with 3 entries; SHA256 402d550fe0229c49 (full value in JSON), actual Array with 3 entries; SHA256 402d550fe0229c49 (full value in JSON); 290 criterion-specific checks (PASS); Launches 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.8 | MUST | PASS | [54 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 27 log / 51 item IDs](#p10-8-id-ranges) | Compared F04 log 15817 fence blank lines in details: expected true, actual true; 54 criterion-specific checks (PASS); Launches 3010, 3029, 3034, 3042, 3048-3049, 3051-3052, 3054-3055, 3058, 3072, 3077; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.9 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 2 log / 2 item IDs](#p10-9-id-ranges) | Compared F13 eight-column table has no TH span: expected false, actual false; 1 criterion-specific checks (PASS); Launches 3038; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.10 | MUST | PASS | [10 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 16 log / 9 item IDs](#p10-10-id-ranges) | Compared 12.0.1 S03-wp5-ci-final-20261101-c12.0.1-f04-frozen-rich-both-folds-expanded: visible rich pills/titles/folds, independently inspected: expected "PASS", actual "PASS"; 10 criterion-specific checks (PASS); Launches 3005, 3022, 3025, 3029, 3031-3032, 3037-3038, 3072; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| P10.11 | SHOULD | PASS | [4 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 6 log / 4 item IDs](#p10-11-id-ranges) | Compared 12.0.1: computed info pill contrast, WCAG sRGB relative luminance: expected ">= 4.5:1", actual 5.38234760973427; 4 criterion-specific checks (PASS); Launches 3005, 3022, 3025, 3031; runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V1 | MUST | PASS | [4 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v1-id-ranges) | Compared Every actual loaded SDK byte hash matches the exact final/baseline Git revision, not the QA branch: expected true, actual true; 4 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V2 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v2-id-ranges) | Compared Frozen-baseline lock diff contains only the gem's own PATH version: expected ["-    reportportal-cucumber-ruby (2.0.0)","+    reportportal-cucumber-ruby (2.0.1)"], actual ["-    reportportal-cucumber-ruby (2.0.0)","+    reportportal-cucumber-ruby (2.0.1)"]; 1 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V3 | MUST | PASS | [2 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v3-id-ranges) | Compared Fresh gem build from final feature tree, locally verified and never published: expected ["reportportal-cucumber-ruby-2.0.1.gem","2.0.1",true,"3f20313c20b25071fbc49b31e1c6bc772bd599e4"], actual ["reportportal-cucumber-ruby-2.0.1.gem","2.0.1",true,"3f20313c20b25071fbc49b31e1c6bc772bd599e4"]; 2 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V4 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v4-id-ranges) | Compared CHANGELOG begins with new patch release and owner SemVer rationale: expected true, actual true; 3 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V5 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v5-id-ranges) | Compared Both switches and Presentation section documented at final SHA: expected [true,true,true], actual [true,true,true]; 1 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V6 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v6-id-ranges) | Compared Decision16: baseline-to-final Helm is untouched and only the exactly audited validation workflow differs: expected ["3f20313c20b25071fbc49b31e1c6bc772bd599e4","PASS",[".github/workflows/validate.yml"]], actual ["3f20313c20b25071fbc49b31e1c6bc772bd599e4","PASS",[".github/workflows/validate.yml"]]; 1 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V7 | MUST | PASS | [3 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v7-id-ranges) | Compared Protected heads still equal original independent observations: expected Hash with 3 entries; SHA256 0dc182c26f5fbe8c (full value in JSON), actual Hash with 3 entries; SHA256 0dc182c26f5fbe8c (full value in JSON); 3 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |
| V8 | MUST | PASS | [1 checks](assets/presentation-ledger-2.0.1-acceptance.json); [all 0 log / 0 item IDs](#v8-id-ranges) | Compared C0-C8 semantic implementation order, P10 isolated stage retained: expected true, actual true; 1 criterion-specific checks (PASS); Launch N/A (U; no live proof claimed); runtime SHA 3f20313c20b25071fbc49b31e1c6bc772bd599e4. |

## Defects
Decision15 explicitly excepts only the named F14 backslash failure title while retaining complete fail-closed omission. Original title-comparison mismatches remain in the evidence; no golden/redaction change or broader exception is applied.

| # | Severity | Criterion | Fixture | Expected | Actual | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
No demonstrated fresh product failure so far; BLOCKED criteria are missing proof, not PASS.

Retained earlier failures are not waived: the independent Ruby 3.1 focused run observed 0.1342089579993626 s against the unchanged <0.12 s assertion, without the handle_error diagnostic observer. Its original result and command provenance remain in `docs/reviews/assets/wp5-final-20261101/spec-repair-ruby31-focused.json` and `.provenance.json` on the 1.x QA branch. The original RSpec keyword-wrapper failures remain in their original matrix evidence. Fresh all-six-cell evidence is required for G10.

Original remote CI attempt-1 failures (2x SIGINT spooled=0 and frozen 1.3.1 SIGINT/HTTP-400 receipt failures) remain separately recorded in `docs/reviews/assets/wp5-ci-final-20261101/ci-attempt1-independent-review.json`. Unchanged attempt-2 success does not establish their cause or waive an assertion. Independent classification: the legacy failures predate Ledger; budget/scheduling sensitivity is a supported explanation, not proof of runner-only causation or a demonstrated repaired SDK defect.

Evidence-integrity findings, separate from SDK defects: the independent publication review found three S2 packaging gaps (quiet G11 root omitted, historical raw references not selected, and portable reproduction setup missing). The bounded curator/reproduction-guide correction passed 35 synthetic assertions and Master review; original findings remain in the publication-audit sidecar. Final selection and secret/size/path audit remain a publication gate, not an SDK waiver.

QA harness observations are retained separately: an initial package-binding helper rejected comma-formatted counts despite identical package/runtime bytes; its failed result remains on 1.x. Console replay attempt 1 performed only GET and stopped because list severity `error` differs from direct GET `ERROR`; identical 10,492-byte messages were independently hash-verified before attempt 2. Only severity casing is canonicalized, not message content.

Historical-index repair preserves every committed Q and WP5 object at its original ID; 17 later in-progress legacy variants are retained inline under unique `DRAFT-HISTORY-*` IDs with full original draft objects and explicit mappings. The Master before-repair witness is unchanged. No old failure, input, expected/actual value or verdict is discarded.

The fixture-only containment test correction additionally passes 37 unchanged-security assertions with a QA-local TMPDIR; the earlier host failure and separate unchanged-test container pass remain retained. Production curator source is unchanged by that fixture correction.

## Screenshots
Historical screenshots remain at their original Launches/runtime and are not relabelled final. Fresh final-head captures and DOM observations are indexed separately below.
- S01-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-outer-fold-untouched: Launch 2924; item 23502; log 15316; PASS; [image](assets/presentation-ledger-2.0.1/S01-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-outer-fold-untouched.png).
- S02-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-stack-trace: Launch 2924; item 23502; log 15316; PASS; [image](assets/presentation-ledger-2.0.1/S02-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-stack-trace.png).
- S03-wp5-ci-final-20261101-c12.0.1-f04-frozen-rich-both-folds-expanded: Launch 3072; item 24666; log 16101; PASS; [image](assets/presentation-ledger-2.0.1/S03-wp5-ci-final-20261101-c12.0.1-f04-frozen-rich-both-folds-expanded.png).
- S06-wp5-ci-final-20261101-c12.0.1-f01-plain-captions-preview-download: Launch 2857; item 23022; log 15017, 15018, 15019; PASS; [image](assets/presentation-ledger-2.0.1/S06-wp5-ci-final-20261101-c12.0.1-f01-plain-captions-preview-download.png).
- S06-wp5-ci-final-20261101-c12.0.1-f01-plain-captions-preview-download-preview-modal: Launch 2857; item 23022; log 15017, 15018, 15019; PASS; [image](assets/presentation-ledger-2.0.1/S06-wp5-ci-final-20261101-c12.0.1-f01-plain-captions-preview-download-preview-modal.png).
- S06-wp5-ci-final-20261101-c12.0.1-f01-rich-captions-preview-download: Launch 3005; item 24186; log 15804, 15805, 15806; PASS; [image](assets/presentation-ledger-2.0.1/S06-wp5-ci-final-20261101-c12.0.1-f01-rich-captions-preview-download.png).
- S08-wp5-ci-final-20261101-c12.0.1-f13-plain-numeric-table: Launch 2890; item 23279; log 15183, 15184; PASS; [image](assets/presentation-ledger-2.0.1/S08-wp5-ci-final-20261101-c12.0.1-f13-plain-numeric-table.png).
- S08-wp5-ci-final-20261101-c12.0.1-f13-rich-numeric-table: Launch 3038; item 24469; log 15983, 15984; PASS; [image](assets/presentation-ledger-2.0.1/S08-wp5-ci-final-20261101-c12.0.1-f13-rich-numeric-table.png).
- S09-wp5-ci-final-20261101-c12.0.1-f10a-plain-cards-expanded: Launch 2874; item 23186; log 15129; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f10a-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f10a-rich-cards-expanded: Launch 3022; item 24350; log 15916; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f10a-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f10c-plain-cards-expanded: Launch 2877; item 23195; log 15132; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f10c-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f10c-rich-cards-expanded: Launch 3025; item 24359; log 15923; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f10c-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f11a-plain-cards-expanded: Launch 2881; item 23207; log 15140; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f11a-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f11a-rich-cards-expanded: Launch 3029; item 24372; log 15928; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f11a-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f11a-rich-cards-expanded-headers-open: Launch 3029; item 24372; log 15928; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f11a-rich-cards-expanded-headers-open.png).
- S09-wp5-ci-final-20261101-c12.0.1-f11b-plain-cards-expanded: Launch 2883; item 23214; log 15143; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f11b-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f11b-rich-cards-expanded: Launch 3031; item 24395; log 15942; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f11b-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f11c-plain-cards-expanded: Launch 2884; item 23217; log 15144; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f11c-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f11c-rich-cards-expanded: Launch 3032; item 24419; log 15957; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f11c-rich-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f12-plain-cards-expanded: Launch 2889; item 23276; log 15178, 15180, 15179, 15181, 15182; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f12-plain-cards-expanded.png).
- S09-wp5-ci-final-20261101-c12.0.1-f12-rich-cards-expanded: Launch 3037; item 24452; log 15971, 15972, 15975, 15973, 15974; PASS; [image](assets/presentation-ledger-2.0.1/S09-wp5-ci-final-20261101-c12.0.1-f12-rich-cards-expanded.png).
- S04-wp5-ci-final-20261101-c12.0.1-f03-plain-escaped-table: Launch 2860; item 23037; log 15025, 15026, 15027, 15028; PASS; [image](assets/presentation-ledger-2.0.1/S04-wp5-ci-final-20261101-c12.0.1-f03-plain-escaped-table.png).
- S04-wp5-ci-final-20261101-c12.0.1-f14-plain-escaped-table: Launch 2892; item 23286; log 15186, 15188, 15190, 15191, 15193, 15194, 15196, 15198, 15200, 15201, 15203, 15205, 15206, 15208, 15210, 15211, 15213, 15214, 15216, 15218, 15219, 15220, 15221, 15222, 15223, 15224, 15225, 15226, 15227, 15228; PASS; [image](assets/presentation-ledger-2.0.1/S04-wp5-ci-final-20261101-c12.0.1-f14-plain-escaped-table.png).
- S05-wp5-ci-final-20261101-c12.0.1-f02-golden-plain-suite-list: Launch 2922; item 23493; log 15313, 15314; PASS; [image](assets/presentation-ledger-2.0.1/S05-wp5-ci-final-20261101-c12.0.1-f02-golden-plain-suite-list.png).
- S07-wp5-ci-final-20261101-c12.0.1-f15-plain-hook-rows: Launch 2896; item 23397; log 15250, 15251, 15252, 15253; PASS; [image](assets/presentation-ledger-2.0.1/S07-wp5-ci-final-20261101-c12.0.1-f15-plain-hook-rows.png).
- S10-wp5-ci-final-20261101-c12.0.1-f19a-plain-launch-list: Launch 2912; item 23458; log 15288; PASS; [image](assets/presentation-ledger-2.0.1/S10-wp5-ci-final-20261101-c12.0.1-f19a-plain-launch-list.png).
- S11-wp5-ci-final-20261101-c12.0.1-f01-plain-markdown-off-then-restored: Launch 2857; item 23022; log 15017, 15018, 15019; PASS; [image](assets/presentation-ledger-2.0.1/S11-wp5-ci-final-20261101-c12.0.1-f01-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-markdown-off-then-restored: Launch 2924; item 23502; log 15316, 15317; PASS; [image](assets/presentation-ledger-2.0.1/S11-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c12.0.1-f10a-plain-markdown-off-then-restored: Launch 2874; item 23186; log 15129; PASS; [image](assets/presentation-ledger-2.0.1/S11-wp5-ci-final-20261101-c12.0.1-f10a-plain-markdown-off-then-restored.png).
- S11-wp5-ci-final-20261101-c12.0.1-f11a-plain-markdown-off-then-restored: Launch 2881; item 23207; log 15140; PASS; [image](assets/presentation-ledger-2.0.1/S11-wp5-ci-final-20261101-c12.0.1-f11a-plain-markdown-off-then-restored.png).
- S12-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-console-blocked-nested-ui: Launch 2924; item 23502; log 15316, 15317; BLOCKED; [image](assets/presentation-ledger-2.0.1/S12-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-console-blocked-nested-ui.png).
- S12-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-console-flat-Decision17: Launch 3804; item 30408; log 19747; PASS; [image](assets/presentation-ledger-2.0.1/S12-wp5-ci-final-20261101-c12.0.1-f04-frozen-plain-console-flat-Decision17.png).

## Exact ID Ranges
Every range below is inclusive and round-trip checked; gaps and singletons are preserved, and the complete uncompressed arrays remain in the evidence JSON.

<a id="g1-id-ranges"></a>
<details>
<summary>G1: 244 Launch, 1883 item, 0 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3159, 3161-3162, 3164-3166, 3168, 3171-3172, 3174-3175, 3177-3179, 3181-3182, 3184-3185, 3187-3188, 3190-3191, 3193, 3196, 3198, 3200-3201, 3203-3204, 3206-3211, 3216-3217, 3219, 3221-3222, 3224-3225, 3227, 3229, 3231, 3233-3234, 3236

Items: 23021-23023, 23027-23044, 23048-23065, 23068, 23070-23086, 23089, 23091-23131, 23135-23141, 23144-23145, 23147-23168, 23172-23181, 23185-23190, 23193, 23195-23199, 23203-23208, 23212, 23214-23219, 23221-23222, 23244-23245, 23247, 23268-23270, 23275-23281, 23285-23286, 23288, 23290, 23293-23295, 23298-23299, 23302, 23304-23305, 23307, 23310-23312, 23315-23316, 23319-23320, 23322, 23324, 23327-23329, 23332-23333, 23336-23338, 23341-23362, 23367-23368, 23371-23392, 23396-23404, 23409-23416, 23421-23426, 23430-23435, 23439-23445, 23449-23459, 23463-23468, 23471, 23473-23477, 23490-23497, 23501-23508, 23512-23516, 23520-23522, 23529-23558, 23562-23569, 23578-23580, 23583-23591, 23595-23608, 23614-23686, 23693-23723, 23735-23744, 23751-23774, 23787-23789, 23810-23869, 23872-23873, 23875-23914, 23923, 23925-23926, 23929, 23936-23954, 23971-23973, 23975-23982, 23985, 23987-23988, 23991-23996, 24006, 24008, 24010, 24036-24037, 24039, 24060, 24062-24063, 24065, 24067, 24081-24093, 24125-24127, 24135-24137, 24139, 24141-24142, 24147-24178, 24185-24187, 24191-24207, 24209, 24212-24221, 24224-24225, 24227-24242, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24302-24332, 24336-24342, 24346-24351, 24355-24360, 24364, 24366-24373, 24393, 24395, 24397, 24417, 24419, 24421, 24427-24435, 24451-24453, 24468-24502, 24505-24507, 24509-24510, 24512, 24514, 24516-24524, 24528-24530, 24532-24557, 24562-24570, 24573-24576, 24578-24584, 24588-24593, 24597-24602, 24606-24617, 24621-24626, 24631-24636, 24645-24647, 24651-24652, 24654, 24657-24661, 24665-24672, 24676-24680, 24684-24689, 24691, 24693-24694, 24696-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24750-24752, 24756-24765, 24768-24770, 24772, 24774, 24776-24850, 24853-24855, 24857, 24859, 24862, 24865-24866, 24868, 24870, 24872, 24874-24875, 24877-24878, 24881-24882, 24885-24904, 24911-24935, 24939-24954, 24956, 24958, 24974-25027, 25045-25073, 25079-25091, 25113-25122, 25133, 25135-25136, 25155-25156, 25158, 25179, 25181-25182, 25184-25195, 25204, 25206-25207, 25230-25238, 25246-25248, 25252-25254, 25258-25267, 25271-25278, 25288-25290, 25297-25302, 25309-25328, 25331-25333, 25335-25343, 25350-25352, 25354, 25356-25357, 25359-25360, 25362-25374, 25389, 25391-25392, 25394-25395, 25419-25421, 25423, 25425, 25428-25429, 25432-25433, 25436-25471, 25474-25475, 25477-25478, 25481-25482, 25485, 25487, 25489, 25491, 25493-25494, 25497-25498, 25501-25502, 25505-25506, 25509-25510, 25513-25514, 25517-25518, 25521-25522, 25525-25526, 25529-25542, 25544, 25546-25547, 25549, 25551, 25553-25554, 25556-25565, 25570-25579, 25584-25589, 25592-25594, 25596-25599, 25601-25602, 25605-25610, 25614-25619, 25623-25625, 25627, 25629-25630, 25632-25634, 25637-25640, 25643-25669, 25672-25673, 25675-25676, 25678, 25680, 25682, 25684-25685, 25687-25697, 25701-25729, 25733-25738, 25742-25748, 25752-25758, 25762-25785, 25798-25803, 25821-25823, 25829-25838, 25842-25849, 25855-25857, 25864-25866, 25878-25888, 25890, 25892, 25894-25896, 25900-25922, 25926-25928

Logs: N/A

</details>

<a id="g2-id-ranges"></a>
<details>
<summary>G2: 135 Launch, 618 item, 762 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081, 3159, 3161-3162, 3164-3166, 3168, 3171-3172, 3174-3175, 3177-3179, 3181-3182, 3184-3185, 3187-3188, 3190-3191, 3193, 3196, 3198, 3200-3201, 3203-3204, 3206-3211, 3216-3217, 3219, 3221-3222, 3224-3225, 3227, 3229, 3231

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23541, 23544-23558, 23562-23569, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 25352, 25357, 25360, 25363, 25365, 25368, 25370, 25372, 25374, 25392, 25395, 25421, 25425, 25429, 25433, 25437, 25439, 25441, 25443, 25445, 25447, 25450-25471, 25474-25475, 25477-25478, 25481-25482, 25485, 25487, 25489, 25491, 25493-25494, 25497-25498, 25501-25502, 25505-25506, 25509-25510, 25513-25514, 25517-25518, 25521-25522, 25525-25526, 25531, 25533, 25535, 25537, 25539, 25541, 25544, 25547, 25551, 25554, 25557, 25559, 25561, 25563, 25565, 25572, 25574, 25576, 25579, 25586, 25589, 25594, 25598, 25602, 25607, 25610, 25616, 25619, 25625, 25630, 25634, 25639-25640, 25645-25646, 25648-25649, 25651-25652, 25654-25655, 25657-25658, 25660-25661, 25663-25664, 25666-25667, 25669, 25672, 25675-25676, 25680, 25682, 25685, 25687, 25689-25690, 25692-25693, 25695, 25697, 25703, 25705, 25707, 25709, 25711, 25713, 25715, 25717, 25719, 25721, 25723, 25725, 25727, 25729, 25735-25738, 25744, 25747-25748, 25754-25755, 25758, 25764, 25767, 25770, 25773, 25776-25777, 25780-25785, 25800, 25803, 25823, 25831, 25833, 25836, 25838, 25844, 25847, 25849, 25857, 25866, 25885, 25887-25888, 25890, 25892, 25894-25896, 25900-25915

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15287, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15333, 15335-15358, 15362-15373, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16116, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16570-16573, 16575, 16577-16582, 16592, 16594, 16610, 16612, 16615, 16617, 16619-16658, 16660-16661, 16663-16664, 16666-16667, 16669-16670, 16672-16673, 16675-16676, 16678-16679, 16681-16683, 16685, 16687-16689, 16691, 16693-16695, 16697, 16699-16706, 16709, 16711, 16713-16717, 16720-16725, 16728-16730, 16732-16733, 16735-16736, 16738-16739, 16741-16742, 16744-16750, 16757-16775, 16780, 16783, 16785, 16787, 16789-16795, 16797-16810, 16812-16815, 16817-16821, 16823-16825, 16827-16845, 16852-16853, 16862-16864, 16867-16870, 16872-16874, 16877, 16882-16889, 16897-16904, 16906-16909, 16911-16914, 16917-16936

</details>

<a id="g3-id-ranges"></a>
<details>
<summary>G3: 135 Launch, 529 item, 192 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081, 3159, 3161-3162, 3164-3166, 3168, 3171-3172, 3174-3175, 3177-3179, 3181-3182, 3184-3185, 3187-3188, 3190-3191, 3193, 3196, 3198, 3200-3201, 3203-3204, 3206-3211, 3216-3217, 3219, 3221-3222, 3224-3225, 3227, 3229, 3231

Items: 23023, 23027-23044, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23185-23190, 23193, 23195-23199, 23203-23208, 23212, 23214-23219, 23221-23222, 23244-23245, 23247, 23268-23270, 23277-23281, 23285-23286, 23288, 23290, 23293-23295, 23298-23299, 23302, 23304-23305, 23307, 23310-23312, 23315-23316, 23319-23320, 23322, 23324, 23327-23329, 23332-23333, 23336-23338, 23341-23362, 23367-23368, 23371-23392, 23396-23404, 23409-23416, 23421-23426, 23430-23435, 23439-23441, 23444-23445, 23451, 23471, 23473-23477, 23492-23497, 23505-23508, 23512-23516, 23520-23522, 23529-23531, 23547-23550, 24187, 24191-24207, 24209, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24255, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348-24351, 24355-24360, 24364, 24366-24373, 24393, 24395, 24397, 24417, 24419, 24421, 24427-24435, 24453, 24468-24502, 24505-24507, 24509-24510, 24512, 24514, 24516-24524, 24528-24530, 24532-24557, 24562-24570, 24573-24576, 24578-24584, 24588-24593, 24597-24602, 24608-24609, 24612, 24634-24636, 24645-24647, 24654, 24657-24661, 24669-24672, 24676-24680, 24684-24689, 24708-24711, 25352, 25395, 25421, 25425, 25429, 25433, 25437, 25439, 25441, 25443, 25445, 25447, 25450-25459, 25531, 25533, 25535, 25537, 25539, 25541, 25544, 25547, 25551, 25554, 25557, 25559, 25561, 25563, 25565, 25572, 25574, 25576, 25579, 25634, 25776-25777, 25780, 25823, 25838, 25892, 25894-25896

Logs: 15017-15019, 15031-15037, 15039-15042, 15044, 15046, 15048, 15050, 15052, 15054, 15056, 15058, 15060, 15063, 15105-15108, 15110-15120, 15122-15125, 15179-15180, 15182, 15272-15277, 15279-15282, 15310-15312, 15317, 15344, 15346, 15348, 15350, 15804-15806, 15818-15821, 15823-15829, 15831, 15833, 15835, 15838, 15840, 15842-15843, 15846, 15848, 15850, 15893-15907, 15909-15911, 15913, 15972, 15974-15975, 16057-16066, 16094-16096, 16102, 16130, 16132, 16134, 16136, 16570-16572, 16594, 16610, 16612, 16615, 16617, 16619-16624, 16626, 16628, 16630-16631, 16634, 16636, 16638, 16640, 16642, 16644, 16699-16706, 16709, 16711, 16713-16717, 16720-16723, 16745-16746, 16748, 16831-16840, 16862-16864, 16870, 16907, 16909, 16912, 16914

</details>

<a id="g4-id-ranges"></a>
<details>
<summary>G4: 172 Launch, 816 item, 1008 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981, 2990-2994, 2996, 2998, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3138, 3140-3141, 3143-3144, 3148, 3151, 3155

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23541, 23544-23558, 23562-23569, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23606, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756, 23759, 23762, 23765, 23768, 23771, 23774, 23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 23904-23907, 23910, 23913-23914, 23926, 23929, 23938, 23941, 23944, 23947, 23950, 23953-23954, 23973, 23975-23979, 24039, 24063, 24067, 24083, 24085, 24088, 24091, 24093, 24127, 24137, 24155-24178, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24781, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926, 24929, 24932, 24935, 24941, 24944, 24947, 24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25047, 25049, 25051, 25053, 25055, 25057, 25059, 25061, 25063, 25065, 25067, 25069, 25071, 25073, 25081-25084, 25087, 25090-25091, 25115-25116, 25119, 25122, 25136, 25158, 25182, 25186-25187, 25190-25195, 25254, 25260, 25262, 25265, 25267, 25273, 25276, 25278, 25290, 25299, 25311, 25314, 25317, 25320-25328, 25331-25333, 25335-25343

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15287, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15333, 15335-15358, 15362-15373, 15377-15379, 15381-15384, 15386-15391, 15394-15463, 15468-15482, 15490-15495, 15500-15507, 15510, 15545-15584, 15588-15609, 15614, 15616, 15620-15630, 15639-15647, 15689-15691, 15713, 15716, 15730-15734, 15750, 15754-15761, 15766-15801, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16116, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16167-16169, 16171-16175, 16177, 16179-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16293, 16297-16302, 16311-16347, 16356-16369, 16372-16380, 16391-16394, 16413, 16434, 16456, 16458-16472, 16498-16500, 16502-16505, 16507-16509, 16513, 16516-16523, 16527-16547, 16549-16563

</details>

<a id="g5-id-ranges"></a>
<details>
<summary>G5: 199 Launch, 844 item, 1042 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23534, 23541, 23544-23558, 23562-23569, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23606, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756, 23759, 23762, 23765, 23768, 23771, 23774, 23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 23904-23907, 23910, 23913-23914, 23926, 23929, 23938, 23941, 23944, 23947, 23950, 23953-23954, 23973, 23975-23979, 23982, 23988, 23993, 23996, 24010, 24039, 24063, 24067, 24083, 24085, 24088, 24091, 24093, 24127, 24137, 24142, 24155-24178, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24781, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926, 24929, 24932, 24935, 24941, 24944, 24947, 24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25047, 25049, 25051, 25053, 25055, 25057, 25059, 25061, 25063, 25065, 25067, 25069, 25071, 25073, 25081-25084, 25087, 25090-25091, 25115-25116, 25119, 25122, 25136, 25158, 25182, 25186-25187, 25190-25195, 25207, 25232, 25235, 25238, 25248, 25254, 25260, 25262, 25265, 25267, 25273, 25276, 25278, 25290, 25299, 25302, 25311, 25314, 25317, 25320-25328, 25331-25333, 25335-25343, 25918, 25921-25922, 25928

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15358, 15362-15373, 15377-15379, 15381-15384, 15386-15391, 15394-15463, 15468-15482, 15490-15495, 15500-15507, 15510, 15545-15584, 15588-15609, 15614, 15616, 15620-15630, 15639-15648, 15650, 15652-15653, 15658, 15689-15691, 15713, 15716, 15730-15734, 15750, 15754-15762, 15766-15801, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16167-16169, 16171-16175, 16177, 16179-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16293, 16297-16302, 16311-16347, 16356-16369, 16372-16380, 16391-16394, 16413, 16434, 16456, 16458-16472, 16477, 16489-16491, 16495, 16498-16500, 16502-16505, 16507-16509, 16513, 16516-16524, 16527-16547, 16549-16563, 16937-16945, 16949

</details>

<a id="g6-id-ranges"></a>
<details>
<summary>G6: 48 Launch, 209 item, 257 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23541, 23544-23558, 23562-23569

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15333, 15335-15358, 15362-15373

</details>

<a id="g7-id-ranges"></a>
<details>
<summary>G7: 199 Launch, 844 item, 1042 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23534, 23541, 23544-23558, 23562-23569, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23606, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756, 23759, 23762, 23765, 23768, 23771, 23774, 23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 23904-23907, 23910, 23913-23914, 23926, 23929, 23938, 23941, 23944, 23947, 23950, 23953-23954, 23973, 23975-23979, 23982, 23988, 23993, 23996, 24010, 24039, 24063, 24067, 24083, 24085, 24088, 24091, 24093, 24127, 24137, 24142, 24155-24178, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24781, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926, 24929, 24932, 24935, 24941, 24944, 24947, 24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25047, 25049, 25051, 25053, 25055, 25057, 25059, 25061, 25063, 25065, 25067, 25069, 25071, 25073, 25081-25084, 25087, 25090-25091, 25115-25116, 25119, 25122, 25136, 25158, 25182, 25186-25187, 25190-25195, 25207, 25232, 25235, 25238, 25248, 25254, 25260, 25262, 25265, 25267, 25273, 25276, 25278, 25290, 25299, 25302, 25311, 25314, 25317, 25320-25328, 25331-25333, 25335-25343, 25918, 25921-25922, 25928

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15358, 15362-15373, 15377-15379, 15381-15384, 15386-15391, 15394-15463, 15468-15482, 15490-15495, 15500-15507, 15510, 15545-15584, 15588-15609, 15614, 15616, 15620-15630, 15639-15648, 15650, 15652-15653, 15658, 15689-15691, 15713, 15716, 15730-15734, 15750, 15754-15762, 15766-15801, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16167-16169, 16171-16175, 16177, 16179-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16293, 16297-16302, 16311-16347, 16356-16369, 16372-16380, 16391-16394, 16413, 16434, 16456, 16458-16472, 16477, 16489-16491, 16495, 16498-16500, 16502-16505, 16507-16509, 16513, 16516-16524, 16527-16547, 16549-16563, 16937-16945, 16949

</details>

<a id="g8-id-ranges"></a>
<details>
<summary>G8: 199 Launch, 844 item, 1042 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23534, 23541, 23544-23558, 23562-23569, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23606, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756, 23759, 23762, 23765, 23768, 23771, 23774, 23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 23904-23907, 23910, 23913-23914, 23926, 23929, 23938, 23941, 23944, 23947, 23950, 23953-23954, 23973, 23975-23979, 23982, 23988, 23993, 23996, 24010, 24039, 24063, 24067, 24083, 24085, 24088, 24091, 24093, 24127, 24137, 24142, 24155-24178, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24781, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926, 24929, 24932, 24935, 24941, 24944, 24947, 24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25047, 25049, 25051, 25053, 25055, 25057, 25059, 25061, 25063, 25065, 25067, 25069, 25071, 25073, 25081-25084, 25087, 25090-25091, 25115-25116, 25119, 25122, 25136, 25158, 25182, 25186-25187, 25190-25195, 25207, 25232, 25235, 25238, 25248, 25254, 25260, 25262, 25265, 25267, 25273, 25276, 25278, 25290, 25299, 25302, 25311, 25314, 25317, 25320-25328, 25331-25333, 25335-25343, 25918, 25921-25922, 25928

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15358, 15362-15373, 15377-15379, 15381-15384, 15386-15391, 15394-15463, 15468-15482, 15490-15495, 15500-15507, 15510, 15545-15584, 15588-15609, 15614, 15616, 15620-15630, 15639-15648, 15650, 15652-15653, 15658, 15689-15691, 15713, 15716, 15730-15734, 15750, 15754-15762, 15766-15801, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16167-16169, 16171-16175, 16177, 16179-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16293, 16297-16302, 16311-16347, 16356-16369, 16372-16380, 16391-16394, 16413, 16434, 16456, 16458-16472, 16477, 16489-16491, 16495, 16498-16500, 16502-16505, 16507-16509, 16513, 16516-16524, 16527-16547, 16549-16563, 16937-16945, 16949

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
<summary>G12: 96 Launch, 690 item, 0 log IDs</summary>

Launches: 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152

Items: 24185-24187, 24191-24207, 24209, 24212-24221, 24224-24225, 24227-24242, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24302-24332, 24336-24342, 24346-24351, 24355-24360, 24364, 24366-24373, 24393, 24395, 24397, 24417, 24419, 24421, 24427-24435, 24451-24453, 24468-24502, 24505-24507, 24509-24510, 24512, 24514, 24516-24524, 24528-24530, 24532-24557, 24562-24570, 24573-24576, 24578-24584, 24588-24593, 24597-24602, 24606-24617, 24621-24626, 24631-24636, 24645-24647, 24651-24652, 24654, 24657-24661, 24665-24672, 24676-24680, 24684-24689, 24691, 24693-24694, 24750-24752, 24756-24765, 24768-24770, 24772, 24774, 24776-24850, 24853-24855, 24857, 24859, 24862, 24865-24866, 24868, 24870, 24872, 24874-24875, 24877-24878, 24881-24882, 24885-24904, 24911-24935, 24939-24954, 24956, 24958, 24974-25027, 25045-25073, 25079-25091, 25113-25122, 25133, 25135-25136, 25155-25156, 25158, 25179, 25181-25182, 25184-25195, 25204, 25206-25207, 25230-25238, 25246-25248, 25252-25254, 25258-25267, 25271-25278, 25288-25290, 25297-25302

Logs: N/A

</details>

<a id="p1-1-id-ranges"></a>
<details>
<summary>P1.1: 7 Launch, 7 item, 7 log IDs</summary>

Launches: 2862, 2924, 2992, 3072, 3141, 3164, 3222

Items: 23050, 23503, 24083, 24667, 25265, 25392, 25836

Logs: 15030, 15316, 15730, 16101, 16504, 16592, 16869

</details>

<a id="p1-2-id-ranges"></a>
<details>
<summary>P1.2: 8 Launch, 34 item, 34 log IDs</summary>

Launches: 2893, 2905-2906, 2925, 2968, 2993, 3073, 3143

Items: 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23432, 23435, 23508, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 24088, 24672, 25273

Logs: 15229-15230, 15233, 15236-15246, 15268-15269, 15318, 15584, 15588-15600, 15732, 16103, 16507

</details>

<a id="p1-3-id-ranges"></a>
<details>
<summary>P1.3: 10 Launch, 22 item, 22 log IDs</summary>

Launches: 2862, 2893, 2900, 2902-2903, 2905-2906, 2908, 2924, 2929

Items: 23050, 23360, 23362, 23368, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23416, 23423, 23426, 23432, 23435, 23441, 23503, 23522

Logs: 15030, 15229-15230, 15233, 15237-15246, 15262, 15265-15266, 15268-15269, 15271, 15316, 15323

</details>

<a id="p1-4-id-ranges"></a>
<details>
<summary>P1.4: 13 Launch, 25 item, 25 log IDs</summary>

Launches: 2862, 2893, 2900, 2902-2903, 2905-2906, 2908, 2924, 2929, 2996, 3077, 3148

Items: 23050, 23360, 23362, 23368, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23416, 23423, 23426, 23432, 23435, 23441, 23503, 23522, 24127, 24686, 25290

Logs: 15030, 15229-15230, 15233, 15237-15246, 15262, 15265-15266, 15268-15269, 15271, 15316, 15323, 15750, 16108, 16513

</details>

<a id="p1-5-id-ranges"></a>
<details>
<summary>P1.5: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2902

Items: 23423

Logs: 15265

</details>

<a id="p1-6-id-ranges"></a>
<details>
<summary>P1.6: 1 Launch, 2 item, 2 log IDs</summary>

Launches: 2893

Items: 23361, 23385

Logs: 15230, 15243

</details>

<a id="p1-7-id-ranges"></a>
<details>
<summary>P1.7: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2908

Items: 23441

Logs: 15271

</details>

<a id="p1-8-id-ranges"></a>
<details>
<summary>P1.8: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2924

Items: 23502

Logs: 15316

</details>

<a id="p1-9-id-ranges"></a>
<details>
<summary>P1.9: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2924

Items: 23502

Logs: 15316

</details>

<a id="p1-10-id-ranges"></a>
<details>
<summary>P1.10: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2862

Items: 23050

Logs: 15030

</details>

<a id="p2-1-id-ranges"></a>
<details>
<summary>P2.1: 1 Launch, 14 item, 14 log IDs</summary>

Launches: 554

Items: 4971, 4974, 4977, 4980, 4983, 4986, 4989, 4992, 4995, 4998, 5001, 5004, 5007, 5010

Logs: 3402, 3404, 3406, 3408, 3410, 3412, 3414, 3416, 3418, 3420, 3422, 3424, 3426, 3428

</details>

<a id="p2-2-id-ranges"></a>
<details>
<summary>P2.2: 1 Launch, 47 item, 30 log IDs</summary>

Launches: 554

Items: 4968-5014

Logs: 3401-3430

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
<summary>P2.4: 76 Launch, 676 item, 0 log IDs</summary>

Launches: 532-534, 536-540, 553-555, 560-566, 570-571, 614-616, 618-622, 635-637, 642-648, 652-653, 982-993, 1008-1019, 1107-1112, 1125-1130

Items: 4788-4808, 4814-4927, 4964-5043, 5061-5087, 5097-5102, 5482-5502, 5508-5621, 5658-5737, 5755-5781, 5791-5796, 8435-8470, 8513-8548, 8845-8898, 8999-9052

Logs: N/A

</details>

<a id="p3-1-id-ranges"></a>
<details>
<summary>P3.1: 85 Launch, 704 item, 486 log IDs</summary>

Launches: 532-534, 536-540, 553-555, 560-571, 614-616, 618-622, 635-637, 642-653, 737-739, 982-993, 1008-1019, 1107-1112, 1125-1130

Items: 4788-4808, 4814-4927, 4964-5043, 5061-5102, 5482-5502, 5508-5621, 5658-5737, 5755-5796, 6523-6532, 8435-8470, 8513-8548, 8845-8898, 8999-9052

Logs: 3279-3289, 3292-3382, 3399-3444, 3456-3480, 3755-3765, 3768-3858, 3875-3920, 3932-3956, 4469-4478, 5625-5640, 5659-5674, 5855-5903, 5983-6031

</details>

<a id="p3-2-id-ranges"></a>
<details>
<summary>P3.2: 2 Launch, 6 item, 6 log IDs</summary>

Launches: 560, 993

Items: 5061-5063, 8468-8470

Logs: 3456, 5636-5640

</details>

<a id="p3-3-id-ranges"></a>
<details>
<summary>P3.3: 23 Launch, 167 item, 116 log IDs</summary>

Launches: 554, 567-571, 718, 720-723, 731-735, 1086-1087, 1089, 1108-1111

Items: 4968-5014, 5088-5102, 6356-6402, 6432-6448, 6476-6490, 8747-8752, 8756-8758, 8850-8866

Logs: 3401-3430, 3476-3480, 4353-4382, 4397-4407, 4428-4432, 5761-5776, 5778-5785, 5857-5867

</details>

<a id="p3-4-id-ranges"></a>
<details>
<summary>P3.4: 4 Launch, 14 item, 7 log IDs</summary>

Launches: 532, 541, 546, 939

Items: 4788-4790, 4928-4930, 4943-4945, 8188-8192

Logs: 3279-3281, 3383, 3388, 5515-5516

</details>

<a id="p4-1-id-ranges"></a>
<details>
<summary>P4.1: 4 Launch, 20 item, 0 log IDs</summary>

Launches: 938, 942, 946, 950

Items: 8183-8187, 8201-8205, 8219-8223, 8237-8241

Logs: N/A

</details>

<a id="p4-2-id-ranges"></a>
<details>
<summary>P4.2: 1 Launch, 47 item, 0 log IDs</summary>

Launches: 554

Items: 4968-5014

Logs: N/A

</details>

<a id="p4-3-id-ranges"></a>
<details>
<summary>P4.3: 1 Launch, 5 item, 0 log IDs</summary>

Launches: 938

Items: 8183-8187

Logs: N/A

</details>

<a id="p4-4-id-ranges"></a>
<details>
<summary>P4.4: 76 Launch, 676 item, 0 log IDs</summary>

Launches: 532-534, 536-540, 553-555, 560-566, 570-571, 614-616, 618-622, 635-637, 642-648, 652-653, 982-993, 1008-1019, 1107-1112, 1125-1130

Items: 4788-4808, 4814-4927, 4964-5043, 5061-5087, 5097-5102, 5482-5502, 5508-5621, 5658-5737, 5755-5781, 5791-5796, 8435-8470, 8513-8548, 8845-8898, 8999-9052

Logs: N/A

</details>

<a id="p5-1-id-ranges"></a>
<details>
<summary>P5.1: 1 Launch, 1 item, 3 log IDs</summary>

Launches: 2857

Items: 23023

Logs: 15017-15019

</details>

<a id="p5-2-id-ranges"></a>
<details>
<summary>P5.2: 3 Launch, 6 item, 10 log IDs</summary>

Launches: 2862, 2871, 2909

Items: 23052, 23174, 23176, 23178, 23444-23445

Logs: 15031, 15122-15124, 15272-15277

</details>

<a id="p5-3-id-ranges"></a>
<details>
<summary>P5.3: 199 Launch, 844 item, 1042 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23534, 23541, 23544-23558, 23562-23569, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23606, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756, 23759, 23762, 23765, 23768, 23771, 23774, 23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 23904-23907, 23910, 23913-23914, 23926, 23929, 23938, 23941, 23944, 23947, 23950, 23953-23954, 23973, 23975-23979, 23982, 23988, 23993, 23996, 24010, 24039, 24063, 24067, 24083, 24085, 24088, 24091, 24093, 24127, 24137, 24142, 24155-24178, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24781, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926, 24929, 24932, 24935, 24941, 24944, 24947, 24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25047, 25049, 25051, 25053, 25055, 25057, 25059, 25061, 25063, 25065, 25067, 25069, 25071, 25073, 25081-25084, 25087, 25090-25091, 25115-25116, 25119, 25122, 25136, 25158, 25182, 25186-25187, 25190-25195, 25207, 25232, 25235, 25238, 25248, 25254, 25260, 25262, 25265, 25267, 25273, 25276, 25278, 25290, 25299, 25302, 25311, 25314, 25317, 25320-25328, 25331-25333, 25335-25343, 25918, 25921-25922, 25928

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15358, 15362-15373, 15377-15379, 15381-15384, 15386-15391, 15394-15463, 15468-15482, 15490-15495, 15500-15507, 15510, 15545-15584, 15588-15609, 15614, 15616, 15620-15630, 15639-15648, 15650, 15652-15653, 15658, 15689-15691, 15713, 15716, 15730-15734, 15750, 15754-15762, 15766-15801, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16167-16169, 16171-16175, 16177, 16179-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16293, 16297-16302, 16311-16347, 16356-16369, 16372-16380, 16391-16394, 16413, 16434, 16456, 16458-16472, 16477, 16489-16491, 16495, 16498-16500, 16502-16505, 16507-16509, 16513, 16516-16524, 16527-16547, 16549-16563, 16937-16945, 16949

</details>

<a id="p5-4-id-ranges"></a>
<details>
<summary>P5.4: 199 Launch, 844 item, 1042 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23534, 23541, 23544-23558, 23562-23569, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23606, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756, 23759, 23762, 23765, 23768, 23771, 23774, 23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 23904-23907, 23910, 23913-23914, 23926, 23929, 23938, 23941, 23944, 23947, 23950, 23953-23954, 23973, 23975-23979, 23982, 23988, 23993, 23996, 24010, 24039, 24063, 24067, 24083, 24085, 24088, 24091, 24093, 24127, 24137, 24142, 24155-24178, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24781, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926, 24929, 24932, 24935, 24941, 24944, 24947, 24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25047, 25049, 25051, 25053, 25055, 25057, 25059, 25061, 25063, 25065, 25067, 25069, 25071, 25073, 25081-25084, 25087, 25090-25091, 25115-25116, 25119, 25122, 25136, 25158, 25182, 25186-25187, 25190-25195, 25207, 25232, 25235, 25238, 25248, 25254, 25260, 25262, 25265, 25267, 25273, 25276, 25278, 25290, 25299, 25302, 25311, 25314, 25317, 25320-25328, 25331-25333, 25335-25343, 25918, 25921-25922, 25928

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15358, 15362-15373, 15377-15379, 15381-15384, 15386-15391, 15394-15463, 15468-15482, 15490-15495, 15500-15507, 15510, 15545-15584, 15588-15609, 15614, 15616, 15620-15630, 15639-15648, 15650, 15652-15653, 15658, 15689-15691, 15713, 15716, 15730-15734, 15750, 15754-15762, 15766-15801, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16167-16169, 16171-16175, 16177, 16179-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16293, 16297-16302, 16311-16347, 16356-16369, 16372-16380, 16391-16394, 16413, 16434, 16456, 16458-16472, 16477, 16489-16491, 16495, 16498-16500, 16502-16505, 16507-16509, 16513, 16516-16524, 16527-16547, 16549-16563, 16937-16945, 16949

</details>

<a id="p5-5-id-ranges"></a>
<details>
<summary>P5.5: 1 Launch, 1 item, 4 log IDs</summary>

Launches: 2911

Items: 23451

Logs: 15279-15282

</details>

<a id="p5-6-id-ranges"></a>
<details>
<summary>P5.6: 2 Launch, 4 item, 12 log IDs</summary>

Launches: 2909, 3234

Items: 23444-23445, 25921-25922

Logs: 15272-15277, 16940-16945

</details>

<a id="p5-7-id-ranges"></a>
<details>
<summary>P5.7: 90 Launch, 478 item, 128 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932, 2934, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3078, 3081

Items: 23023, 23027-23044, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23185-23190, 23193, 23195-23199, 23203-23208, 23212, 23214-23219, 23221-23222, 23244-23245, 23247, 23268-23270, 23277-23281, 23285-23286, 23288, 23290, 23293-23295, 23298-23299, 23302, 23304-23305, 23307, 23310-23312, 23315-23316, 23319-23320, 23322, 23324, 23327-23329, 23332-23333, 23336-23338, 23341-23362, 23367-23368, 23371-23392, 23396-23404, 23409-23416, 23421-23426, 23430-23435, 23439-23441, 23444-23445, 23451, 23471, 23473-23477, 23492-23497, 23505-23508, 23512-23516, 23520-23522, 23529-23531, 23547-23550, 24187, 24191-24207, 24209, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24255, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348-24351, 24355-24360, 24364, 24366-24373, 24393, 24395, 24397, 24417, 24419, 24421, 24427-24435, 24453, 24468-24502, 24505-24507, 24509-24510, 24512, 24514, 24516-24524, 24528-24530, 24532-24557, 24562-24570, 24573-24576, 24578-24584, 24588-24593, 24597-24602, 24608-24609, 24612, 24634-24636, 24645-24647, 24654, 24657-24661, 24669-24672, 24676-24680, 24684-24689, 24708-24711

Logs: 15017-15019, 15031-15037, 15039-15042, 15044, 15046, 15048, 15050, 15052, 15054, 15056, 15058, 15060, 15063, 15105-15108, 15110-15120, 15122-15125, 15179-15180, 15182, 15272-15277, 15279-15282, 15310-15312, 15317, 15344, 15346, 15348, 15350, 15804-15806, 15818-15821, 15823-15829, 15831, 15833, 15835, 15838, 15840, 15842-15843, 15846, 15848, 15850, 15893-15907, 15909-15911, 15913, 15972, 15974-15975, 16057-16066, 16094-16096, 16102, 16130, 16132, 16134, 16136

</details>

<a id="p5-8-id-ranges"></a>
<details>
<summary>P5.8: 2 Launch, 2 item, 6 log IDs</summary>

Launches: 2857, 3005

Items: 23022, 24186

Logs: 15017-15019, 15804-15806

</details>

<a id="p6-1-id-ranges"></a>
<details>
<summary>P6.1: 18 Launch, 120 item, 0 log IDs</summary>

Launches: 1104-1106, 1108, 1110, 1113-1115, 1119, 1122-1124, 1126, 1128, 1131-1133, 1137

Items: 8822-8844, 8850-8855, 8859-8862, 8899-8921, 8936-8939, 8976-8998, 9004-9009, 9013-9016, 9053-9075, 9090-9093

Logs: N/A

</details>

<a id="p6-2-id-ranges"></a>
<details>
<summary>P6.2: 76 Launch, 676 item, 0 log IDs</summary>

Launches: 532-534, 536-540, 553-555, 560-566, 570-571, 614-616, 618-622, 635-637, 642-648, 652-653, 982-993, 1008-1019, 1107-1112, 1125-1130

Items: 4788-4808, 4814-4927, 4964-5043, 5061-5087, 5097-5102, 5482-5502, 5508-5621, 5658-5737, 5755-5781, 5791-5796, 8435-8470, 8513-8548, 8845-8898, 8999-9052

Logs: N/A

</details>

<a id="p6-3-id-ranges"></a>
<details>
<summary>P6.3: 1 Launch, 5 item, 2 log IDs</summary>

Launches: 1107

Items: 8845-8849

Logs: 5855-5856

</details>

<a id="p6-4-id-ranges"></a>
<details>
<summary>P6.4: 2 Launch, 12 item, 0 log IDs</summary>

Launches: 556, 1104

Items: 5044-5049, 8822-8827

Logs: N/A

</details>

<a id="p7-1-id-ranges"></a>
<details>
<summary>P7.1: 1 Launch, 9 item, 4 log IDs</summary>

Launches: 534

Items: 4800-4808

Logs: 3286-3289

</details>

<a id="p7-2-id-ranges"></a>
<details>
<summary>P7.2: 1 Launch, 4 item, 2 log IDs</summary>

Launches: 553

Items: 4964-4967

Logs: 3399-3400

</details>

<a id="p7-3-id-ranges"></a>
<details>
<summary>P7.3: 1 Launch, 52 item, 0 log IDs</summary>

Launches: 537

Items: 4835-4886

Logs: N/A

</details>

<a id="p7-4-id-ranges"></a>
<details>
<summary>P7.4: 1 Launch, 8 item, 9 log IDs</summary>

Launches: 566

Items: 5080-5087

Logs: 3467-3475

</details>

<a id="p7-5-id-ranges"></a>
<details>
<summary>P7.5: 2 Launch, 8 item, 4 log IDs</summary>

Launches: 553, 635

Items: 4964-4967, 5658-5661

Logs: 3399-3400, 3875-3876

</details>

<a id="p8-1-id-ranges"></a>
<details>
<summary>P8.1: 2 Launch, 2 item, 2 log IDs</summary>

Launches: 2874, 2877

Items: 23187, 23196

Logs: 15129, 15132

</details>

<a id="p8-2-id-ranges"></a>
<details>
<summary>P8.2: 3 Launch, 3 item, 3 log IDs</summary>

Launches: 2875, 2878, 2880

Items: 23190, 23199, 23205

Logs: 15130, 15133, 15139

</details>

<a id="p8-3-id-ranges"></a>
<details>
<summary>P8.3: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2877

Items: 23196

Logs: 15132

</details>

<a id="p8-4-id-ranges"></a>
<details>
<summary>P8.4: 4 Launch, 4 item, 4 log IDs</summary>

Launches: 2881, 2883-2884, 2886

Items: 23208, 23215, 23218, 23222

Logs: 15140, 15143-15145

</details>

<a id="p8-5-id-ranges"></a>
<details>
<summary>P8.5: 1 Launch, 1 item, 5 log IDs</summary>

Launches: 2889

Items: 23277

Logs: 15178-15182

</details>

<a id="p8-6-id-ranges"></a>
<details>
<summary>P8.6: 199 Launch, 996 item, 906 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3002, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152, 3155, 3233-3234, 3236

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23193, 23195-23199, 23203-23205, 23208, 23212, 23214-23219, 23221-23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357-23362, 23367-23368, 23371-23392, 23398-23401, 23404, 23411-23412, 23415, 23421-23426, 23430-23435, 23439-23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23505-23508, 23514, 23516, 23520-23522, 23531, 23534, 23541, 23544-23558, 23562-23569, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756-23765, 23768-23774, 23787-23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23872-23873, 23875-23901, 23904-23907, 23910, 23913-23914, 23926, 23936-23950, 23953-23954, 23973, 23975-23979, 23982, 23988, 23993, 23996, 24010, 24039, 24063, 24067, 24085-24088, 24091, 24093, 24125-24127, 24137, 24142, 24155-24178, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357-24360, 24364, 24366-24370, 24373, 24393, 24395, 24397, 24417, 24419, 24421, 24427-24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24528-24530, 24532-24557, 24564-24567, 24570, 24575-24576, 24580, 24582-24584, 24588-24593, 24597-24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24669-24672, 24678, 24680, 24684-24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926-24935, 24941-24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25045-25073, 25081-25084, 25087, 25090-25091, 25115, 25117-25122, 25133, 25135-25136, 25155-25156, 25158, 25179, 25181-25182, 25186-25187, 25190-25195, 25207, 25232, 25235, 25238, 25248, 25254, 25260, 25262, 25267, 25271-25273, 25276, 25278, 25288-25290, 25299, 25302, 25311, 25314, 25317, 25320-25328, 25331-25333, 25335-25343, 25918, 25921-25922, 25928

Logs: 15017-15019, 15021-15028, 15031-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15140, 15161, 15175, 15182-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15228, 15250-15256, 15259-15261, 15272-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15317, 15320-15321, 15326-15358, 15362-15373, 15377-15379, 15381-15384, 15386-15389, 15391, 15394-15463, 15468-15482, 15490-15495, 15500-15501, 15505, 15545-15546, 15550, 15552-15583, 15601-15609, 15614, 15625-15630, 15639-15648, 15650, 15652-15653, 15658, 15689-15691, 15713, 15716, 15731, 15733-15734, 15754-15762, 15766-15801, 15804-15806, 15808-15815, 15818-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922, 15928, 15962-15963, 15974, 15983-16006, 16008, 16010, 16013-16018, 16037-16045, 16047, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16102, 16105-16106, 16109-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161, 16167-16169, 16171-16175, 16177, 16179-16180, 16182-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16290, 16297, 16301-16302, 16315-16347, 16372-16380, 16391, 16458-16472, 16477, 16489-16491, 16495, 16498-16500, 16502-16503, 16505, 16508-16509, 16516-16524, 16527-16547, 16549-16563, 16937-16945, 16949

</details>

<a id="p8-7-id-ranges"></a>
<details>
<summary>P8.7: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2888

Items: 23270

Logs: 15175

</details>

<a id="p8-8-id-ranges"></a>
<details>
<summary>P8.8: 48 Launch, 144 item, 0 log IDs</summary>

Launches: 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2889, 2952-2956, 2958-2964, 3022, 3024-3025, 3027-3029, 3031-3035, 3037, 3098-3102, 3104-3109, 3111

Items: 23185-23190, 23193, 23195-23199, 23203-23208, 23212, 23214-23219, 23221-23222, 23244-23245, 23247, 23268-23270, 23275-23277, 23751-23774, 23787-23789, 23810-23818, 24349-24351, 24355-24360, 24364, 24366-24373, 24393, 24395, 24397, 24417, 24419, 24421, 24427-24435, 24451-24453, 24921-24935, 24939-24954, 24956, 24958, 24974-24976

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

Launches: 570

Items: 5097-5099

Logs: N/A

</details>

<a id="p9-2-id-ranges"></a>
<details>
<summary>P9.2: 4 Launch, 12 item, 0 log IDs</summary>

Launches: 567, 569, 1088, 1090

Items: 5088-5090, 5094-5096, 8753-8755, 8759-8761

Logs: N/A

</details>

<a id="p9-3-id-ranges"></a>
<details>
<summary>P9.3: 1 Launch, 3 item, 0 log IDs</summary>

Launches: 568

Items: 5091-5093

Logs: N/A

</details>

<a id="p9-4-id-ranges"></a>
<details>
<summary>P9.4: 5 Launch, 15 item, 0 log IDs</summary>

Launches: 567-569, 1088, 1090

Items: 5088-5096, 8753-8755, 8759-8761

Logs: N/A

</details>

<a id="p9-5-id-ranges"></a>
<details>
<summary>P9.5: 1 Launch, 3 item, 0 log IDs</summary>

Launches: 567

Items: 5088-5090

Logs: N/A

</details>

<a id="p10-1-id-ranges"></a>
<details>
<summary>P10.1: 3 Launch, 4 item, 10 log IDs</summary>

Launches: 3233-3234, 3236

Items: 25918, 25921-25922, 25928

Logs: 16937-16945, 16949

</details>

<a id="p10-2-id-ranges"></a>
<details>
<summary>P10.2: 1 Launch, 1 item, 1 log IDs</summary>

Launches: 2918

Items: 23477

Logs: 15294

</details>

<a id="p10-3-id-ranges"></a>
<details>
<summary>P10.3: 49 Launch, 210 item, 258 log IDs</summary>

Launches: 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081

Items: 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733

Logs: 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161

</details>

<a id="p10-4-id-ranges"></a>
<details>
<summary>P10.4: 17 Launch, 30 item, 33 log IDs</summary>

Launches: 3010, 3025, 3027-3028, 3032-3033, 3037, 3042, 3048-3049, 3051-3052, 3054-3055, 3072-3073, 3077

Items: 24214, 24360, 24367, 24370, 24421, 24429, 24453, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24581, 24584, 24590, 24593, 24599, 24602, 24667, 24672, 24686

Logs: 15817, 15923, 15926-15927, 15957, 15961, 15971-15973, 15975, 16020, 16022-16034, 16048-16049, 16051-16052, 16054-16055, 16101, 16103, 16108

</details>

<a id="p10-5-id-ranges"></a>
<details>
<summary>P10.5: 49 Launch, 210 item, 258 log IDs</summary>

Launches: 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081

Items: 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24698, 24703-24704, 24707-24715, 24718-24721, 24723-24726, 24729-24731, 24733

Logs: 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16121-16144, 16146-16149, 16151, 16153-16155, 16157-16159, 16161

</details>

<a id="p10-6-id-ranges"></a>
<details>
<summary>P10.6: 192 Launch, 744 item, 888 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2933, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152

Items: 23023, 23029, 23031, 23033, 23035, 23038, 23040, 23042, 23044, 23050, 23052, 23055, 23057, 23059, 23061, 23063, 23065, 23070, 23072, 23074, 23076, 23079-23086, 23089, 23091-23131, 23137, 23139, 23141, 23145, 23148, 23150, 23152, 23154, 23156, 23158, 23160, 23162, 23164, 23166, 23168, 23174, 23176, 23178, 23181, 23187, 23190, 23196, 23199, 23205, 23208, 23215, 23218, 23222, 23247, 23270, 23277, 23280-23281, 23288, 23290, 23294-23295, 23299, 23302, 23305, 23307, 23311-23312, 23316, 23319, 23322, 23324, 23328-23329, 23333, 23336, 23338, 23341, 23343-23344, 23346-23347, 23349-23350, 23352-23353, 23355, 23357, 23360, 23362, 23368, 23372, 23374, 23376, 23378, 23380, 23382, 23384, 23386, 23388, 23390, 23392, 23398-23401, 23404, 23411-23412, 23415-23416, 23423, 23426, 23432, 23435, 23441, 23444-23445, 23451-23456, 23459, 23465, 23468, 23474, 23477, 23492, 23495, 23497, 23503, 23505, 23508, 23514, 23516, 23522, 23531, 23534, 23580, 23585, 23587, 23589, 23591, 23597, 23599, 23601, 23603, 23606, 23608, 23616, 23618, 23620, 23622, 23624, 23626, 23628, 23630, 23632, 23634, 23637-23686, 23695, 23697, 23699, 23701, 23703, 23705, 23707, 23709, 23711, 23713, 23715, 23717, 23719, 23721, 23723, 23737, 23739, 23741, 23744, 23753, 23756, 23759, 23762, 23765, 23768, 23771, 23774, 23789, 23812, 23815, 23818, 23821-23822, 23825-23826, 23828-23829, 23831-23832, 23834-23835, 23837-23838, 23840-23841, 23843-23844, 23846-23847, 23849-23850, 23852-23853, 23855-23856, 23858-23859, 23861-23862, 23864-23865, 23867, 23869, 23875, 23877, 23879, 23881, 23883, 23885, 23887, 23889, 23891, 23893, 23895, 23897, 23899, 23901, 23904-23907, 23910, 23913-23914, 23926, 23929, 23938, 23941, 23944, 23947, 23950, 23953-23954, 23973, 23975-23979, 23982, 23988, 23993, 23996, 24010, 24039, 24063, 24067, 24083, 24085, 24088, 24091, 24093, 24127, 24137, 24142, 24187, 24193, 24195, 24197, 24199, 24202, 24204, 24206, 24209, 24214, 24216, 24219, 24221, 24225, 24228, 24230, 24232, 24234, 24236, 24238, 24240, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24304, 24306, 24308, 24310, 24312, 24314, 24316, 24318, 24320, 24322, 24324, 24326, 24328, 24330, 24332, 24338, 24340, 24342, 24348, 24351, 24357, 24360, 24367, 24370, 24373, 24397, 24421, 24429, 24432, 24435, 24453, 24470-24471, 24474-24475, 24477-24478, 24480-24481, 24483-24484, 24486-24487, 24489-24490, 24492-24493, 24495-24496, 24498-24499, 24501-24502, 24506-24507, 24510, 24512, 24516-24517, 24519-24520, 24522, 24524, 24530, 24533, 24535, 24537, 24539, 24541, 24543, 24545, 24547, 24549, 24551, 24553, 24555, 24557, 24564-24567, 24570, 24575-24576, 24580-24581, 24584, 24590, 24593, 24599, 24602, 24608-24609, 24612-24617, 24623, 24626, 24633, 24636, 24647, 24654, 24659, 24661, 24667, 24669, 24672, 24678, 24680, 24686, 24689, 24694, 24752, 24758, 24760, 24762, 24764, 24769, 24772, 24776, 24778, 24781, 24783, 24786, 24788, 24790, 24792, 24794, 24796, 24798, 24800, 24802, 24804, 24807-24850, 24853-24855, 24857, 24859, 24862, 24868, 24872, 24875, 24878, 24882, 24886, 24888, 24890, 24892, 24894, 24896, 24898, 24900, 24902, 24904, 24913, 24915, 24917, 24920, 24923, 24926, 24929, 24932, 24935, 24941, 24944, 24947, 24950, 24953, 24958, 24976, 24979-24980, 24983-24984, 24986-24987, 24989-24990, 24992-24993, 24995-24996, 24998-24999, 25001-25002, 25004-25005, 25007-25008, 25010-25011, 25013-25014, 25016-25017, 25019-25020, 25022-25023, 25025, 25027, 25047, 25049, 25051, 25053, 25055, 25057, 25059, 25061, 25063, 25065, 25067, 25069, 25071, 25073, 25081-25084, 25087, 25090-25091, 25115-25116, 25119, 25122, 25136, 25158, 25182, 25186-25187, 25190-25195, 25207, 25232, 25235, 25238, 25248, 25254, 25260, 25262, 25265, 25267, 25273, 25276, 25278, 25290, 25299, 25302

Logs: 15017-15019, 15021-15028, 15030-15037, 15039-15060, 15062-15103, 15105-15108, 15110-15120, 15122-15127, 15129-15130, 15132-15133, 15139-15140, 15143-15145, 15161, 15175, 15178-15184, 15186, 15188, 15190-15191, 15193-15194, 15196, 15198, 15200-15201, 15203, 15205-15206, 15208, 15210-15211, 15213-15214, 15216, 15218-15230, 15233, 15236-15246, 15250-15256, 15259-15262, 15265-15266, 15268-15269, 15271-15277, 15279-15288, 15290-15291, 15293-15294, 15310-15314, 15316-15318, 15320-15321, 15323, 15326-15334, 15377-15379, 15381-15384, 15386-15391, 15394-15463, 15468-15482, 15490-15495, 15500-15507, 15510, 15545-15584, 15588-15609, 15614, 15616, 15620-15630, 15639-15648, 15650, 15652-15653, 15658, 15689-15691, 15713, 15716, 15730-15734, 15750, 15754-15762, 15804-15806, 15808-15815, 15817-15821, 15823-15835, 15837-15885, 15887-15891, 15893-15907, 15909-15911, 15913-15916, 15922-15923, 15926-15928, 15942, 15957, 15961-15963, 15971-15975, 15983-16006, 16008, 16010, 16013-16018, 16020, 16022-16034, 16037-16045, 16047-16049, 16051-16052, 16054-16055, 16057-16071, 16073-16074, 16081-16082, 16092, 16094-16096, 16098-16099, 16101-16103, 16105-16106, 16108-16117, 16167-16169, 16171-16175, 16177, 16179-16249, 16251, 16254, 16256, 16258, 16260, 16262-16263, 16266, 16269-16278, 16283-16293, 16297-16302, 16311-16347, 16356-16369, 16372-16380, 16391-16394, 16413, 16434, 16456, 16458-16472, 16477, 16489-16491, 16495, 16498-16500, 16502-16505, 16507-16509, 16513, 16516-16524

</details>

<a id="p10-7-id-ranges"></a>
<details>
<summary>P10.7: 194 Launch, 1444 item, 0 log IDs</summary>

Launches: 2857, 2859-2860, 2862-2863, 2865, 2868, 2871-2872, 2874-2875, 2877-2878, 2880-2881, 2883-2884, 2886-2890, 2892-2893, 2896-2897, 2899-2900, 2902-2903, 2905-2906, 2908-2909, 2911-2912, 2914-2915, 2917-2918, 2921-2922, 2924-2925, 2927, 2929, 2932-2934, 2938-2939, 2941-2942, 2944-2945, 2947, 2949-2950, 2952-2956, 2958-2966, 2968-2971, 2973-2979, 2981-2982, 2984-2986, 2988, 2990-2994, 2996, 2998, 3000, 3005, 3007-3008, 3010-3011, 3013, 3017, 3019, 3021-3022, 3024-3025, 3027-3029, 3031-3035, 3037-3039, 3042, 3044-3045, 3047-3049, 3051-3052, 3054-3055, 3057-3058, 3060-3061, 3063-3064, 3066, 3068, 3070, 3072-3073, 3075, 3077-3079, 3081, 3084, 3086-3087, 3089-3091, 3094, 3096-3102, 3104-3109, 3111-3113, 3115, 3117-3119, 3121-3123, 3125-3129, 3131-3134, 3136, 3138, 3140-3141, 3143-3144, 3148, 3151-3152

Items: 23021-23023, 23027-23044, 23048-23065, 23068, 23070-23086, 23089, 23091-23131, 23135-23141, 23144-23145, 23147-23168, 23172-23181, 23185-23190, 23193, 23195-23199, 23203-23208, 23212, 23214-23219, 23221-23222, 23244-23245, 23247, 23268-23270, 23275-23281, 23285-23286, 23288, 23290, 23293-23295, 23298-23299, 23302, 23304-23305, 23307, 23310-23312, 23315-23316, 23319-23320, 23322, 23324, 23327-23329, 23332-23333, 23336-23338, 23341-23362, 23367-23368, 23371-23392, 23396-23404, 23409-23416, 23421-23426, 23430-23435, 23439-23445, 23449-23459, 23463-23468, 23471, 23473-23477, 23490-23497, 23501-23508, 23512-23516, 23520-23522, 23529-23558, 23562-23569, 23578-23580, 23583-23591, 23595-23608, 23614-23686, 23693-23723, 23735-23744, 23751-23774, 23787-23789, 23810-23869, 23872-23873, 23875-23914, 23923, 23925-23926, 23929, 23936-23954, 23971-23973, 23975-23982, 23985, 23987-23988, 23991-23996, 24006, 24008, 24010, 24036-24037, 24039, 24060, 24062-24063, 24065, 24067, 24081-24093, 24125-24127, 24135-24137, 24139, 24141-24142, 24185-24187, 24191-24207, 24209, 24212-24221, 24224-24225, 24227-24242, 24244, 24246-24247, 24249-24288, 24291-24292, 24294-24298, 24302-24332, 24336-24342, 24346-24351, 24355-24360, 24364, 24366-24373, 24393, 24395, 24397, 24417, 24419, 24421, 24427-24435, 24451-24453, 24468-24502, 24505-24507, 24509-24510, 24512, 24514, 24516-24524, 24528-24530, 24532-24557, 24562-24570, 24573-24576, 24578-24584, 24588-24593, 24597-24602, 24606-24617, 24621-24626, 24631-24636, 24645-24647, 24651-24652, 24654, 24657-24661, 24665-24672, 24676-24680, 24684-24689, 24691, 24693-24694, 24696-24715, 24718-24721, 24723-24726, 24729-24731, 24733, 24750-24752, 24756-24765, 24768-24770, 24772, 24774, 24776-24850, 24853-24855, 24857, 24859, 24862, 24865-24866, 24868, 24870, 24872, 24874-24875, 24877-24878, 24881-24882, 24885-24904, 24911-24935, 24939-24954, 24956, 24958, 24974-25027, 25045-25073, 25079-25091, 25113-25122, 25133, 25135-25136, 25155-25156, 25158, 25179, 25181-25182, 25184-25195, 25204, 25206-25207, 25230-25238, 25246-25248, 25252-25254, 25258-25267, 25271-25278, 25288-25290, 25297-25302

Logs: N/A

</details>

<a id="p10-8-id-ranges"></a>
<details>
<summary>P10.8: 13 Launch, 51 item, 27 log IDs</summary>

Launches: 3010, 3029, 3034, 3042, 3048-3049, 3051-3052, 3054-3055, 3058, 3072, 3077

Items: 24213-24214, 24372-24373, 24431-24432, 24529-24530, 24532-24535, 24538-24557, 24579, 24581, 24583-24584, 24589-24590, 24592-24593, 24598-24599, 24601-24602, 24611-24612, 24617, 24666-24667, 24685-24686

Logs: 15817, 15928, 15962, 16020, 16022-16023, 16025-16034, 16048-16049, 16051-16052, 16054-16055, 16063-16064, 16071, 16101, 16108

</details>

<a id="p10-9-id-ranges"></a>
<details>
<summary>P10.9: 1 Launch, 2 item, 2 log IDs</summary>

Launches: 3038

Items: 24470-24471

Logs: 15983-15984

</details>

<a id="p10-10-id-ranges"></a>
<details>
<summary>P10.10: 9 Launch, 9 item, 16 log IDs</summary>

Launches: 3005, 3022, 3025, 3029, 3031-3032, 3037-3038, 3072

Items: 24186, 24350, 24359, 24372, 24395, 24419, 24452, 24469, 24666

Logs: 15804-15806, 15916, 15923, 15928, 15942, 15957, 15971-15975, 15983-15984, 16101

</details>

<a id="p10-11-id-ranges"></a>
<details>
<summary>P10.11: 4 Launch, 4 item, 6 log IDs</summary>

Launches: 3005, 3022, 3025, 3031

Items: 24186, 24350, 24359, 24395

Logs: 15804-15806, 15916, 15923, 15942

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
