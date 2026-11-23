# Data audit and sampling-rate note

This audit was completed before inspecting classifier performance. It is part of the analysis, not merely a loading step.

## Provenance and released structure

- Official source: [huytungst/EEGEmotions-27](https://github.com/huytungst/EEGEmotions-27)
- Fixed upstream commit: `0dfec14d177ed73c37a95f06d942e9b58e2bbf77`
- Dataset license: CC BY-NC 4.0
- Raw directory: `eeg_raw/`
- Filename grammar: `{Participant_ID}_{Emotion_ID}.0.txt`
- Files found: 2,343 of a possible `88 × 27 = 2,376`
- Participant metadata rows: 88, with IDs 1--90 except 26 and 48
- Condition IDs: all 1--27 present
- File format verified across all files: tab-delimited numeric, time samples in rows, 14 channels in columns

Every file was parsed, read, and SHA-256 hashed. The audit found no duplicate participant-condition key, duplicate file hash, NaN/Inf value, or unexpected 14-channel orientation among the structurally valid recordings.

## Mixed effective-sampling-rate evidence

The repository README describes all data as 256 Hz. The [EPOC X manufacturer specifications](https://emotiv.gitbook.io/epoc-x-user-manual/introduction/technical-specifications), however, allow user-configurable 128 or 256 SPS and document an approximately 0.2--45 Hz bandwidth. The released row counts form two participant-level clusters:

- 41 participants: median row-count ratio approximately `0.5` within every fixed stimulus condition;
- 47 participants: median row-count ratio approximately `1.0`.

The split is participant-consistent across conditions, not a random collection of short trials. Using the documented 256 Hz for both groups would imply that the same fixed videos lasted half as long for 41 participants.

An independent spectral check used the first five valid condition IDs for every participant. Each file was temporarily placed on a nominal 256 Hz axis, and the median ratio of nominal 50--90 Hz power to 1--40 Hz power was calculated. The median log10 ratio was:

- inferred-128 group: `-1.4624`;
- 256-consistent group: `-4.0370`.

The large difference is consistent with the headset's approximately 45 Hz effective bandwidth appearing near 90 Hz when 128 Hz data are mislabeled as 256 Hz. The distributions were not perfectly separated because several recordings contained substantial high-frequency noise; therefore spectral power was used as validation, not as the assignment rule.

The frozen assignment rule is based only on pre-model row counts: a participant median ratio below `0.75` is assigned 128 Hz; otherwise 256 Hz. This produces no ambiguous participants. The values should be interpreted as effective output rates: the public TXT files cannot distinguish acquisition-time configuration from later export or downsampling. The inference still requires confirmation from the dataset authors.

The released metadata contain no recording-batch identifier. The inferred groups are not equivalent to nationality:

| Nation code | Dataset meaning | Inferred 128 Hz | Consistent 256 Hz |
|---:|---|---:|---:|
| 1 | Korean | 27 | 37 |
| 2 | Vietnamese | 14 | 10 |

Age, gender, and nation cross-counts are persisted in [`outputs/audit/sampling_rate_demographics.csv`](outputs/audit/sampling_rate_demographics.csv). These checks rule out a one-to-one demographic explanation but cannot exclude an unrecorded batch effect.

## Pre-model exclusions

After correcting duration by the participant-level rate, a trial was excluded if its duration differed from its condition median by more than 5%. The threshold was fixed before model results were inspected.

| File | Reason |
|---|---|
| `21_1.0.txt` | corrected duration ratio 2.0000 |
| `30_8.0.txt` | corrected duration ratio 0.8754 |
| `33_1.0.txt` | corrected duration ratio 6.2619 |
| `33_3.0.txt` | corrected duration ratio 0.7404 |
| `33_9.0.txt` | corrected duration ratio 3.9391 |
| `3_15.0.txt` | corrected duration ratio 0.9402 |
| `42_4.0.txt` | corrected duration ratio 3.8066 |
| `52_3.0.txt` | one sample only; 14 constant channels |

This leaves 2,335 complete trials. The excluded-file reasons and hashes are preserved in [`outputs/audit/data_audit.csv`](outputs/audit/data_audit.csv).

A frozen-policy sensitivity restored all seven duration outliers and excluded only the one structurally unusable file. It increased the analysis to 2,342 trials while changing macro-F1 from `0.047984` to `0.047887` and accuracy from `5.310%` to `5.295%`. The result therefore does not depend materially on the 5% threshold. The exact comparison and added-trial list are in [`outputs/duration_exclusion_sensitivity`](outputs/duration_exclusion_sensitivity).

## Remaining unknowns

The official materials do not establish:

- whether numeric samples are microvolts, device units, or another scale;
- the exact online/offline filtering applied to each released file;
- the reference montage;
- whether any released TXT received ICA or other artifact correction;
- whether the effective-rate difference arose during acquisition, export, or downsampling;
- why two participant-level sampling-rate groups appear despite the 256 Hz documentation;
- whether an unrecorded recording-batch factor aligns with those groups.

For that reason, figures say arbitrary units, the model uses within-fold standardization, and no classifier coefficient is interpreted as a neural source. The all-256-Hz sensitivity result is retained in [`outputs/sampling_rate_sensitivity/metrics.csv`](outputs/sampling_rate_sensitivity/metrics.csv); it does not change the qualitative conclusion.

