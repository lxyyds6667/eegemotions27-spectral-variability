function baseline = run_uniform_random_baseline(labels, classIds, numRepeats, seed)
%RUN_UNIFORM_RANDOM_BASELINE Repeated uniform predictions over fixed classes.

arguments
    labels (:,1) double
    classIds (:,1) double
    numRepeats (1,1) double {mustBeInteger, mustBePositive}
    seed (1,1) double {mustBeInteger, mustBeNonnegative}
end

previousState = rng;
restoreRng = onCleanup(@() rng(previousState));
rng(seed, 'twister');

macroF1 = zeros(numRepeats, 1);
balancedAccuracy = zeros(numRepeats, 1);
accuracy = zeros(numRepeats, 1);
repeatId = (1:numRepeats)';

for repeatIndex = 1:numRepeats
    prediction = classIds(randi(numel(classIds), numel(labels), 1));
    metrics = compute_classification_metrics(labels, prediction, classIds);
    macroF1(repeatIndex) = metrics.macroF1;
    balancedAccuracy(repeatIndex) = metrics.balancedAccuracy;
    accuracy(repeatIndex) = metrics.accuracy;
end

baseline = struct();
baseline.repeats = table(repeatId, macroF1, balancedAccuracy, accuracy, ...
    'VariableNames', {'repeat_id', 'macro_f1', 'balanced_accuracy', 'accuracy'});
baseline.meanMacroF1 = mean(macroF1);
baseline.meanBalancedAccuracy = mean(balancedAccuracy);
baseline.meanAccuracy = mean(accuracy);
baseline.macroF195PercentInterval = prctile(macroF1, [2.5, 97.5]);
baseline.accuracy95PercentInterval = prctile(accuracy, [2.5, 97.5]);
end
