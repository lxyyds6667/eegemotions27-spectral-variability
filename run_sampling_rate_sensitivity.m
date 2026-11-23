function comparison = run_sampling_rate_sensitivity()
%RUN_SAMPLING_RATE_SENSITIVITY Treat every file as the documented 256 Hz.
%   This deliberately misspecified alternative uses the identical trials,
%   folds, features, model, and metrics. It tests the impact of the mixed-rate
%   correction; it is not a second candidate model.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = default_config();

manifestPath = fullfile(cfg.paths.outputs, 'audit', 'trial_manifest.csv');
primaryFoldPath = fullfile(cfg.paths.outputs, 'modeling', 'fold_manifest.csv');
primaryMetricsPath = fullfile(cfg.paths.outputs, 'modeling', 'metrics.csv');
if ~isfile(manifestPath) || ~isfile(primaryFoldPath) || ~isfile(primaryMetricsPath)
    error('EEG:PrimaryAnalysisRequired', ...
        'Run the audit and primary modeling before this sensitivity analysis.');
end

trialManifest = readtable(manifestPath, 'TextType', 'string');
trialManifest.sampling_rate_hz(:) = cfg.data.samplingRateHz;
trialManifest.sampling_rate_basis(:) = ...
    "sensitivity: documented 256 Hz forced for every participant";

[featureTable, featureNames] = build_feature_table(cfg, trialManifest);
features = featureTable{:, cellstr(featureNames)};
labels = featureTable.condition_id;
participantIds = featureTable.participant_id;

primaryFold = readtable(primaryFoldPath, 'TextType', 'string');
[knownTrial, foldLocation] = ismember(featureTable.trial_id, primaryFold.trial_id);
if ~all(knownTrial)
    error('EEG:SensitivityTrialMismatch', ...
        'Sensitivity feature table does not match the primary trial set.');
end
foldId = primaryFold.fold_id(foldLocation);

evaluation = evaluate_grouped_cv( ...
    features, labels, participantIds, foldId, cfg);

primaryMetrics = readtable(primaryMetricsPath, 'TextType', 'string');
primaryRow = primaryMetrics.model == "fourier_linear_ecoc";
analysis = ["participant_rate_corrected"; "all_files_forced_256_hz"];
macroF1 = [primaryMetrics.macro_f1(primaryRow); evaluation.metrics.macroF1];
balancedAccuracy = [primaryMetrics.balanced_accuracy(primaryRow); ...
    evaluation.metrics.balancedAccuracy];
accuracy = [primaryMetrics.accuracy(primaryRow); evaluation.metrics.accuracy];
comparison = table(analysis, macroF1, balancedAccuracy, accuracy, ...
    'VariableNames', {'analysis', 'macro_f1', 'balanced_accuracy', 'accuracy'});

outputFolder = fullfile(cfg.paths.outputs, 'sampling_rate_sensitivity');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
writetable(comparison, fullfile(outputFolder, 'metrics.csv'));
writetable(evaluation.foldMetrics, fullfile(outputFolder, 'fold_metrics.csv'));
predictions = table(featureTable.trial_id, participantIds, foldId, labels, ...
    evaluation.outOfFoldPrediction, ...
    'VariableNames', {'trial_id', 'participant_id', 'fold_id', ...
    'true_condition_id', 'predicted_condition_id'});
writetable(predictions, fullfile(outputFolder, 'oof_predictions_all_256.csv'));

metadata = struct();
metadata.purpose = ['Sensitivity analysis only: force the repository-documented ' ...
    '256 Hz rate on every file despite the released-data length clusters.'];
metadata.sameTrialsAndFoldsAsPrimary = true;
metadata.primaryFeatureInterpretation = ...
    'participant-level 128/256 Hz inferred before modeling';
metadata.sensitivityFeatureInterpretation = 'all files forced to 256 Hz';
metadata.generatedAt = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
write_sensitivity_json(fullfile(outputFolder, 'metadata.json'), metadata);

fprintf('Sampling-rate sensitivity macro-F1: corrected %.4f; forced-256 %.4f.\n', ...
    macroF1(1), macroF1(2));
end

function write_sensitivity_json(filePath, value)
fileId = fopen(filePath, 'w');
if fileId < 0
    error('EEG:OutputOpenFailed', 'Cannot open output file: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(value, 'PrettyPrint', true));
end

