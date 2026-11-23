function comparison = run_duration_exclusion_sensitivity()
%RUN_DURATION_EXCLUSION_SENSITIVITY Retain all structurally usable trials.
%   The primary analysis excludes corrected-duration deviations above 5%.
%   This sensitivity retains those seven trials and excludes only files that
%   cannot support the frozen whole-trial Welch representation.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = default_config();

auditPath = fullfile(cfg.paths.outputs, 'audit', 'data_audit.csv');
featurePath = fullfile(cfg.paths.interim, 'welch_features.mat');
foldPath = fullfile(cfg.paths.outputs, 'modeling', ...
    'participant_fold_assignment.csv');
primaryMetricsPath = fullfile(cfg.paths.outputs, 'modeling', 'metrics.csv');
primaryPredictionPath = fullfile(cfg.paths.outputs, 'modeling', ...
    'oof_predictions.csv');
requiredPaths = [string(auditPath), string(featurePath), string(foldPath), ...
    string(primaryMetricsPath), string(primaryPredictionPath)];
if any(~isfile(requiredPaths))
    error('EEG:PrimaryAnalysisRequired', ...
        'Run audit, feature extraction, and primary modeling first.');
end

fileAudit = readtable(auditPath, 'TextType', 'string');
structuralManifest = make_trial_manifest( ...
    fileAudit, cfg, logical(fileAudit.structural_ready));

loaded = load(featurePath, 'featureTable', 'featureNames');
primaryFeatureTable = loaded.featureTable;
featureNames = string(loaded.featureNames);
isAddedTrial = ~ismember(structuralManifest.trial_id, ...
    primaryFeatureTable.trial_id);
addedManifest = structuralManifest(isAddedTrial, :);
if isempty(addedManifest)
    error('EEG:NoDurationSensitivityTrials', ...
        'Structural-only sensitivity did not add any trials.');
end

fprintf('Extracting features for %d duration-outlier trials...\n', ...
    height(addedManifest));
[addedFeatureTable, addedFeatureNames] = build_feature_table(cfg, addedManifest);
if ~isequal(string(addedFeatureNames), featureNames)
    error('EEG:FeatureNameDrift', ...
        'Sensitivity features do not match the primary feature order.');
end

featureTable = [primaryFeatureTable; addedFeatureTable];
featureTable = sortrows(featureTable, {'participant_id', 'condition_id'});
if height(featureTable) ~= height(structuralManifest) || ...
        ~isequal(featureTable.trial_id, structuralManifest.trial_id)
    error('EEG:SensitivityTrialMismatch', ...
        'Combined sensitivity features do not match the structural manifest.');
end

features = featureTable{:, cellstr(featureNames)};
labels = featureTable.condition_id;
participantIds = featureTable.participant_id;
participantFolds = readtable(foldPath);
[knownParticipant, foldLocation] = ismember( ...
    participantIds, participantFolds.participant_id);
if ~all(knownParticipant)
    error('EEG:SensitivityParticipantMismatch', ...
        'Sensitivity data contain a participant absent from primary folds.');
end
foldId = participantFolds.fold_id(foldLocation);

evaluation = evaluate_grouped_cv( ...
    features, labels, participantIds, foldId, cfg);

primaryMetrics = readtable(primaryMetricsPath, 'TextType', 'string');
primaryPredictions = readtable(primaryPredictionPath, 'TextType', 'string');
primaryRow = primaryMetrics.model == "fourier_linear_ecoc";
analysis = ["primary_5_percent_duration_rule"; ...
    "structural_only_exclusion"];
trialCount = [height(primaryPredictions); height(featureTable)];
macroF1 = [primaryMetrics.macro_f1(primaryRow); evaluation.metrics.macroF1];
balancedAccuracy = [primaryMetrics.balanced_accuracy(primaryRow); ...
    evaluation.metrics.balancedAccuracy];
accuracy = [primaryMetrics.accuracy(primaryRow); evaluation.metrics.accuracy];
comparison = table(analysis, trialCount, macroF1, balancedAccuracy, accuracy, ...
    'VariableNames', {'analysis', 'trial_count', 'macro_f1', ...
    'balanced_accuracy', 'accuracy'});

outputFolder = fullfile(cfg.paths.outputs, 'duration_exclusion_sensitivity');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(comparison, fullfile(outputFolder, 'metrics.csv'));
writetable(evaluation.foldMetrics, fullfile(outputFolder, 'fold_metrics.csv'));

predictions = table(featureTable.trial_id, participantIds, foldId, labels, ...
    featureTable.sampling_rate_hz, evaluation.outOfFoldPrediction, ...
    'VariableNames', {'trial_id', 'participant_id', 'fold_id', ...
    'true_condition_id', 'sampling_rate_hz', 'predicted_condition_id'});
writetable(predictions, ...
    fullfile(outputFolder, 'oof_predictions_structural_only.csv'));

[knownSource, auditLocation] = ismember( ...
    addedManifest.source_relative_path, fileAudit.source_relative_path);
if ~all(knownSource)
    error('EEG:SensitivityAuditMismatch', ...
        'An added sensitivity trial is absent from the saved audit.');
end
addedTrials = table(addedManifest.trial_id, addedManifest.participant_id, ...
    addedManifest.condition_id, addedManifest.source_relative_path, ...
    fileAudit.corrected_duration_seconds(auditLocation), ...
    fileAudit.condition_duration_ratio(auditLocation), ...
    'VariableNames', {'trial_id', 'participant_id', 'condition_id', ...
    'source_relative_path', 'corrected_duration_seconds', ...
    'condition_duration_ratio'});
writetable(addedTrials, fullfile(outputFolder, 'added_trials.csv'));

metadata = struct();
metadata.purpose = ['Sensitivity analysis only: retain every structurally ' ...
    'usable trial regardless of corrected-duration deviation.'];
metadata.primaryPolicy = ...
    'exclude corrected-duration deviations above 5 percent';
metadata.sensitivityPolicy = ...
    'exclude only structurally unusable files';
metadata.sameParticipantsFoldsFeaturesAndModel = true;
metadata.primaryTrialCount = height(primaryPredictions);
metadata.sensitivityTrialCount = height(featureTable);
metadata.addedDurationOutlierCount = height(addedManifest);
metadata.generatedAt = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
write_duration_json(fullfile(outputFolder, 'metadata.json'), metadata);

fprintf(['Duration-exclusion sensitivity macro-F1: primary %.4f; ' ...
    'structural-only %.4f (%d added trials).\n'], ...
    macroF1(1), macroF1(2), height(addedManifest));
end

function write_duration_json(filePath, value)
fileId = fopen(filePath, 'w');
if fileId < 0
    error('EEG:OutputOpenFailed', 'Cannot open output file: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(value, 'PrettyPrint', true));
end
