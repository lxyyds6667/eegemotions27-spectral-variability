function eeg = load_eeg_trial(filePath, expectedChannelCount)
%LOAD_EEG_TRIAL Load one numeric, time-by-channel EEG text file.
%   This function intentionally refuses to transpose data silently.

arguments
    filePath (1,1) string
    expectedChannelCount (1,1) double {mustBeInteger, mustBePositive}
end

if ~isfile(filePath)
    error('EEG:MissingFile', 'EEG file does not exist: %s', filePath);
end

eeg = readmatrix(filePath, 'FileType', 'text', 'Delimiter', char(9));

if isempty(eeg) || ~isnumeric(eeg) || ~ismatrix(eeg)
    error('EEG:InvalidMatrix', 'File did not contain a nonempty numeric matrix: %s', filePath);
end

if size(eeg, 2) ~= expectedChannelCount
    if size(eeg, 1) == expectedChannelCount
        error('EEG:TransposedData', ...
            ['File appears to be channels-by-time (%d rows). Confirm the ' ...
             'official layout and transpose explicitly in a documented step: %s'], ...
            expectedChannelCount, filePath);
    end
    error('EEG:ChannelCount', ...
        'Expected %d columns but found a %d-by-%d matrix: %s', ...
        expectedChannelCount, size(eeg, 1), size(eeg, 2), filePath);
end

if any(~isfinite(eeg), 'all')
    error('EEG:NonFiniteData', 'File contains NaN or Inf values: %s', filePath);
end

if size(eeg, 1) < 2
    error('EEG:TooFewSamples', 'File contains fewer than two time samples: %s', filePath);
end

eeg = double(eeg);
end

