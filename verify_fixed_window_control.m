function verification = verify_fixed_window_control(outputFolder)
%VERIFY_FIXED_WINDOW_CONTROL Verify the offline equal-window control outputs.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'));
if nargin == 0 || isempty(outputFolder)
    outputFolder = fullfile(root, 'outputs', 'fixed_window_control');
end
outputFolder = string(outputFolder);
assert(isfolder(outputFolder), 'Fixed-window output folder is missing.');

out = fullfile(outputFolder, 'oof_predictions.csv');
met = fullfile(outputFolder, 'metrics.csv');
metaFile = fullfile(outputFolder, 'metadata.json');
foldFile = fullfile(root, 'outputs', 'modeling', 'fold_manifest.csv');
baseFile = fullfile(root, 'outputs', 'modeling', 'oof_predictions.csv');
temporalFile = fullfile(root, 'outputs', 'temporal_extension', 'oof_predictions.csv');
trialFile = fullfile(root, 'outputs', 'audit', 'trial_manifest.csv');
runFile = fullfile(root, 'outputs', 'modeling', 'run_manifest.json');
assert(all(cellfun(@isfile, {out, met, metaFile, foldFile, baseFile, ...
    temporalFile, trialFile, runFile})), 'A required verification artifact is missing.');

p = sortrows(readtable(out, 'TextType', 'string'), 'trial_id');
m = readtable(met, 'TextType', 'string');
fold = sortrows(readtable(foldFile, 'TextType', 'string'), 'trial_id');
base = sortrows(readtable(baseFile, 'TextType', 'string'), 'trial_id');
temporal = sortrows(readtable(temporalFile, 'TextType', 'string'), 'trial_id');
trial = sortrows(readtable(trialFile, 'TextType', 'string'), 'trial_id');
assert(height(p) == 2335 && numel(unique(p.trial_id)) == height(p) && ...
    isequal(p.trial_id, fold.trial_id, base.trial_id, temporal.trial_id, trial.trial_id), ...
    'The trial sets differ from the 2,335 unique reference trials.');

assert(all(p.participant_id == fold.participant_id) && all(p.fold_id == fold.fold_id) && ...
    all(p.true_condition_id == fold.condition_id) && ...
    all(p.sampling_rate_hz == fold.sampling_rate_hz), 'New and old folds do not align.');
assert(all(base.participant_id == p.participant_id) && all(base.fold_id == p.fold_id) && ...
    all(base.true_condition_id == p.true_condition_id), 'Old predictions do not align.');
assert(all(temporal.participant_id == p.participant_id) && all(temporal.fold_id == p.fold_id) && ...
    all(temporal.true_condition_id == p.true_condition_id) && ...
    all(temporal.sampling_rate_hz == p.sampling_rate_hz), 'Temporal predictions do not align.');
assert(all(trial.participant_id == p.participant_id) && ...
    all(trial.condition_id == p.true_condition_id) && ...
    all(trial.sampling_rate_hz == p.sampling_rate_hz) && ...
    all(trial.exclusion_status == "included"), 'A trial was newly excluded.');
assert(all(p.baseline_prediction == base.predicted_condition_id) && ...
    all(p.baseline_prediction == temporal.baseline_prediction) && ...
    all(p.full_fifths_prediction == temporal.extended_prediction), ...
    'Frozen baseline or full-fifths prediction changed.');

