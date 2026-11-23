function results = run_modeling()
%RUN_MODELING Execute the frozen participant-grouped baseline and ablations.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = default_config();

featurePath = fullfile(cfg.paths.interim, 'welch_features.mat');
auditSummaryPath = fullfile(cfg.paths.outputs, 'audit', 'audit_summary.json');
if ~isfile(featurePath)
    error('EEG:FeaturesRequired', 'Run run_feature_extraction before modeling.');
end
if ~isfile(auditSummaryPath)
    error('EEG:AuditRequired', 'Audit summary is missing.');
end

loaded = load(featurePath, 'featureTable', 'featureNames');
featureTable = loaded.featureTable;
featureNames = string(loaded.featureNames);
features = featureTable{:, cellstr(featureNames)};
labels = featureTable.condition_id;
participantIds = featureTable.participant_id;

[foldId, participantFoldTable] = assign_participant_folds( ...
    participantIds, cfg.cv.numFolds, cfg.cv.seed);

outputFolder = fullfile(cfg.paths.outputs, 'modeling');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

foldManifest = featureTable(:, {'trial_id', 'participant_id', 'condition_id', ...
    'source_relative_path', 'sampling_rate_hz'});
foldManifest.fold_id = foldId;
writetable(foldManifest, fullfile(outputFolder, 'fold_manifest.csv'));
writetable(participantFoldTable, ...
    fullfile(outputFolder, 'participant_fold_assignment.csv'));

classSupport = zeros(cfg.cv.numFolds, numel(cfg.data.expectedEmotionIds));
for fold = 1:cfg.cv.numFolds
    for classIndex = 1:numel(cfg.data.expectedEmotionIds)
        classSupport(fold, classIndex) = sum( ...
            foldId == fold & labels == cfg.data.expectedEmotionIds(classIndex));
    end
end
classSupportTable = array2table(classSupport, ...
    'VariableNames', compose('condition_%02d', cfg.data.expectedEmotionIds));
classSupportTable = addvars(classSupportTable, (1:cfg.cv.numFolds)', ...
    'Before', 1, 'NewVariableNames', 'fold_id');
writetable(classSupportTable, fullfile(outputFolder, 'fold_class_support.csv'));

fprintf('Running full model and five paired band ablations...\n');
[ablationTable, fullEvaluation, ablationFoldTable] = run_band_ablation( ...
    features, featureNames, labels, participantIds, foldId, cfg);

fprintf('Running %d uniform-random baseline repeats...\n', ...
    cfg.randomBaseline.numRepeats);
uniformBaseline = run_uniform_random_baseline( ...
    labels, cfg.data.expectedEmotionIds, ...
    cfg.randomBaseline.numRepeats, cfg.randomBaseline.seed);

fprintf('Running %d participant-structured label permutations...\n', ...
    cfg.permutation.numRepeats);
permutation = run_structured_permutation_baseline( ...
    features, labels, participantIds, foldId, cfg, fullEvaluation.metrics);

conditionNames = string(cfg.data.emotionNames(:));
trueConditionName = conditionNames(labels);
predictedConditionName = conditionNames(fullEvaluation.outOfFoldPrediction);
majorityConditionName = conditionNames(fullEvaluation.majorityPrediction);
oofPredictions = table(featureTable.trial_id, participantIds, foldId, ...
    labels, trueConditionName, fullEvaluation.outOfFoldPrediction, ...
    predictedConditionName, fullEvaluation.majorityPrediction, ...
    majorityConditionName, ...
    'VariableNames', {'trial_id', 'participant_id', 'fold_id', ...
    'true_condition_id', 'true_condition_name', 'predicted_condition_id', ...
    'predicted_condition_name', 'majority_condition_id', ...
    'majority_condition_name'});
writetable(oofPredictions, fullfile(outputFolder, 'oof_predictions.csv'));

samplingGroupMetrics = compute_sampling_group_metrics( ...
    labels, fullEvaluation.outOfFoldPrediction, participantIds, ...
    featureTable.sampling_rate_hz, cfg.data.expectedEmotionIds);
writetable(samplingGroupMetrics, ...
    fullfile(outputFolder, 'sampling_rate_group_metrics.csv'));

modelName = ["fourier_linear_ecoc"; "train_fold_majority"; ...
    "uniform_random_mean"; "structured_permutation_mean"; ...
    "theoretical_uniform_accuracy"];
macroF1 = [fullEvaluation.metrics.macroF1; ...
    fullEvaluation.majorityMetrics.macroF1; ...
    uniformBaseline.meanMacroF1; permutation.macroF1Mean; NaN];
balancedAccuracy = [fullEvaluation.metrics.balancedAccuracy; ...
    fullEvaluation.majorityMetrics.balancedAccuracy; ...
    uniformBaseline.meanBalancedAccuracy; ...
    permutation.balancedAccuracyMean; NaN];
