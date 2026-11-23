function scores = run_fixed_window_control()
%RUN_FIXED_WINDOW_CONTROL Compare three EEG representations on the same trials.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'config'), fullfile(root, 'src'));
cfg = default_config();
verify_results();
verify_temporal_extension();

modelFolder = fullfile(cfg.paths.outputs, 'modeling');
temporalFile = fullfile(cfg.paths.outputs, 'temporal_extension', 'oof_predictions.csv');
foldFile = fullfile(modelFolder, 'fold_manifest.csv');
featureFile = fullfile(cfg.paths.interim, 'welch_features.mat');
modelRun = jsondecode(fileread(fullfile(modelFolder, 'run_manifest.json')));
assert(sha256_file(featureFile) == string(modelRun.featureMatSha256), ...
    'Whole-trial feature cache differs from the baseline fit.');
cache = load(featureFile, 'featureTable', 'featureNames', 'cfg');
assert(isequal(cfg.welch, cache.cfg.welch) && isequal(cfg.bands, cache.cfg.bands) && ...
    isequal(cfg.features, cache.cfg.features) && isequal(cfg.model, cache.cfg.model) && ...
    isequal(cfg.data.channelNames, cache.cfg.data.channelNames), ...
    'The spectrum, channel order or classifier settings differ from the baseline.');
trials = sortrows(cache.featureTable, 'trial_id');
predictions = sortrows(readtable(temporalFile, 'TextType', 'string'), 'trial_id');
assert(isequal(trials.trial_id, predictions.trial_id) && ...
    isequal(trials.participant_id, predictions.participant_id) && ...
    isequal(trials.condition_id, predictions.true_condition_id) && ...
    isequal(trials.sampling_rate_hz, predictions.sampling_rate_hz), ...
    'Cached trials and saved held-out predictions disagree.');

baseFeatures = trials{:, cellstr(cache.featureNames)};
[centerFeatures, minWindows, maxWindows, fixedWindows] = centered_features(trials, cfg);
fit = evaluate_grouped_cv([baseFeatures centerFeatures], trials.condition_id, ...
    trials.participant_id, predictions.fold_id, cfg);
predictions = renamevars(predictions, 'extended_prediction', 'full_fifths_prediction');
predictions.fixed_window_prediction = fit.outOfFoldPrediction;
duration = trials.sample_count ./ trials.sampling_rate_hz;
classes = cfg.data.expectedEmotionIds;
predictions.duration_only_prediction = duration_predictions( ...
    duration, trials.condition_id, predictions.fold_id, classes);
predictions.original_min_windows = minWindows;
predictions.original_max_windows = maxWindows;
predictions.fixed_windows_per_block = fixedWindows;
scores = summarize_predictions(predictions, classes);

audit = jsondecode(fileread(fullfile(cfg.paths.outputs, 'audit', 'audit_summary.json')));
meta.upstream_commit = audit.upstream.commit;
meta.plan_sha256 = sha256_file(fullfile(root, 'fixed-window-control-plan.md'));
meta.baseline_features_sha256 = modelRun.featureMatSha256;
meta.fold_manifest_sha256 = sha256_file(foldFile);
meta.temporal_predictions_sha256 = sha256_file(temporalFile);
meta.raw_files_verified = height(trials);
meta.participant_count = numel(unique(trials.participant_id));
meta.whole_trial_features = size(baseFeatures, 2);
meta.added_features = size(centerFeatures, 2);
meta.block_seconds = 3;
meta.window_seconds = cfg.welch.windowSeconds;
meta.overlap_fraction = cfg.welch.overlapFraction;
meta.windows_per_block = 2;
meta.matlab_release = version('-release');
meta.model = fit.modelDescription;
meta.bootstrap = fixed_window_gain_interval(predictions, classes);

% Validate the completed set of files before publishing it.
staging = tempname(cfg.paths.outputs);
mkdir(staging);
cleanup = onCleanup(@() remove_staging(staging));
writetable(predictions, fullfile(staging, 'oof_predictions.csv'));
writetable(scores, fullfile(staging, 'metrics.csv'));
plot_fixed_window_control(scores, fullfile(staging, 'fold_comparison.png'));
meta.predictions_sha256 = sha256_file(fullfile(staging, 'oof_predictions.csv'));
meta.metrics_sha256 = sha256_file(fullfile(staging, 'metrics.csv'));
writelines(string(jsonencode(meta, 'PrettyPrint', true)), fullfile(staging, 'metadata.json'));
verify_fixed_window_control(staging);