classes = (1:27)';
assert(isequal(unique(p.fold_id, 'sorted'), (1:5)') && ...
    isequal(unique(p.sampling_rate_hz, 'sorted'), [128; 256]) && ...
    isequal(unique(p.true_condition_id, 'sorted'), classes), ...
    'Folds, sampling rates, or 27 classes are incomplete.');
participants = unique(p.participant_id);
assert(numel(participants) == 88, 'The primary cohort should contain 88 participants.');
for participant = participants'
    assert(numel(unique(p.fold_id(p.participant_id == participant))) == 1, ...
        'Participant fold isolation failed.');
end
predColumns = {'baseline_prediction', 'full_fifths_prediction', ...
    'fixed_window_prediction', 'duration_only_prediction'};
for k = 1:numel(predColumns)
    x = p.(predColumns{k});
    assert(all(isfinite(x) & x == fix(x) & ismember(x, classes)), ...
        'A prediction column contains an invalid class.');
end

% Rebuild the number of 2-second, 1-second-step windows in every fifth.
fs = p.sampling_rate_hz;
edges = floor(trial.sample_count * (0:5) / 5);
lengths = diff(edges, 1, 2);
assert(all(lengths >= 3 * fs, 'all'), 'A fifth is shorter than its centered block.');
windowCounts = floor((lengths - 2 * fs) ./ fs) + 1;
assert(all(p.original_min_windows == min(windowCounts, [], 2)) && ...
    all(p.original_max_windows == max(windowCounts, [], 2)), ...
    'Original fifth window counts are incorrect.');
assert(all(p.fixed_windows_per_block == 2), 'Centered 3-second blocks must contain two windows.');

% Rebuild duration-only predictions from training-fold condition medians.
seconds = trial.sample_count ./ fs;
expected = zeros(height(p), 1);
for f = 1:5
    train = p.fold_id ~= f;
    med = zeros(27, 1);
    for c = classes'
        med(c) = median(seconds(train & p.true_condition_id == c));
    end
    for row = find(~train)'
        [~, c] = min(abs(med - seconds(row))); % ascending IDs resolve ties low-to-high.
        expected(row) = c;
    end
end
assert(all(p.duration_only_prediction == expected), 'Duration-only prediction is incorrect.');

% Recompute every scope/method row, including correct counts and all metrics.
scopes = ["all"; "fold_" + string((1:5)'); "rate_128"; "rate_256"];
methods = ["whole_trial"; "full_fifths"; "centered_3s"; "duration_only"];
masks = [true(height(p),1), p.fold_id == (1:5), p.sampling_rate_hz == [128 256]];
assert(height(m) == 32, 'Metrics must contain exactly 32 rows.');
for s = 1:numel(scopes)
    mask = masks(:,s);
    for q = 1:numel(methods)
        row = m.scope == scopes(s) & m.method == methods(q);
        assert(nnz(row) == 1, 'Metrics scope/method combination is missing or duplicated.');
        y = p.(predColumns{q});
        a = compute_classification_metrics(p.true_condition_id(mask), y(mask), classes);
        assert(all(a.support > 0), 'A metric scope lacks one of the 27 classes.');
        expectedMetrics = [nnz(mask), nnz(y(mask) == p.true_condition_id(mask)), ...
            a.macroF1, a.accuracy, a.balancedAccuracy];
        observed = [m.trial_count(row), m.correct_count(row), m.macro_f1(row), ...
            m.accuracy(row), m.balanced_accuracy(row)];
        assert(all(isfinite(observed)) && max(abs(observed - expectedMetrics)) < 1e-12, ...
            'Metrics disagree with predictions.');
    end
end

meta = jsondecode(fileread(metaFile));
run = jsondecode(fileread(runFile));
audit = jsondecode(fileread(fullfile(root, 'outputs', 'audit', 'audit_summary.json')));
assert(strcmpi(meta.upstream_commit, audit.upstream.commit), ...
    'Metadata upstream commit is inconsistent.');
assert(strcmpi(string(meta.plan_sha256), sha256_file(fullfile(root, 'fixed-window-control-plan.md'))) && ...
    strcmpi(string(meta.baseline_features_sha256), string(run.featureMatSha256)), ...
    'Metadata plan or baseline feature hash is inconsistent.');
hashFields = {'fold_manifest_sha256', 'temporal_predictions_sha256', ...
    'predictions_sha256', 'metrics_sha256'};
hashFiles = {foldFile, temporalFile, out, met};
for k = 1:4
    assert(strcmpi(string(meta.(hashFields{k})), sha256_file(string(hashFiles{k}))), ...
        'Metadata artifact hash is inconsistent.');
end
assert(double(meta.raw_files_verified) == 2335 && meta.block_seconds == 3 && ...
    meta.window_seconds == 2 && meta.overlap_fraction == 0.5 && meta.windows_per_block == 2, ...
    'Metadata window settings or checked-trial count are inconsistent.');
interval = fixed_window_gain_interval(p, classes);
assert(meta.bootstrap.seed == interval.seed && meta.bootstrap.repeats == interval.repeats && ...
    abs(meta.bootstrap.lower - interval.lower) < 1e-12 && ...
    abs(meta.bootstrap.upper - interval.upper) < 1e-12, ...
    'Saved participant-bootstrap interval differs from the paired predictions.');

verification = struct('passed', true, 'trialCount', height(p), ...
    'participantCount', numel(unique(p.participant_id)), 'foldCount', 5, ...
    'conditionCount', 27, 'metricRows', height(m));
fprintf('Verified %d fixed-window trials, 5 isolated folds, 32 metric rows and the paired interval.\n', height(p));
end
