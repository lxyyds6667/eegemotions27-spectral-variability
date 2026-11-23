# Does within-trial variation add information beyond average band power?

This is an English translation of the plan recorded before the five-segment experiment. The plan reused the participant folds already examined during baseline development.

## Starting evidence

The whole-trial model reached a macro-F1 of 0.047984 and an accuracy of 5.310%. Across 100 within-participant label permutations, mean macro-F1 was 0.035896 and the highest value was 0.046553. The baseline was insensitive to the 5% duration exclusion rule, but performance differed between the inferred 128 Hz and 256 Hz groups.

A whole-trial average can hide changes in power during a video. The hypothesis was that variation across five segments would improve classification of the 27 video conditions for held-out participants. The comparison keeps the classifier fixed so that the change in representation can be evaluated directly.

## Method specified before examining the follow-up results

1. Keep the 70 whole-trial log absolute band powers. Split each recording into five consecutive, non-overlapping segments of nearly equal length, using every sample.
2. Estimate power in each segment with the baseline frequency bands, a 2-second periodic Hann window, 50% overlap and 0.5 Hz frequency spacing.
3. For each channel and band, take the sample standard deviation of the five segment log powers. This adds 70 features (14 channels × 5 bands) and preserves one observation per trial.
4. Reuse the five participant folds, training-fold standardization and one-vs-all linear logistic ECOC classifier with ridge parameter 0.001. Keep the segment count, window length, bands, folds and model parameters fixed.
5. Save out-of-fold predictions, paired differences by fold, results for each inferred sampling-rate group and the within-participant permutation results.

## Decision rule

The primary outcome was the change in pooled out-of-fold macro-F1 between the 140-feature representation and the 70-feature baseline. Accuracy and balanced accuracy were secondary outcomes. The plan required all four conditions to support a consistent improvement:

- Pooled macro-F1 increases.
- At least four of the five participant folds improve.
- Macro-F1 holds steady or increases in each inferred sampling-rate group.
- The extended model scores higher with the observed labels than in all 100 of its own structured permutations.

If any condition fails, retain the results and treat the hypothesis of a consistent improvement as unsupported. The scope is a single feature comparison using the existing classifier and the same five participant folds.

## Implementation check

Before fitting the real data, test the extractor on synthetic sinusoids. Constant amplitude across all five segments should yield near-zero variation. Changing the amplitude across segments at the same frequency should increase variation in the corresponding band.
