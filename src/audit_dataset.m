function [fileAudit, trialManifest, summary, participantSampling, conditionTiming] = audit_dataset(cfg)
%AUDIT_DATASET Inspect every public TXT before feature extraction is allowed.

arguments
    cfg (1,1) struct
end

rawFolder = string(cfg.paths.rawData);
if ~isfolder(rawFolder)
    error('EEG:MissingDataDirectory', ...
        'Raw EEG directory is missing: %s', rawFolder);
end

files = dir(fullfile(rawFolder, '**', '*.txt'));
files = files(~[files.isdir]);
if isempty(files)
    error('EEG:NoRawFiles', 'No TXT files were found below %s.', rawFolder);
end
[~, order] = sort(string({files.name}));
files = files(order);

numFiles = numel(files);
relativePath = strings(numFiles, 1);
fileName = strings(numFiles, 1);
fileBytes = zeros(numFiles, 1);
sha256 = strings(numFiles, 1);
parseOk = false(numFiles, 1);
participantId = nan(numFiles, 1);
emotionId = nan(numFiles, 1);
readOk = false(numFiles, 1);
numRows = nan(numFiles, 1);
numColumns = nan(numFiles, 1);
orientation = repmat("unknown", numFiles, 1);
durationSeconds = nan(numFiles, 1);
nonfiniteCount = nan(numFiles, 1);
zeroChannelCount = nan(numFiles, 1);
constantChannelCount = nan(numFiles, 1);
maximumAbsoluteValue = nan(numFiles, 1);
analysisReady = false(numFiles, 1);
exclusionReason = strings(numFiles, 1);

minimumSamples = round(cfg.welch.windowSeconds * cfg.data.samplingRateHz);
datasetRootPrefix = string(cfg.paths.datasetRoot) + filesep;
auditTimer = tic;

for fileIndex = 1:numFiles
    fullPath = string(fullfile(files(fileIndex).folder, files(fileIndex).name));
    relativePath(fileIndex) = erase(fullPath, datasetRootPrefix);
    fileName(fileIndex) = string(files(fileIndex).name);
    fileBytes(fileIndex) = files(fileIndex).bytes;

    try
        metadata = parse_trial_filename(fileName(fileIndex));
        participantId(fileIndex) = metadata.participantId;
        emotionId(fileIndex) = metadata.emotionId;
        parseOk(fileIndex) = true;
    catch exception
        exclusionReason(fileIndex) = append_reason( ...
            exclusionReason(fileIndex), "filename: " + string(exception.message));
    end

    try
        sha256(fileIndex) = sha256_file(fullPath);
    catch exception
        exclusionReason(fileIndex) = append_reason( ...
            exclusionReason(fileIndex), "hash: " + string(exception.message));
    end

    try
        matrix = readmatrix(fullPath, 'FileType', 'text', ...
            'Delimiter', cfg.data.textDelimiter);
        if isempty(matrix) || ~isnumeric(matrix) || ~ismatrix(matrix)
            error('EEG:InvalidMatrix', 'not a nonempty numeric matrix');
        end
        readOk(fileIndex) = true;
        numRows(fileIndex) = size(matrix, 1);
        numColumns(fileIndex) = size(matrix, 2);
        nonfiniteCount(fileIndex) = sum(~isfinite(matrix), 'all');
        maximumAbsoluteValue(fileIndex) = max(abs(matrix), [], 'all', 'omitnan');

        if size(matrix, 2) == cfg.data.expectedChannelCount
            orientation(fileIndex) = "time_by_channel";
            durationSeconds(fileIndex) = size(matrix, 1) / cfg.data.samplingRateHz;
            finiteMatrix = matrix;
            finiteMatrix(~isfinite(finiteMatrix)) = NaN;
            channelMinimum = min(finiteMatrix, [], 1, 'omitnan');
            channelMaximum = max(finiteMatrix, [], 1, 'omitnan');
            constantChannels = channelMinimum == channelMaximum;
            constantChannelCount(fileIndex) = sum(constantChannels);
            zeroChannelCount(fileIndex) = sum(constantChannels & channelMinimum == 0);
        elseif size(matrix, 1) == cfg.data.expectedChannelCount
            orientation(fileIndex) = "channel_by_time";
            durationSeconds(fileIndex) = size(matrix, 2) / cfg.data.samplingRateHz;
            exclusionReason(fileIndex) = append_reason( ...
                exclusionReason(fileIndex), "matrix is channel-by-time; no silent transpose");
        else
            orientation(fileIndex) = "unexpected_shape";
            exclusionReason(fileIndex) = append_reason( ...
                exclusionReason(fileIndex), sprintf( ...
                'expected 14 columns, found %d-by-%d', size(matrix, 1), size(matrix, 2)));
        end

        if nonfiniteCount(fileIndex) > 0
            exclusionReason(fileIndex) = append_reason( ...
                exclusionReason(fileIndex), sprintf( ...
                '%d non-finite values', nonfiniteCount(fileIndex)));
        end
        if orientation(fileIndex) == "time_by_channel" && size(matrix, 1) < minimumSamples
            exclusionReason(fileIndex) = append_reason( ...
                exclusionReason(fileIndex), sprintf( ...
                'only %d samples; Welch requires at least %d', size(matrix, 1), minimumSamples));
        end
        if orientation(fileIndex) == "time_by_channel" && constantChannelCount(fileIndex) > 0
            exclusionReason(fileIndex) = append_reason( ...
                exclusionReason(fileIndex), sprintf( ...
                '%d exactly constant channels', constantChannelCount(fileIndex)));
        end
    catch exception
        exclusionReason(fileIndex) = append_reason( ...
            exclusionReason(fileIndex), "read: " + string(exception.message));
    end

    analysisReady(fileIndex) = parseOk(fileIndex) && readOk(fileIndex) && ...
        orientation(fileIndex) == "time_by_channel" && ...
        nonfiniteCount(fileIndex) == 0 && ...
        numRows(fileIndex) >= minimumSamples && ...
        constantChannelCount(fileIndex) == 0;

    if mod(fileIndex, 100) == 0 || fileIndex == numFiles
        fprintf('Audited %d/%d files (%.1f s).\n', ...
            fileIndex, numFiles, toc(auditTimer));
    end
