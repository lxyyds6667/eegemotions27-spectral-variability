function output = compute_sampling_group_metrics( ...
    yTrue, yPredicted, participantIds, samplingRateHz, classIds)
%COMPUTE_SAMPLING_GROUP_METRICS Describe OOF performance by inferred rate.
%   These subgroup metrics diagnose heterogeneity. They are not separate
%   trained models and do not establish that sampling rate caused a change.

arguments
    yTrue (:,1) double
    yPredicted (:,1) double
    participantIds (:,1) double
    samplingRateHz (:,1) double
    classIds (:,1) double
end

numRows = numel(yTrue);
if numel(yPredicted) ~= numRows || numel(participantIds) ~= numRows || ...
        numel(samplingRateHz) ~= numRows
    error('EEG:SubgroupLengthMismatch', ...
        'Labels, predictions, participants, and sampling rates must align.');
end
if any(~isfinite(samplingRateHz))
    error('EEG:UnknownSamplingGroup', ...
        'Every trial must have a finite inferred sampling rate.');
end

participants = unique(participantIds, 'sorted');
for participantIndex = 1:numel(participants)
    participantRates = unique(samplingRateHz( ...
        participantIds == participants(participantIndex)));
    if numel(participantRates) ~= 1
        error('EEG:ParticipantSamplingConflict', ...
            'Participant %g maps to more than one sampling-rate group.', ...
            participants(participantIndex));
    end
end

groupRate = unique(samplingRateHz, 'sorted');
numGroups = numel(groupRate);
participantCount = zeros(numGroups, 1);
trialCount = zeros(numGroups, 1);
macroF1 = zeros(numGroups, 1);
balancedAccuracy = zeros(numGroups, 1);
accuracy = zeros(numGroups, 1);

for groupIndex = 1:numGroups
    rows = samplingRateHz == groupRate(groupIndex);
    metrics = compute_classification_metrics( ...
        yTrue(rows), yPredicted(rows), classIds);
    participantCount(groupIndex) = numel(unique(participantIds(rows)));
    trialCount(groupIndex) = sum(rows);
    macroF1(groupIndex) = metrics.macroF1;
    balancedAccuracy(groupIndex) = metrics.balancedAccuracy;
    accuracy(groupIndex) = metrics.accuracy;
end

output = table(groupRate, participantCount, trialCount, macroF1, ...
    balancedAccuracy, accuracy, ...
    'VariableNames', {'sampling_rate_hz', 'participant_count', ...
    'trial_count', 'macro_f1', 'balanced_accuracy', 'accuracy'});
end
