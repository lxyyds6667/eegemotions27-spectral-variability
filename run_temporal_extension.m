function comparison = run_temporal_extension()
% Run the five-segment experiment against the saved phase-one predictions.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'),fullfile(root,'config'));
cfg = default_config();
primary = fullfile(cfg.paths.outputs,'modeling');
baseline = readtable(fullfile(primary,'oof_predictions.csv'),'TextType','string');
folds = readtable(fullfile(primary,'fold_manifest.csv'),'TextType','string');
featureFile = fullfile(cfg.paths.interim,'welch_features.mat');
manifest = jsondecode(fileread(fullfile(primary,'run_manifest.json')));
assert(strcmp(sha256_file(featureFile),manifest.featureMatSha256),'Baseline feature cache changed.');
cache = load(featureFile,'featureTable','featureNames');
t = cache.featureTable;
assert(isequal(t.trial_id, baseline.trial_id, folds.trial_id) && ...
    isequal(t.participant_id, baseline.participant_id, folds.participant_id) && ...
    isequal(t.condition_id,baseline.true_condition_id,folds.condition_id) && ...
    isequal(t.sampling_rate_hz,folds.sampling_rate_hz) && isequal(baseline.fold_id,folds.fold_id), ...
    'Primary trials or folds do not align.');
base = t{:, cellstr(cache.featureNames)};
temporal = zeros(size(base));
for k = 1:height(t)
    trialCfg = cfg;
    trialCfg.data.samplingRateHz = t.sampling_rate_hz(k);
    eeg = load_eeg_trial(fullfile(cfg.paths.datasetRoot,t.source_relative_path(k)),cfg.data.expectedChannelCount);
    assert(size(eeg,1)==t.sample_count(k),'Trial length changed.');
    temporal(k,:) = extract_temporal_variability(eeg,trialCfg);
    if mod(k,500)==0
        fprintf('Extracted five-segment features for %d/%d trials.\n',k,height(t));
    end
end
X = [base temporal];
y = t.condition_id;
id = t.participant_id;
fold = folds.fold_id;
classes = cfg.data.expectedEmotionIds;
model = evaluate_grouped_cv(X,y,id,fold,cfg);
pred = model.outOfFoldPrediction;
out = fullfile(cfg.paths.outputs,'temporal_extension');
if ~isfolder(out), mkdir(out); end
predictions = table(t.trial_id,id,fold,t.sampling_rate_hz,y,baseline.predicted_condition_id,pred, ...
    'VariableNames',{'trial_id','participant_id','fold_id','sampling_rate_hz','true_condition_id','baseline_prediction','extended_prediction'});
writetable(predictions,fullfile(out,'oof_predictions.csv'));
comparison = table();
for scope = ["all","fold_1","fold_2","fold_3","fold_4","fold_5","rate_128","rate_256"]
    mask = true(size(y));
    if startsWith(scope,"fold_")
        mask = fold == str2double(extractAfter(scope,"_"));
    elseif startsWith(scope,"rate_")
        mask = t.sampling_rate_hz == str2double(extractAfter(scope,"_"));
    end
    a = compute_classification_metrics(y(mask),baseline.predicted_condition_id(mask),classes);
    b = compute_classification_metrics(y(mask),pred(mask),classes);
    assert(all(a.support>0),'A comparison subset lacks one of the 27 conditions.');
    row = table(scope,nnz(mask),a.macroF1,b.macroF1,b.macroF1-a.macroF1,a.accuracy,b.accuracy, ...
        a.balancedAccuracy,b.balancedAccuracy,'VariableNames',{'scope','trial_count','baseline_f1', ...
        'extended_f1','delta_f1','baseline_accuracy','extended_accuracy','baseline_balanced_accuracy','extended_balanced_accuracy'});
    comparison = [comparison;row]; %#ok<AGROW>
end
writetable(comparison,fullfile(out,'paired_metrics.csv'));
disp(comparison);
null = run_structured_permutation_baseline(X,y,id,fold,cfg,model.metrics);
writetable(null.repeats,fullfile(out,'permutations.csv'));
checks = [comparison.delta_f1(1)>0; nnz(comparison.delta_f1(2:6)>0)>=4; ...
    all(comparison.delta_f1(7:8)>=0); model.metrics.macroF1>max(null.repeats.macro_f1)];
decision = table(["pooled_gain";"four_positive_folds";"both_groups_nondecreasing"; ...
    "above_all_permutations"],checks,'VariableNames',{'criterion','passed'});
writetable(decision,fullfile(out,'decision.csv'));
plot_temporal_comparison();
disp(decision);
fprintf('Observed macro-F1 %.6f, permutation mean %.6f, max %.6f, empirical p %.6f.\n', ...
    model.metrics.macroF1,null.macroF1Mean,max(null.repeats.macro_f1),null.macroF1EmpiricalP);
end