end

fileAudit = table(relativePath, fileName, fileBytes, sha256, parseOk, ...
    participantId, emotionId, readOk, numRows, numColumns, orientation, ...
    durationSeconds, nonfiniteCount, zeroChannelCount, constantChannelCount, ...
    maximumAbsoluteValue, analysisReady, exclusionReason, ...
    'VariableNames', {'source_relative_path', 'file_name', 'file_bytes', ...
    'sha256', 'parse_ok', 'participant_id', 'emotion_id', 'read_ok', ...
    'num_rows', 'num_columns', 'orientation', 'duration_seconds', ...
    'nonfinite_count', 'zero_channel_count', 'constant_channel_count', ...
    'maximum_absolute_value', 'analysis_ready', 'exclusion_reason'});

validKeys = parseOk;
trialKey = strings(numFiles, 1);
trialKey(validKeys) = "P" + compose('%03d', participantId(validKeys)) + ...
    "_E" + compose('%02d', emotionId(validKeys));
duplicateTrialKey = mark_duplicates(trialKey, validKeys);
duplicateHash = mark_duplicates(sha256, strlength(sha256) > 0);
fileAudit.duplicate_trial_key = duplicateTrialKey;
fileAudit.duplicate_sha256 = duplicateHash;

fileAudit.analysis_ready = fileAudit.analysis_ready & ...
    ~duplicateTrialKey & ~duplicateHash;
for fileIndex = find(duplicateTrialKey)'
    fileAudit.exclusion_reason(fileIndex) = append_reason( ...
        fileAudit.exclusion_reason(fileIndex), "duplicate participant-condition key");
end
for fileIndex = find(duplicateHash)'
    fileAudit.exclusion_reason(fileIndex) = append_reason( ...
        fileAudit.exclusion_reason(fileIndex), "duplicate file SHA-256");
end

[fileAudit, participantSampling, conditionTiming] = ...
    infer_sampling_rates_from_lengths(fileAudit, cfg);

trialManifest = make_trial_manifest(fileAudit, cfg, fileAudit.analysis_ready);

