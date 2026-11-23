function [featureTable, featureNames, representative] = build_feature_table(cfg, trialManifest)
%BUILD_FEATURE_TABLE Extract exactly one 70-element vector per whole trial.

arguments
    cfg (1,1) struct
    trialManifest table
end

requiredVariables = {'trial_id', 'participant_id', 'condition_id', ...
    'source_relative_path', 'sample_count', 'sampling_rate_hz'};
if ~all(ismember(requiredVariables, trialManifest.Properties.VariableNames))
    error('EEG:ManifestColumns', ...
        'Trial manifest is missing one or more required variables.');
end
if isempty(trialManifest)
    error('EEG:EmptyManifest', 'No analysis-ready trials are present.');
end
if numel(unique(trialManifest.trial_id)) ~= height(trialManifest)
    error('EEG:DuplicateTrialId', 'Trial IDs must be unique before feature extraction.');
end

numTrials = height(trialManifest);
numFeatures = cfg.data.expectedChannelCount * numel(cfg.bands.names);
featureValues = nan(numTrials, numFeatures);
featureNames = strings(1, numFeatures);
representative = struct();
featureTimer = tic;

for trialIndex = 1:numTrials
    filePath = fullfile(cfg.paths.datasetRoot, ...
        trialManifest.source_relative_path(trialIndex));
    eeg = load_eeg_trial(string(filePath), cfg.data.expectedChannelCount);
    if size(eeg, 1) ~= trialManifest.sample_count(trialIndex)
        error('EEG:ManifestSampleMismatch', ...
            'Manifest and source sample counts disagree for %s.', ...
            trialManifest.trial_id(trialIndex));
    end

    trialConfig = cfg;
    trialConfig.data.samplingRateHz = trialManifest.sampling_rate_hz(trialIndex);
    [features, currentNames, diagnostics] = extract_welch_features(eeg, trialConfig);
    featureValues(trialIndex, :) = features;
    if trialIndex == 1
        featureNames = currentNames;
        representative.trialId = trialManifest.trial_id(trialIndex);
        representative.sourceRelativePath = ...
            trialManifest.source_relative_path(trialIndex);
        representative.frequencyHz = diagnostics.frequencyHz;
        representative.psd = diagnostics.psd;
    elseif ~isequal(currentNames, featureNames)
        error('EEG:FeatureNameDrift', ...
            'Feature order changed while processing %s.', trialManifest.trial_id(trialIndex));
    end

    if mod(trialIndex, 100) == 0 || trialIndex == numTrials
        fprintf('Extracted features for %d/%d trials (%.1f s).\n', ...
            trialIndex, numTrials, toc(featureTimer));
    end
end

if any(~isfinite(featureValues), 'all')
    error('EEG:NonFiniteFeatures', 'Extracted feature table contains NaN or Inf values.');
end

numericFeatureTable = array2table(featureValues, ...
    'VariableNames', cellstr(featureNames));
featureTable = [trialManifest, numericFeatureTable];
end

