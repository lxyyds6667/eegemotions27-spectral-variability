function [ablationTable, fullEvaluation, ablationFoldTable] = run_band_ablation( ...
    features, featureNames, labels, participantIds, foldId, cfg)
%RUN_BAND_ABLATION Remove complete bands and reuse the identical folds.

arguments
    features (:,:) double
    featureNames (1,:) string
    labels (:,1) double
    participantIds (:,1) double
    foldId (:,1) double
    cfg (1,1) struct
end

if size(features, 2) ~= numel(featureNames)
    error('EEG:FeatureNameCount', 'Feature name count must equal the number of columns.');
end

fullEvaluation = evaluate_grouped_cv(features, labels, participantIds, foldId, cfg);
numBands = numel(cfg.bands.names);
numVariants = numBands + 1;
variant = strings(numVariants, 1);
removedBand = strings(numVariants, 1);
remainingFeatureCount = zeros(numVariants, 1);
macroF1 = zeros(numVariants, 1);
balancedAccuracy = zeros(numVariants, 1);
accuracy = zeros(numVariants, 1);

variant(1) = "ALL";
removedBand(1) = "none";
remainingFeatureCount(1) = size(features, 2);
macroF1(1) = fullEvaluation.metrics.macroF1;
balancedAccuracy(1) = fullEvaluation.metrics.balancedAccuracy;
accuracy(1) = fullEvaluation.metrics.accuracy;
baseFold = fullEvaluation.foldMetrics;
baseFold.variant = repmat("ALL", height(baseFold), 1);
baseFold.removed_band = repmat("none", height(baseFold), 1);
baseFold.delta_macro_f1 = zeros(height(baseFold), 1);
baseFold.delta_balanced_accuracy = zeros(height(baseFold), 1);
baseFold.delta_accuracy = zeros(height(baseFold), 1);
ablationFoldTable = baseFold;

for bandIndex = 1:numBands
    rowIndex = bandIndex + 1;
    removedBand(rowIndex) = string(cfg.bands.names{bandIndex});
    variant(rowIndex) = "remove_" + removedBand(rowIndex);
    suffix = "__" + removedBand(rowIndex);
    removedColumns = endsWith(featureNames, suffix);
    if ~any(removedColumns)
        error('EEG:MissingBandFeatures', 'No feature names end with %s.', suffix);
    end
    remainingFeatureCount(rowIndex) = sum(~removedColumns);
    reducedEvaluation = evaluate_grouped_cv( ...
        features(:, ~removedColumns), labels, participantIds, foldId, cfg);
    macroF1(rowIndex) = reducedEvaluation.metrics.macroF1;
    balancedAccuracy(rowIndex) = reducedEvaluation.metrics.balancedAccuracy;
    accuracy(rowIndex) = reducedEvaluation.metrics.accuracy;

    foldRows = reducedEvaluation.foldMetrics;
    foldRows.variant = repmat(variant(rowIndex), height(foldRows), 1);
    foldRows.removed_band = repmat(removedBand(rowIndex), height(foldRows), 1);
    foldRows.delta_macro_f1 = foldRows.macro_f1 - baseFold.macro_f1;
    foldRows.delta_balanced_accuracy = ...
        foldRows.balanced_accuracy - baseFold.balanced_accuracy;
    foldRows.delta_accuracy = foldRows.accuracy - baseFold.accuracy;
    ablationFoldTable = [ablationFoldTable; foldRows]; %#ok<AGROW>
end

ablationTable = table(variant, removedBand, remainingFeatureCount, macroF1, ...
    balancedAccuracy, accuracy);
ablationTable.delta_macro_f1 = macroF1 - fullEvaluation.metrics.macroF1;
ablationTable.delta_balanced_accuracy = ...
    balancedAccuracy - fullEvaluation.metrics.balancedAccuracy;
ablationTable.delta_accuracy = accuracy - fullEvaluation.metrics.accuracy;
end

