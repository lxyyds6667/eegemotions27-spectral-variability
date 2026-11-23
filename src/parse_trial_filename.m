function metadata = parse_trial_filename(filePath)
%PARSE_TRIAL_FILENAME Parse participant and emotion IDs from a public file.
%   The provisional accepted forms are PARTICIPANT_EMOTION.txt and
%   PARTICIPANT_EMOTION.0.txt. The dataset audit must confirm which form is
%   actually released before the real analysis is run.

arguments
    filePath (1,1) string
end

[~, stem, ext] = fileparts(filePath);
fileName = stem + ext;
token = regexp(fileName, ...
    '^(?<participant>\d+)_(?<emotion>\d+)(?:\.0)?\.txt$', ...
    'names', 'once');

if isempty(token)
    error('EEG:UnparseableFilename', ...
        ['Cannot parse "%s". Expected PARTICIPANT_EMOTION.txt or ' ...
         'PARTICIPANT_EMOTION.0.txt.'], fileName);
end

metadata = struct();
metadata.fileName = char(fileName);
metadata.participantId = str2double(token.participant);
metadata.emotionId = str2double(token.emotion);

if ~isfinite(metadata.participantId) || metadata.participantId < 1 || ...
        ~isfinite(metadata.emotionId) || metadata.emotionId < 1
    error('EEG:InvalidFilenameIdentifiers', ...
        'Participant and emotion IDs must be positive integers: %s', fileName);
end
end

