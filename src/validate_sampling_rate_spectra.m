function participantSampling = validate_sampling_rate_spectra( ...
    fileAudit, participantSampling, cfg)
%VALIDATE_SAMPLING_RATE_SPECTRA Check the independent bandwidth signature.
%   At a nominal 256 Hz axis, true 128 Hz recordings shift the headset's
%   ~43 Hz bandwidth edge toward ~86 Hz. This function reads the first five
%   valid condition IDs per participant and records the median high/low ratio,
%   reducing sensitivity to a single artifact-heavy trial.

arguments
    fileAudit table
    participantSampling table
    cfg (1,1) struct
end


numParticipants = height(participantSampling);
validationFiles = strings(numParticipants, 1);
validationTrialCount = zeros(numParticipants, 1);
nominalHighToLowPower = nan(numParticipants, 1);
log10NominalHighToLowPower = nan(numParticipants, 1);
documentedFs = cfg.data.samplingRateHz;
windowLength = round(cfg.welch.windowSeconds * documentedFs);
window = hann(windowLength, 'periodic');
overlap = round(cfg.welch.overlapFraction * windowLength);
nfft = round(cfg.welch.nfftSeconds * documentedFs);

for participantIndex = 1:numParticipants
    participantId = participantSampling.participant_id(participantIndex);
    candidates = find(fileAudit.participant_id == participantId & ...
        fileAudit.structural_ready);
    if isempty(candidates)
        continue;
    end
    [~, candidateOrder] = sort(fileAudit.emotion_id(candidates));
    candidates = candidates(candidateOrder);
    candidates = candidates(1:min(5, numel(candidates)));
    trialLogRatios = nan(numel(candidates), 1);
    selectedFiles = strings(numel(candidates), 1);
    for trialIndex = 1:numel(candidates)
        row = candidates(trialIndex);
        selectedFiles(trialIndex) = fileAudit.source_relative_path(row);
        filePath = fullfile(cfg.paths.datasetRoot, selectedFiles(trialIndex));
        eeg = load_eeg_trial(string(filePath), cfg.data.expectedChannelCount);
        eeg = eeg - mean(eeg, 1);
        [psdValues, frequencyHz] = pwelch( ...
            eeg, window, overlap, nfft, documentedFs, 'onesided');
        frequencyStep = median(diff(frequencyHz));
        lowBand = frequencyHz >= cfg.audit.nominalLowFrequencyBandHz(1) & ...
            frequencyHz < cfg.audit.nominalLowFrequencyBandHz(2);
        highBand = frequencyHz >= cfg.audit.nominalHighFrequencyBandHz(1) & ...
            frequencyHz < cfg.audit.nominalHighFrequencyBandHz(2);
        lowPower = sum(psdValues(lowBand, :), 'all') * frequencyStep;
        highPower = sum(psdValues(highBand, :), 'all') * frequencyStep;
        trialLogRatios(trialIndex) = log10(highPower / lowPower);
    end
    validationFiles(participantIndex) = strjoin(selectedFiles, '|');
    validationTrialCount(participantIndex) = numel(candidates);
    log10NominalHighToLowPower(participantIndex) = median(trialLogRatios);
    nominalHighToLowPower(participantIndex) = ...
        10 ^ log10NominalHighToLowPower(participantIndex);
end

participantSampling.validation_files = validationFiles;
participantSampling.validation_trial_count = validationTrialCount;
participantSampling.nominal_high_to_low_power_ratio = nominalHighToLowPower;
participantSampling.log10_nominal_high_to_low_power_ratio = ...
    log10NominalHighToLowPower;
end

