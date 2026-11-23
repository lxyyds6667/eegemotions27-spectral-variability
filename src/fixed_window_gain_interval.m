function stats = fixed_window_gain_interval(p, classes)
%FIXED_WINDOW_GAIN_INTERVAL Bootstrap pooled macro-F1 gain from held-out predictions.
% Each repeated participant contributes all their trials to both methods.
stats.seed = 2704;
stats.repeats = 2000;
stream = RandStream('mt19937ar', 'Seed', stats.seed);
[participants, ~, group] = unique(p.participant_id);
n = numel(participants);
delta = zeros(stats.repeats, 1);
for k = 1:stats.repeats
    weights = accumarray(randi(stream, n, n, 1), 1, [n 1]);
    rows = repelem((1:height(p))', weights(group));
    baseline = compute_classification_metrics(p.true_condition_id(rows), p.baseline_prediction(rows), classes);
    fixed = compute_classification_metrics(p.true_condition_id(rows), p.fixed_window_prediction(rows), classes);
    delta(k) = fixed.macroF1 - baseline.macroF1;
end
bounds = prctile(delta, [2.5 97.5]);
stats.lower = bounds(1);
stats.upper = bounds(2);
end
