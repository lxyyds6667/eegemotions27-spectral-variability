function [features, featureNames, diagnostics] = extract_welch_features(eeg, cfg)
%EXTRACT_WELCH_FEATURES Compute channel-wise log absolute band power.
%   EEG must be samples-by-channels. Discrete frequency bins use half-open
%   bands, so no bin is double-counted and 40 Hz is excluded.

arguments
    eeg (:,:) double
    cfg (1,1) struct
end

expectedChannels = cfg.data.expectedChannelCount;
if size(eeg, 2) ~= expectedChannels
    error('EEG:ChannelCount', 'Expected %d channels, received %d.', ...
        expectedChannels, size(eeg, 2));
end
if any(~isfinite(eeg), 'all')
    error('EEG:NonFiniteData', 'EEG matrix contains NaN or Inf values.');
end

fs = cfg.data.samplingRateHz;
windowLength = round(cfg.welch.windowSeconds * fs);
overlapLength = round(cfg.welch.overlapFraction * windowLength);
nfft = round(cfg.welch.nfftSeconds * fs);

if size(eeg, 1) < windowLength
    error('EEG:TrialTooShort', ...
        'Trial has %d samples; at least %d are required for the Welch window.', ...
        size(eeg, 1), windowLength);
end
if overlapLength >= windowLength
    error('EEG:InvalidWelchOverlap', 'Welch overlap must be shorter than the window.');
end
if nfft < windowLength
    error('EEG:InvalidNfft', 'NFFT (%d) must be at least the window length (%d).', ...
        nfft, windowLength);
end

eegCentered = eeg - mean(eeg, 1);
window = hann(windowLength, 'periodic');
[psdValues, frequencyHz] = pwelch( ...
    eegCentered, window, overlapLength, nfft, fs, 'onesided');

frequencyStepHz = median(diff(frequencyHz));
bandEdges = cfg.bands.edgesHz;
numBands = size(bandEdges, 1);
bandPower = zeros(numBands, expectedChannels);

for bandIndex = 1:numBands
    lowerEdge = bandEdges(bandIndex, 1);
    upperEdge = bandEdges(bandIndex, 2);
    inBand = frequencyHz >= lowerEdge & frequencyHz < upperEdge;
    if ~any(inBand)
        error('EEG:EmptyFrequencyBand', ...
            'No Welch bins fall inside band %s [%g, %g].', ...
            cfg.bands.names{bandIndex}, lowerEdge, upperEdge);
    end
    bandPower(bandIndex, :) = sum(psdValues(inBand, :), 1) * frequencyStepHz;
end

logBandPower = 10 * log10(max(bandPower, cfg.features.powerFloor));
features = reshape(logBandPower, 1, []);

featureNames = strings(1, numel(features));
nameIndex = 1;
for channelIndex = 1:expectedChannels
    for bandIndex = 1:numBands
        featureNames(nameIndex) = string(cfg.data.channelNames{channelIndex}) + ...
            "__" + string(cfg.bands.names{bandIndex});
        nameIndex = nameIndex + 1;
    end
end

diagnostics = struct();
diagnostics.frequencyHz = frequencyHz;
diagnostics.psd = psdValues;
diagnostics.bandPower = bandPower;
diagnostics.logBandPower = logBandPower;
diagnostics.frequencyStepHz = frequencyStepHz;
diagnostics.units = cfg.data.units;
diagnostics.bandBinMask = false(numel(frequencyHz), numBands);
for bandIndex = 1:numBands
    diagnostics.bandBinMask(:, bandIndex) = ...
        frequencyHz >= bandEdges(bandIndex, 1) & ...
        frequencyHz < bandEdges(bandIndex, 2);
end
end

