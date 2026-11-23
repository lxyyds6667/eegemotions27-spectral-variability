function trialManifest = make_trial_manifest(fileAudit, cfg, includeRows)
%MAKE_TRIAL_MANIFEST Build a whole-trial manifest from audited files.
%   INCLUDEROWS makes the exclusion policy explicit. The primary analysis
%   passes analysis_ready; structural-only sensitivity passes structural_ready.

arguments
    fileAudit table
    cfg (1,1) struct
    includeRows (:,1) logical
end

if numel(includeRows) ~= height(fileAudit)
    error('EEG:ManifestSelectionLength', ...
        'Manifest selection must have one logical value per audit row.');
end

required = {'participant_id', 'emotion_id', 'source_relative_path', ...
    'file_bytes', 'sha256', 'num_rows', 'inferred_sampling_rate_hz', ...
    'sampling_rate_basis'};
if ~all(ismember(required, fileAudit.Properties.VariableNames))
    error('EEG:AuditColumns', ...
        'File audit lacks columns required to build a trial manifest.');
end
if ~any(includeRows)
    error('EEG:EmptyManifest', 'No rows were selected for the trial manifest.');
end

participantId = fileAudit.participant_id(includeRows);
conditionId = fileAudit.emotion_id(includeRows);
if any(~isfinite(participantId)) || any(~isfinite(conditionId))
    error('EEG:ManifestIdentifier', ...
        'Selected audit rows must have finite participant and condition IDs.');
end

trialId = "P" + compose('%03d', participantId) + ...
    "_E" + compose('%02d', conditionId);
if numel(unique(trialId)) ~= numel(trialId)
    error('EEG:DuplicateTrialId', ...
        'Selected audit rows contain duplicate participant-condition IDs.');
end

numTrials = sum(includeRows);
trialIndex = ones(numTrials, 1);
startSample = ones(numTrials, 1);
endSample = fileAudit.num_rows(includeRows);
samplingRateHz = fileAudit.inferred_sampling_rate_hz(includeRows);
samplingRateBasis = fileAudit.sampling_rate_basis(includeRows);
channelCount = repmat(cfg.data.expectedChannelCount, numTrials, 1);
channelOrder = repmat(strjoin(string(cfg.data.channelNames), ','), numTrials, 1);
exclusionStatus = repmat("included", numTrials, 1);
exclusionReason = repmat("", numTrials, 1);

trialManifest = table(trialId, participantId, conditionId, trialIndex, ...
    fileAudit.source_relative_path(includeRows), fileAudit.file_bytes(includeRows), ...
    fileAudit.sha256(includeRows), startSample, endSample, samplingRateHz, ...
    samplingRateBasis, channelCount, channelOrder, fileAudit.num_rows(includeRows), ...
    exclusionStatus, exclusionReason, ...
    'VariableNames', {'trial_id', 'participant_id', 'condition_id', ...
    'trial_index', 'source_relative_path', 'file_bytes', 'sha256', ...
    'start_sample', 'end_sample', 'sampling_rate_hz', 'sampling_rate_basis', ...
    'channel_count', 'channel_order', 'sample_count', ...
    'exclusion_status', 'exclusion_reason'});
trialManifest = sortrows(trialManifest, {'participant_id', 'condition_id'});
end
