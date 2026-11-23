function permutation = run_structured_permutation_baseline( ...
    features, labels, participantIds, foldId, cfg, observedMetrics)
%RUN_STRUCTURED_PERMUTATION_BASELINE Refit on within-participant null labels.

arguments
    features (:,:) double
    labels (:,1) double
    participantIds (:,1) double
    foldId (:,1) double
    cfg (1,1) struct
    observedMetrics (1,1) struct
end

numRepeats = cfg.permutation.numRepeats;
macroF1 = zeros(numRepeats, 1);
balancedAccuracy = zeros(numRepeats, 1);
accuracy = zeros(numRepeats, 1);
seed = (cfg.permutation.seed + (0:(numRepeats - 1)))';
permutationTimer = tic;

for repeatIndex = 1:numRepeats
    nullLabels = permute_labels_within_participant( ...
        labels, participantIds, seed(repeatIndex));
    nullEvaluation = evaluate_grouped_cv( ...
        features, nullLabels, participantIds, foldId, cfg);
    macroF1(repeatIndex) = nullEvaluation.metrics.macroF1;
    balancedAccuracy(repeatIndex) = nullEvaluation.metrics.balancedAccuracy;
    accuracy(repeatIndex) = nullEvaluation.metrics.accuracy;
    if mod(repeatIndex, 10) == 0 || repeatIndex == numRepeats
        fprintf('Completed %d/%d structured permutations (%.1f s).\n', ...
            repeatIndex, numRepeats, toc(permutationTimer));
    end
end

permutation = struct();
permutation.repeats = table(seed, macroF1, balancedAccuracy, accuracy, ...
    'VariableNames', {'seed', 'macro_f1', 'balanced_accuracy', 'accuracy'});
permutation.macroF1Mean = mean(macroF1);
permutation.balancedAccuracyMean = mean(balancedAccuracy);
permutation.accuracyMean = mean(accuracy);
permutation.macroF195PercentInterval = prctile(macroF1, [2.5, 97.5]);
permutation.macroF1EmpiricalP = ...
    (1 + sum(macroF1 >= observedMetrics.macroF1)) / (numRepeats + 1);
end