accuracy = [fullEvaluation.metrics.accuracy; ...
    fullEvaluation.majorityMetrics.accuracy; ...
    uniformBaseline.meanAccuracy; permutation.accuracyMean; ...
    1 / numel(cfg.data.expectedEmotionIds)];
metricsTable = table(modelName, macroF1, balancedAccuracy, accuracy, ...
    'VariableNames', {'model', 'macro_f1', 'balanced_accuracy', 'accuracy'});
writetable(metricsTable, fullfile(outputFolder, 'metrics.csv'));
writetable(fullEvaluation.foldMetrics, ...
    fullfile(outputFolder, 'model_fold_metrics.csv'));

classMetrics = table(fullEvaluation.metrics.classIds, ...
    conditionNames(fullEvaluation.metrics.classIds), ...
    fullEvaluation.metrics.support, fullEvaluation.metrics.precision, ...
    fullEvaluation.metrics.recall, fullEvaluation.metrics.f1, ...
    'VariableNames', {'condition_id', 'condition_name', 'support', ...
    'precision', 'recall', 'f1'});
writetable(classMetrics, fullfile(outputFolder, 'class_metrics.csv'));

confusionCounts = fullEvaluation.metrics.confusionMatrix;
rowTotals = sum(confusionCounts, 2);
confusionRowNormalized = confusionCounts ./ max(rowTotals, 1);
predictionVariableNames = compose('pred_%02d', cfg.data.expectedEmotionIds);
confusionCountTable = array2table(confusionCounts, ...
    'VariableNames', predictionVariableNames);
confusionCountTable = addvars(confusionCountTable, cfg.data.expectedEmotionIds, ...
    'Before', 1, 'NewVariableNames', 'true_condition_id');
confusionNormalizedTable = array2table(confusionRowNormalized, ...
    'VariableNames', predictionVariableNames);
confusionNormalizedTable = addvars(confusionNormalizedTable, ...
    cfg.data.expectedEmotionIds, 'Before', 1, ...
    'NewVariableNames', 'true_condition_id');
writetable(confusionCountTable, fullfile(outputFolder, 'confusion_counts.csv'));
writetable(confusionNormalizedTable, ...
    fullfile(outputFolder, 'confusion_row_normalized.csv'));

writetable(ablationTable, fullfile(outputFolder, 'band_ablation.csv'));
writetable(ablationFoldTable, ...
    fullfile(outputFolder, 'band_ablation_fold_metrics.csv'));
writetable(uniformBaseline.repeats, ...
    fullfile(outputFolder, 'uniform_random_baseline.csv'));
writetable(permutation.repeats, ...
    fullfile(outputFolder, 'structured_permutation_baseline.csv'));

normalizationTable = normalization_to_table( ...
    fullEvaluation.normalization, featureNames);
writetable(normalizationTable, ...
    fullfile(outputFolder, 'fold_normalization_parameters.csv'));

confusionFigure = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 760, 680]);
confusionColorMaximum = max(confusionRowNormalized, [], 'all');
imagesc(confusionRowNormalized, [0, confusionColorMaximum]);
axis square;
colormap(confusionFigure, parula(256));
colorbar;
xlabel('Predicted condition ID');
ylabel('True condition ID');
title('Participant-held-out OOF confusion matrix (row-normalized)');
xticks(1:27); yticks(1:27);
exportgraphics(confusionFigure, ...
    fullfile(outputFolder, 'confusion_matrix.png'), 'Resolution', 180);
close(confusionFigure);

ablationFigure = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 800, 520]);
ablationRows = 2:height(ablationTable);
bar(1:numel(ablationRows), ablationTable.delta_macro_f1(ablationRows), ...
    'FaceColor', [0.25, 0.55, 0.72]);
hold on;
for bandIndex = 1:numel(ablationRows)
    bandName = ablationTable.removedBand(ablationRows(bandIndex));
    foldRows = ablationFoldTable.removed_band == bandName;
    scatter(repmat(bandIndex, sum(foldRows), 1), ...
        ablationFoldTable.delta_macro_f1(foldRows), 32, ...
        'filled', 'MarkerFaceColor', [0.12, 0.20, 0.30]);
end
yline(0, '--k');
xticks(1:numel(ablationRows));
xticklabels(ablationTable.removedBand(ablationRows));
set(gca, 'TickLabelInterpreter', 'none');
xlabel('Removed band (all channels)');
ylabel('\Delta macro-F1 vs all bands');
title('Paired leave-one-band-out predictive contribution');
grid on;
box off;
exportgraphics(ablationFigure, ...
    fullfile(outputFolder, 'band_ablation.png'), 'Resolution', 180);
close(ablationFigure);

