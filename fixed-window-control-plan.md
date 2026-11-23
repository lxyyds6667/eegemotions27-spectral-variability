# Does the five-segment result survive equal Welch window counts?

This sensitivity analysis was specified after inspecting the first two models and the duration-only diagnostic, and before fitting the centered-block model. The comparison uses the existing fixed-video protocol and participant folds.

## One change to the EEG representation

1. Use all 2,335 primary trials, the original 70 whole-trial features and the existing five folds. Use each participant's inferred effective sample rate.
2. For a trial with `N` samples, set the six boundaries to `floor((0:5)*N/5)`. In each fifth, take 3 consecutive seconds centered within that fifth. For a fifth of length `L` samples, skip `floor((L - 3*Fs)/2)` samples on the left. Keep exactly `3*Fs` samples. Stop on any trial that cannot supply all five blocks.
3. Each block supplies two overlapping 2-second Hann windows with a 1-second step. Keep the original frequency bins, bands and log-power calculation. For each channel and band, take the sample standard deviation of the five block estimates. Append the resulting 70 values to the original 70.
4. Fit the same one-vs-all ridge logistic model (`lambda = 0.001`). Estimate normalization inside each training fold. Each trial supplies one prediction from a model trained on other participants.

## Comparison and interpretation

The primary quantity is the difference in pooled 27-class macro-F1 between the centered-block model and the 70-feature baseline. Report the prior full-fifths result alongside both models. Report correct counts, accuracy and balanced accuracy, plus descriptive macro-F1 differences by fold and inferred-rate group.

For the primary difference, draw 2,000 paired resamples of the 88 participants with replacement using MATLAB's local MT19937 stream, seed 2704. Bring along all saved predictions for each selected participant. Report the 2.5th and 97.5th percentiles conditional on these predictions. The folds share training data. The interval describes participant-to-participant sampling variation in the saved comparison and does not include the uncertainty of retraining.

For context, independently predict condition from recording duration (sample count divided by inferred rate). For each held-out fold, use the nearest of the 27 training-condition medians, breaking an exact tie by the lower condition ID. Duration is an input only to this protocol diagnostic.

A residual gain after matching window counts is compatible with information beyond the number of Welch windows in a fifth. A reduction in gain shows sensitivity to how the fifths are sampled. Taking only their centers also reduces signal coverage, and their spacing still depends on trial length. All participants saw the same stimulus set. These constraints limit attribution to a specific cause. Report the comparison once, including a zero or negative difference.
