# Analysis contract

## Research question

How much cross-participant information about the 27 stimulus-elicited conditions is retained by a simple Fourier-domain representation?

## What one row means

The primary observation is one complete public trial from one participant and one target condition. The first milestone does not divide a trial into correlated segments. If segmentation is introduced later, all segments from a trial and participant must remain in the same split, and trial-aggregated predictions must remain primary.

## Target interpretation

The class is the target stimulus condition for a trial that met the dataset's self-rating inclusion rule. It is not a direct ground-truth measurement of a discrete internal emotion. Because the same stimulus protocol is reused across participants, participant-held-out performance does not establish stimulus independence.

## Frozen primary representation

- The repository documents 256 Hz, but the released files show two participant-level length and spectral-bandwidth clusters consistent with effective output rates of 128 and 256 Hz. The primary analysis uses the inferred participant-level rate (41 at 128 Hz, 47 at 256 Hz) and labels it as an inference pending author confirmation. Acquisition-time configuration cannot be distinguished from later export or downsampling. A participant median row-count ratio below 0.75 is assigned 128 Hz; otherwise 256 Hz. Treating every file as 256 Hz is retained only as a sensitivity analysis.
- After rate correction, exclude a trial if its duration differs from its condition median by more than 5%, or if it cannot support one 2-second Welch window. This structural rule is fixed before modeling.
- Channels expected in documented order: AF3, F7, F3, FC5, T7, P7, O1, O2, P8, T8, FC6, F4, F8, AF4.
- Whole-trial per-channel mean removal before spectral estimation.
- Welch window: 2 seconds, periodic Hann window, 50% overlap, and an FFT length equal to 2 seconds (256 points at 128 Hz; 512 points at 256 Hz). Both groups therefore have 0.5 Hz bin spacing.
- Frequency range summarized: 1--40 Hz.
- Band assignment: delta `[1,4)`, theta `[4,8)`, alpha `[8,12)`, beta `[12,30)`, low-gamma `[30,40)` Hz. Each discrete FFT bin is assigned to at most one band; 40 Hz is excluded.
- Primary feature: `10*log10(band power)` for every channel-band pair. Until signal units are verified, plots and text must say "log power (arbitrary units squared)", not microvolts squared or dB relative to one microvolt.
- Relative band power may be reported only as a labeled sensitivity analysis and never as the sole spectral view.

## Frozen evaluation

- Five deterministic folds grouped by participant; no participant may appear in both train and test portions of a fold.
- Feature centering/scaling is estimated from the training portion of each fold and then applied to its held-out participants.
- One one-vs-all linear logistic ECOC model with ridge `lambda = 0.001`, fixed before the grouped evaluation.
- Primary summary: out-of-fold macro-F1.
- Additional summaries: balanced accuracy, ordinary trial accuracy, per-class recall, and an aggregated 27-by-27 confusion matrix.
- Baselines: train-fold majority prediction, 1,000 uniform-random repeats, and 100 label permutations performed within participant while retaining the same participant folds.
- Band contribution: remove one complete frequency band across all channels, retrain on the identical folds, and report paired changes. These are predictive-contribution analyses, not neural activation maps or causal mechanisms.
- Sampling-group diagnostics: apply the same mixed-group OOF predictions to each inferred-rate subgroup and report descriptive metrics. These are not separately trained models, subgroup-specific significance tests, or causal effects of sampling rate.
- Duration-rule sensitivity: restore all structurally usable duration outliers, reuse the primary participant folds and fixed model, and compare against the frozen 5% primary rule.
- The reported 2.5th--97.5th permutation range describes the null distribution; it must not be labeled as a confidence interval for the observed model.

## Leakage rules

Participant folds are created before any learned transformation or model fit. Test-participant data cannot influence scaling, feature selection, regularization selection, stopping decisions, or model choice. If a hyperparameter search is later added, it must occur inside each outer training fold or be fixed before the final grouped evaluation.

## Minimum evidence before a result is discussable

1. A machine-readable dataset audit reports file counts, participant/condition coverage, dimensions, duration distribution, non-finite values, constant channels, duplicate participant-condition keys, duplicate file hashes, and unparseable names.
2. Raw-file orientation, channel order, sampling rate, unit status, and preprocessing status are explicitly recorded as confirmed or unknown.
3. Automated tests verify filename parsing, spectral localization on synthetic signals, participant disjointness, and metric calculations.
4. The exact configuration, random seed, MATLAB/toolbox versions, and source revision are saved with outputs.
5. The README separates observed results from assumptions and limitations.

## Non-goals and prohibited claims

This first repository will not:

- reproduce the paper's reported accuracy or its 465-feature pipeline;
- compare a leaderboard of classifiers or use deep learning;
- generate or reconstruct EEG;
- claim that 27 emotions are biologically discrete;
- call classifier weights neural sources;
- claim generalization to unseen stimuli, spontaneous emotion, clinical use, or real-world deployment.

## Stop condition

The screening repository is complete when one documented command recreates the audit, cached feature table, grouped evaluation, baselines, robustness checks, four core figures, and a short limitations-aware README, and all automated checks pass. Additional architectures or feature families belong to a separately frozen second-stage question; they are not retroactively added to improve the first-stage score.

