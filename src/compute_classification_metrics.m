function metrics = compute_classification_metrics(yTrue, yPredicted, classIds)
%COMPUTE_CLASSIFICATION_METRICS Fixed-class multiclass performance metrics.
%   Macro metrics include classes represented in YTRUE. A supported class
%   with no predicted observations receives precision and F1 equal to zero.

arguments
    yTrue (:,1)
    yPredicted (:,1)
    classIds (:,1)
end

if numel(yTrue) ~= numel(yPredicted)
    error('EEG:MetricLengthMismatch', 'True and predicted labels must have equal length.');
end
if isempty(yTrue)
    error('EEG:EmptyLabels', 'Cannot compute metrics for an empty label vector.');
end

[trueKnown, trueIndex] = ismember(yTrue, classIds);
[predictedKnown, predictedIndex] = ismember(yPredicted, classIds);
if ~all(trueKnown) || ~all(predictedKnown)
    error('EEG:UnknownClass', 'All labels must occur in the supplied classIds vector.');
end

numClasses = numel(classIds);
confusion = accumarray([trueIndex, predictedIndex], 1, [numClasses, numClasses]);
truePositive = diag(confusion);
support = sum(confusion, 2);
predictedCount = sum(confusion, 1)';

recall = zeros(numClasses, 1);
precision = zeros(numClasses, 1);
supported = support > 0;
predicted = predictedCount > 0;
recall(supported) = truePositive(supported) ./ support(supported);
precision(predicted) = truePositive(predicted) ./ predictedCount(predicted);

f1 = zeros(numClasses, 1);
nonzeroDenominator = precision + recall > 0;
f1(nonzeroDenominator) = 2 * precision(nonzeroDenominator) .* recall(nonzeroDenominator) ./ ...
    (precision(nonzeroDenominator) + recall(nonzeroDenominator));

metrics = struct();
metrics.accuracy = sum(truePositive) / numel(yTrue);
metrics.balancedAccuracy = mean(recall(supported));
metrics.macroF1 = mean(f1(supported));
metrics.classIds = classIds;
metrics.confusionMatrix = confusion;
metrics.support = support;
metrics.precision = precision;
metrics.recall = recall;
metrics.f1 = f1;
end