resultFolder = fullfile(cfg.paths.outputs, 'fixed_window_control');
if isfolder(resultFolder)
    % Preserve extra files. Publishing metadata last lets readers verify the set.
    for name = ["oof_predictions.csv", "metrics.csv", "fold_comparison.png", "metadata.json"]
        movefile(fullfile(staging, name), fullfile(resultFolder, name), 'f');
    end
else
    movefile(staging, resultFolder);
end
disp(scores(scores.scope == "all", :));
fprintf('Paired participant interval for fixed-window minus whole-trial macro-F1: [%.5f, %.5f].\n', ...
    meta.bootstrap.lower, meta.bootstrap.upper);
end

function [features, minWindows, maxWindows, fixedWindows] = centered_features(trials, cfg)
numTrials = height(trials);
features = zeros(numTrials, cfg.data.expectedChannelCount * numel(cfg.bands.names));
minWindows = zeros(numTrials, 1);
maxWindows = zeros(numTrials, 1);
fixedWindows = zeros(numTrials, 1);
for k = 1:numTrials
    fs = trials.sampling_rate_hz(k);
    cfg.data.samplingRateHz = fs;
    path = fullfile(cfg.paths.datasetRoot, trials.source_relative_path(k));
    assert(sha256_file(path) == trials.sha256(k), 'Source hash changed for %s.', trials.trial_id(k));
    eeg = load_eeg_trial(path, cfg.data.expectedChannelCount);
    assert(size(eeg, 1) == trials.sample_count(k), 'Trial length changed.');
    [features(k,:), ~, edges, blocks] = extract_temporal_variability(eeg, cfg, "centered3s");
    window = round(cfg.welch.windowSeconds * fs);
    step = window - round(cfg.welch.overlapFraction * window);
    originalCounts = 1 + floor((diff(edges) - window) / step);
    blockLengths = blocks(:,2) - blocks(:,1) + 1;
    centeredCounts = 1 + floor((blockLengths - window) / step);
    assert(all(blockLengths == 3*fs & centeredCounts == 2), 'Unexpected centered block size.');
    minWindows(k) = min(originalCounts);
    maxWindows(k) = max(originalCounts);
    fixedWindows(k) = centeredCounts(1);
    if mod(k, 400) == 0 || k == numTrials
        fprintf('Checked raw files and extracted fixed windows for %d/%d trials.\n', k, numTrials);
    end
end
end

function predicted = duration_predictions(seconds, labels, folds, classes)
% MATLAB min returns the first match, so ascending class IDs resolve exact ties.
classes = sort(classes(:));
predicted = zeros(size(labels));
for fold = unique(folds)'
    test = folds == fold;
    medians = arrayfun(@(c) median(seconds(~test & labels == c)), classes);
    assert(all(isfinite(medians)), 'A training fold lacks a condition.');
    [~, nearest] = min(abs(seconds(test) - medians'), [], 2);
    predicted(test) = classes(nearest);
end
end

function scores = summarize_predictions(p, classes)
methods = ["whole_trial","full_fifths","centered_3s","duration_only"];
predicted = [p.baseline_prediction, p.full_fifths_prediction, ...
    p.fixed_window_prediction, p.duration_only_prediction];
scopes = ["all","fold_"+string(1:5),"rate_128","rate_256"];
masks = [true(height(p),1), p.fold_id == (1:5), p.sampling_rate_hz == [128 256]];
scores = table();
for s = 1:numel(scopes)
    rows = masks(:,s);
    truth = p.true_condition_id(rows);
    for m = 1:numel(methods)
        guess = predicted(rows,m);
        metrics = compute_classification_metrics(truth, guess, classes);
        assert(all(metrics.support > 0), 'A comparison subset lacks a condition.');
        row = table(scopes(s), methods(m), numel(truth), nnz(guess == truth), ...
            metrics.macroF1, metrics.accuracy, metrics.balancedAccuracy, ...
            'VariableNames', {'scope','method','trial_count','correct_count', ...
            'macro_f1','accuracy','balanced_accuracy'});
        scores = [scores; row]; %#ok<AGROW>
    end
end
end

function remove_staging(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end
