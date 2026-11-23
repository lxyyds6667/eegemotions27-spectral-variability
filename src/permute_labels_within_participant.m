function permutedLabels = permute_labels_within_participant(labels, participantIds, seed)
%PERMUTE_LABELS_WITHIN_PARTICIPANT Break feature-label links within subjects.
%   Each participant's label histogram is preserved exactly.

arguments
    labels (:,1) double
    participantIds (:,1) double
    seed (1,1) double {mustBeInteger, mustBeNonnegative}
end

if numel(labels) ~= numel(participantIds)
    error('EEG:RowCountMismatch', 'Labels and participant IDs must have equal length.');
end

previousState = rng;
restoreRng = onCleanup(@() rng(previousState));
rng(seed, 'twister');

permutedLabels = labels;
participants = unique(participantIds, 'sorted');
for participantIndex = 1:numel(participants)
    rows = find(participantIds == participants(participantIndex));
    permutedLabels(rows) = labels(rows(randperm(numel(rows))));
end
end

