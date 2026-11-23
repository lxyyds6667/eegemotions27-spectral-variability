function [foldId, participantFoldTable] = assign_participant_folds(participantIds, numFolds, seed)
%ASSIGN_PARTICIPANT_FOLDS Deterministically assign whole participants to folds.

arguments
    participantIds (:,1)
    numFolds (1,1) double {mustBeInteger, mustBeGreaterThan(numFolds, 1)}
    seed (1,1) double {mustBeInteger, mustBeNonnegative}
end

uniqueParticipants = unique(participantIds, 'sorted');
numParticipants = numel(uniqueParticipants);
if numParticipants < numFolds
    error('EEG:TooManyFolds', ...
        'Cannot create %d folds from only %d participants.', numFolds, numParticipants);
end

previousState = rng;
restoreRng = onCleanup(@() rng(previousState));
rng(seed, 'twister');
randomOrder = randperm(numParticipants);

participantFold = zeros(numParticipants, 1);
for orderIndex = 1:numParticipants
    participantFold(randomOrder(orderIndex)) = mod(orderIndex - 1, numFolds) + 1;
end

[isKnown, participantIndex] = ismember(participantIds, uniqueParticipants);
if ~all(isKnown)
    error('EEG:FoldAssignmentFailure', 'At least one participant ID could not be assigned.');
end
foldId = participantFold(participantIndex);

participantFoldTable = table(uniqueParticipants, participantFold, ...
    'VariableNames', {'participant_id', 'fold_id'});
end

