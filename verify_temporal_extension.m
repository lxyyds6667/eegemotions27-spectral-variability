function verify_temporal_extension()
% Independently reconstruct the paired scores and decision from saved trials.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'src'),fullfile(root,'config'));
cfg = default_config();
primary = fullfile(cfg.paths.outputs,'modeling');
out = fullfile(cfg.paths.outputs,'temporal_extension');
p = readtable(fullfile(out,'oof_predictions.csv'),'TextType','string');
ref = readtable(fullfile(primary,'oof_predictions.csv'),'TextType','string');
fold = readtable(fullfile(primary,'fold_manifest.csv'),'TextType','string');
m = readtable(fullfile(out,'paired_metrics.csv'),'TextType','string');
perm = readtable(fullfile(out,'permutations.csv'));
d = readtable(fullfile(out,'decision.csv'),'TextType','string');
assert(isequal(p.trial_id,ref.trial_id,fold.trial_id) && ...
    isequal(p.participant_id,ref.participant_id,fold.participant_id) && ...
    isequal(p.fold_id,ref.fold_id,fold.fold_id) && ...
    isequal(p.true_condition_id,ref.true_condition_id,fold.condition_id) && ...
    isequal(p.sampling_rate_hz,fold.sampling_rate_hz) && ...
    isequal(p.baseline_prediction,ref.predicted_condition_id),'Frozen trial alignment failed.');
assert(height(p)==2335 && numel(unique(p.trial_id))==height(p));
assert(isequal(m.scope,["all";"fold_"+string((1:5)');"rate_128";"rate_256"]));
masks = [true(height(p),1),p.fold_id==(1:5),p.sampling_rate_hz==[128 256]];
for k=1:width(masks)
    rows=masks(:,k);
    a=compute_classification_metrics(p.true_condition_id(rows),p.baseline_prediction(rows),cfg.data.expectedEmotionIds);
    b=compute_classification_metrics(p.true_condition_id(rows),p.extended_prediction(rows),cfg.data.expectedEmotionIds);
    expected=[nnz(rows),a.macroF1,b.macroF1,b.macroF1-a.macroF1,a.accuracy,b.accuracy,a.balancedAccuracy,b.balancedAccuracy];
    assert(all(abs(m{k,2:end}-expected)<1e-12) && all(b.support>0),'Paired metrics differ from saved predictions.');
end
assert(isequal(perm.seed,cfg.permutation.seed+(0:cfg.permutation.numRepeats-1)') && ...
    all(isfinite(perm{:,2:end}),'all'),'Incomplete permutation distribution.');
expectedDecision=[m.delta_f1(1)>0;nnz(m.delta_f1(2:6)>0)>=4; ...
    all(m.delta_f1(7:8)>=0);m.extended_f1(1)>max(perm.macro_f1)];
assert(isequal(logical(d.passed),expectedDecision),'Decision disagrees with paired results.');
fprintf('Verified %d paired trials, %d score rows, %d permutation seeds and all four criteria.\n', ...
    height(p),height(m),height(perm));
end