permutationFigure = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 760, 500]);
histogram(permutation.repeats.macro_f1, 20, ...
    'FaceColor', [0.55, 0.65, 0.72], 'EdgeColor', 'white');
hold on;
xline(fullEvaluation.metrics.macroF1, '-', 'Observed', ...
    'Color', [0.80, 0.20, 0.15], 'LineWidth', 2);
xline(fullEvaluation.majorityMetrics.macroF1, '--', 'Majority', ...
    'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.3);
xlabel('OOF macro-F1');
ylabel('Permutation count');
title('Within-participant structured permutation baseline');
box off;
exportgraphics(permutationFigure, ...
    fullfile(outputFolder, 'permutation_baseline.png'), 'Resolution', 180);
close(permutationFigure);

write_json(fullfile(outputFolder, 'config.json'), make_portable_config(cfg));

results = struct();
results.fullEvaluation = fullEvaluation;
results.ablationTable = ablationTable;
results.ablationFoldTable = ablationFoldTable;
results.uniformBaseline = uniformBaseline;
results.permutation = permutation;
results.samplingGroupMetrics = samplingGroupMetrics;
save(fullfile(outputFolder, 'evaluation_results.mat'), 'results', '-v7.3');

manifest = build_run_manifest(projectRoot, outputFolder, ...
    featurePath, auditSummaryPath, cfg, fullEvaluation, permutation);
write_json(fullfile(outputFolder, 'run_manifest.json'), manifest);

fprintf('Observed OOF macro-F1: %.4f.\n', fullEvaluation.metrics.macroF1);
fprintf('Observed OOF balanced accuracy: %.4f.\n', ...
    fullEvaluation.metrics.balancedAccuracy);
fprintf('Observed OOF accuracy: %.4f.\n', fullEvaluation.metrics.accuracy);
fprintf('Majority macro-F1: %.4f; permutation mean: %.4f; empirical p: %.4g.\n', ...
    fullEvaluation.majorityMetrics.macroF1, permutation.macroF1Mean, ...
    permutation.macroF1EmpiricalP);
fprintf('Modeling outputs: %s\n', outputFolder);
end

function output = normalization_to_table(normalization, featureNames)
numFolds = numel(normalization);
numFeatures = numel(featureNames);
foldId = repelem((1:numFolds)', numFeatures);
featureName = repmat(featureNames(:), numFolds, 1);
trainingMean = zeros(numFolds * numFeatures, 1);
trainingScale = zeros(numFolds * numFeatures, 1);
for fold = 1:numFolds
    rows = (fold - 1) * numFeatures + (1:numFeatures);
    trainingMean(rows) = normalization(fold).mean(:);
    trainingScale(rows) = normalization(fold).scale(:);
end
output = table(foldId, featureName, trainingMean, trainingScale, ...
    'VariableNames', {'fold_id', 'feature_name', 'training_mean', 'training_scale'});
end

function manifest = build_run_manifest(projectRoot, outputFolder, ...
    featurePath, auditSummaryPath, cfg, evaluation, permutation)
manifest = struct();
manifest.generatedAt = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
manifest.runCommand = 'run_modeling';
manifest.projectGitRevision = git_revision(projectRoot);
manifest.featureMatSha256 = char(sha256_file(string(featurePath)));
manifest.auditSummarySha256 = char(sha256_file(string(auditSummaryPath)));
manifest.cvSeed = cfg.cv.seed;
manifest.permutationSeed = cfg.permutation.seed;
manifest.randomBaselineSeed = cfg.randomBaseline.seed;
manifest.matlabVersion = version;
manifest.matlabRelease = version('-release');
manifest.modelDescription = evaluation.modelDescription;
manifest.observedMacroF1 = evaluation.metrics.macroF1;
manifest.permutationEmpiricalP = permutation.macroF1EmpiricalP;

files = dir(fullfile(outputFolder, '*'));
files = files(~[files.isdir] & ~strcmp({files.name}, 'run_manifest.json'));
outputName = strings(numel(files), 1);
outputSha256 = strings(numel(files), 1);
for fileIndex = 1:numel(files)
    outputName(fileIndex) = string(files(fileIndex).name);
    outputSha256(fileIndex) = sha256_file(string( ...
        fullfile(files(fileIndex).folder, files(fileIndex).name)));
end
manifest.outputs = table2struct(table(outputName, outputSha256));
end

function revision = git_revision(folder)
command = sprintf('git -C "%s" rev-parse HEAD', folder);
[status, output] = system(command);
if status == 0
    revision = strtrim(output);
else
    revision = 'uncommitted_worktree';
end
end

function write_json(filePath, value)
fileId = fopen(filePath, 'w');
if fileId < 0
    error('EEG:OutputOpenFailed', 'Cannot open output file: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(value, 'PrettyPrint', true));
end