summary = struct();
summary.rawFolder = char(erase(rawFolder, string(cfg.paths.projectRoot) + filesep));
summary.fileCount = numFiles;
summary.parseableFileCount = sum(fileAudit.parse_ok);
summary.structuralReadyFileCount = sum(fileAudit.structural_ready);
summary.analysisReadyFileCount = sum(fileAudit.analysis_ready);
summary.excludedFileCount = sum(~fileAudit.analysis_ready);
summary.uniqueParticipantCount = numel(unique(fileAudit.participant_id(fileAudit.parse_ok)));
summary.uniqueEmotionCount = numel(unique(fileAudit.emotion_id(fileAudit.parse_ok)));
summary.expectedParticipantCount = cfg.data.expectedParticipantCount;
summary.expectedEmotionCount = numel(cfg.data.expectedEmotionIds);
summary.participantCountMatchesDocumentation = ...
    summary.uniqueParticipantCount == summary.expectedParticipantCount;
summary.participantIdsMatchMetadata = false;
summary.participantIdsMissingFromRaw = [];
summary.participantIdsAbsentFromMetadata = [];
if isfile(cfg.paths.participantInfo)
    participantInfo = readtable(cfg.paths.participantInfo);
    metadataParticipantIds = participantInfo.Participant_ID;
    rawParticipantIds = unique(fileAudit.participant_id(fileAudit.parse_ok));
    summary.participantIdsMissingFromRaw = ...
        setdiff(metadataParticipantIds, rawParticipantIds)';
    summary.participantIdsAbsentFromMetadata = ...
        setdiff(rawParticipantIds, metadataParticipantIds)';
    summary.participantIdsMatchMetadata = ...
        isempty(summary.participantIdsMissingFromRaw) && ...
        isempty(summary.participantIdsAbsentFromMetadata);
end
summary.emotionIdsMatchDocumentation = isequal( ...
    unique(fileAudit.emotion_id(fileAudit.parse_ok)), cfg.data.expectedEmotionIds(:));
summary.duplicateTrialFileCount = sum(fileAudit.duplicate_trial_key);
summary.duplicateHashFileCount = sum(fileAudit.duplicate_sha256);
summary.durationSecondsAtDocumented256 = finite_summary(fileAudit.duration_seconds);
summary.correctedDurationSeconds = finite_summary(fileAudit.corrected_duration_seconds);
summary.fileBytes = finite_summary(fileAudit.file_bytes);
summary.inferred128ParticipantCount = sum( ...
    participantSampling.inferred_sampling_rate_hz == 128);
summary.consistent256ParticipantCount = sum( ...
    participantSampling.inferred_sampling_rate_hz == 256);
summary.ambiguousSamplingParticipantCount = sum( ...
    participantSampling.ambiguous_sampling_group);
summary.durationOutlierFileCount = sum(fileAudit.duration_outlier);
summary.unexplainedExcludedFileCount = sum( ...
    ~fileAudit.analysis_ready & strlength(fileAudit.exclusion_reason) == 0);
summary.canProceedToFeatureExtraction = ...
    summary.analysisReadyFileCount > 0 && ...
    summary.parseableFileCount == summary.fileCount && ...
    summary.duplicateTrialFileCount == 0 && ...
    summary.duplicateHashFileCount == 0 && ...
    summary.participantIdsMatchMetadata && ...
    summary.emotionIdsMatchDocumentation && ...
    summary.ambiguousSamplingParticipantCount == 0 && ...
    summary.unexplainedExcludedFileCount == 0;
summary.signalUnits = cfg.data.units;
summary.preprocessingStatus = 'public files described as raw; filtering/reference/ICA status unknown';
end

function combined = append_reason(existing, addition)
if strlength(existing) == 0
    combined = string(addition);
else
    combined = existing + "; " + string(addition);
end
end

function duplicate = mark_duplicates(values, eligible)
duplicate = false(size(values));
eligibleValues = values(eligible);
if isempty(eligibleValues)
    return;
end
[~, ~, group] = unique(eligibleValues);
counts = accumarray(group, 1);
duplicate(eligible) = counts(group) > 1;
end

function output = finite_summary(values)
values = values(isfinite(values));
if isempty(values)
    output = struct('minimum', NaN, 'median', NaN, 'maximum', NaN);
else
    output = struct('minimum', min(values), 'median', median(values), ...
        'maximum', max(values));
end
end

