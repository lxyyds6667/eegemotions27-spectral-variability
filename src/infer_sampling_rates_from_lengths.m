function [fileAudit, participantSampling, conditionTiming] = ...
    infer_sampling_rates_from_lengths(fileAudit, cfg)
%INFER_SAMPLING_RATES_FROM_LENGTHS Resolve the released 128/256 Hz clusters.
%   The fixed videos create condition-specific expected durations. Across
%   conditions, participant median row counts form clusters near 0.5 and
%   1.0 of the condition median. The threshold is frozen in configuration.

arguments
    fileAudit table
    cfg (1,1) struct
end

required = {'participant_id', 'emotion_id', 'num_rows', 'analysis_ready', ...
    'exclusion_reason'};
if ~all(ismember(required, fileAudit.Properties.VariableNames))
    error('EEG:AuditColumns', 'File audit lacks columns required for sampling inference.');
end

structuralReady = fileAudit.analysis_ready;
fileAudit.structural_ready = structuralReady;

validRows = structuralReady & isfinite(fileAudit.participant_id) & ...
    isfinite(fileAudit.emotion_id) & isfinite(fileAudit.num_rows);
if ~any(validRows)
    error('EEG:NoStructuralTrials', 'No structurally valid trials are available.');
end

[conditionGroup, conditionId] = findgroups(fileAudit.emotion_id(validRows));
conditionMedianRows = splitapply(@median, fileAudit.num_rows(validRows), conditionGroup);
[conditionKnown, conditionLocation] = ismember(fileAudit.emotion_id, conditionId);

rawLengthRatio = nan(height(fileAudit), 1);
rawLengthRatio(conditionKnown) = fileAudit.num_rows(conditionKnown) ./ ...
    conditionMedianRows(conditionLocation(conditionKnown));
fileAudit.raw_length_ratio_to_condition_median = rawLengthRatio;

[participantGroup, participantId] = findgroups(fileAudit.participant_id(validRows));
participantMedianRatio = splitapply(@median, rawLengthRatio(validRows), participantGroup);
inferredRate = repmat(cfg.data.samplingRateHz, numel(participantId), 1);
inferredRate(participantMedianRatio < cfg.audit.halfRateThreshold) = ...
    cfg.data.samplingRateHz / 2;

if any(~ismember(inferredRate, [128, 256]))
    error('EEG:UnexpectedInferredRate', ...
        'Sampling-rate inference produced a rate outside 128/256 Hz.');
end

ambiguousParticipant = participantMedianRatio >= 0.60 & participantMedianRatio <= 0.90;
samplingGroup = strings(numel(participantId), 1);
samplingGroup(inferredRate == 128) = "inferred_128";
samplingGroup(inferredRate == 256) = "consistent_256";
samplingBasis = strings(numel(participantId), 1);
samplingBasis(inferredRate == 128) = ...
    "inferred from half-length cluster; spectral bandwidth validation required";
samplingBasis(inferredRate == 256) = ...
    "consistent with documented 256 Hz and full-length cluster";

participantSampling = table(participantId, participantMedianRatio, inferredRate, ...
    samplingGroup, ambiguousParticipant, samplingBasis, ...
    'VariableNames', {'participant_id', 'median_raw_length_ratio', ...
    'inferred_sampling_rate_hz', 'sampling_group', ...
    'ambiguous_sampling_group', 'sampling_rate_basis'});

[participantKnown, participantLocation] = ismember( ...
    fileAudit.participant_id, participantId);
fileRate = nan(height(fileAudit), 1);
fileRate(participantKnown) = inferredRate(participantLocation(participantKnown));
fileAudit.inferred_sampling_rate_hz = fileRate;
fileAudit.sampling_rate_basis = repmat("unknown", height(fileAudit), 1);
fileAudit.sampling_rate_basis(participantKnown) = ...
    samplingBasis(participantLocation(participantKnown));

correctedDuration = fileAudit.num_rows ./ fileRate;
fileAudit.corrected_duration_seconds = correctedDuration;

[correctedConditionGroup, correctedConditionId] = findgroups( ...
    fileAudit.emotion_id(validRows));
conditionMedianDuration = splitapply( ...
    @median, correctedDuration(validRows), correctedConditionGroup);
[correctedConditionKnown, correctedConditionLocation] = ismember( ...
    fileAudit.emotion_id, correctedConditionId);
conditionDurationRatio = nan(height(fileAudit), 1);
conditionDurationRatio(correctedConditionKnown) = ...
    correctedDuration(correctedConditionKnown) ./ ...
    conditionMedianDuration(correctedConditionLocation(correctedConditionKnown));
fileAudit.condition_duration_ratio = conditionDurationRatio;

durationOutlier = structuralReady & ...
    abs(conditionDurationRatio - 1) > cfg.audit.durationToleranceFraction;
fileAudit.duration_outlier = durationOutlier;
fileAudit.analysis_ready = structuralReady & ~durationOutlier;
for row = find(durationOutlier)'
    fileAudit.exclusion_reason(row) = append_sampling_reason( ...
        fileAudit.exclusion_reason(row), sprintf( ...
        'corrected duration ratio %.4f exceeds %.1f%% tolerance', ...
        conditionDurationRatio(row), 100 * cfg.audit.durationToleranceFraction));
end

conditionTrialCount = splitapply(@numel, correctedDuration(validRows), correctedConditionGroup);
conditionMinimumDuration = splitapply(@min, correctedDuration(validRows), correctedConditionGroup);
conditionMaximumDuration = splitapply(@max, correctedDuration(validRows), correctedConditionGroup);
conditionTiming = table(correctedConditionId, conditionTrialCount, ...
    conditionMinimumDuration, conditionMedianDuration, conditionMaximumDuration, ...
    'VariableNames', {'condition_id', 'structural_trial_count', ...
    'minimum_duration_seconds', 'median_duration_seconds', ...
    'maximum_duration_seconds'});
end

function combined = append_sampling_reason(existing, addition)
if strlength(existing) == 0
    combined = string(addition);
else
    combined = existing + "; " + string(addition);
end
end

