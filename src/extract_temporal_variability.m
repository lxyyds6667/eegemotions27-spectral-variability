function [variability, names, edges, blocks] = extract_temporal_variability(eeg, cfg, mode)
%EXTRACT_TEMPORAL_VARIABILITY Sample SD of five segment log powers.
%   The default mode preserves the original behavior: each fifth is used in
%   full.  The "centered3s" mode uses the central three seconds of each
%   fifth, which gives two 2-second Welch windows at 50% overlap.
%
%   EDGES gives the six zero-based boundaries of the five full segments.
%   Its last value is the sample count. BLOCKS gives the samples used in
%   each segment, represented as five rows of 1-based inclusive indices.

if nargin < 3 || isempty(mode)
    mode = "full";
else
    mode = string(mode);
end

if ~isscalar(mode) || ~any(mode == ["full", "centered3s"])
    error('EEG:InvalidTemporalMode', ...
        'Temporal mode must be "full" or "centered3s".');
end

edges = floor((0:5) * size(eeg, 1) / 5);
segmentLengths = diff(edges);
samplingRateHz = cfg.data.samplingRateHz;

if mode == "full"
    minimumLength = round(cfg.welch.windowSeconds * samplingRateHz);
    if min(segmentLengths) < minimumLength
        error('EEG:SegmentTooShort', ...
            'Each fifth must contain a full Welch window (%d samples).', ...
            minimumLength);
    end
    blocks = [edges(1:5)' + 1, edges(2:6)'];
    nameSuffix = "__sd5";
else
    centerLength = 3 * samplingRateHz;
    if any(segmentLengths < centerLength)
        error('EEG:SegmentTooShort', ...
            ['Each fifth must contain at least 3 seconds (%g samples) ', ...
             'for centered3s variability.'], centerLength);
    end

    leftSkip = floor((segmentLengths - centerLength) / 2);
    starts = edges(1:5)' + leftSkip' + 1;
    blocks = [starts, starts + centerLength - 1];
    nameSuffix = "__sd5_centered3s";
end

for k = 1:5
    segment = eeg(blocks(k, 1):blocks(k, 2), :);
    [values, baseNames] = extract_welch_features(segment, cfg);
    if k == 1
        powers = zeros(5, numel(values));
    end
    powers(k, :) = values;
end

variability = std(powers, 0, 1);
names = baseNames + nameSuffix;
end
