function evaluation = evaluate_grouped_cv(features, labels, participantIds, foldId, cfg)
%EVALUATE_GROUPED_CV Participant-held-out linear multiclass evaluation.
%   Standardization parameters are estimated separately inside every
%   training fold. FOLDID must be constant for each participant.

arguments
    features (:,:) double
    labels (:,1) double
    participantIds (:,1) double
    foldId (:,1) double
    cfg (1,1) struct
end

numRows = size(features, 1);
if numel(labels) ~= numRows || numel(participantIds) ~= numRows || numel(foldId) ~= numRows
    error('EEG:RowCountMismatch', ...
        'Features, labels, participant IDs, and fold IDs must have equal row counts.');
end
if any(~isfinite(features), 'all')
    error('EEG:NonFiniteFeatures', 'Feature matrix contains NaN or Inf values.');
end

uniqueParticipants = unique(participantIds, 'sorted');
for participantIndex = 1:numel(uniqueParticipants)
    participantFolds = unique(foldId(participantIds == uniqueParticipants(participantIndex)));
    if numel(participantFolds) ~= 1
        error('EEG:ParticipantLeakage', ...
            'Participant %g occurs in more than one fold.', uniqueParticipants(participantIndex));
    end
end

classIds = cfg.data.expectedEmotionIds(:);
if any(~ismember(labels, classIds))
    error('EEG:UnknownClass', 'At least one label is absent from cfg.data.expectedEmotionIds.');
end

foldValues = unique(foldId, 'sorted');
numFolds = numel(foldValues);
outOfFoldPrediction = nan(numRows, 1);
majorityPrediction = nan(numRows, 1);
foldMacroF1 = nan(numFolds, 1);
foldBalancedAccuracy = nan(numFolds, 1);
foldAccuracy = nan(numFolds, 1);
trainParticipantCount = zeros(numFolds, 1);
testParticipantCount = zeros(numFolds, 1);
normalization = repmat(struct('mean', [], 'scale', []), numFolds, 1);

learner = templateLinear( ...
    'Learner', 'logistic', ...
    'Regularization', 'ridge', ...
    'Lambda', cfg.model.lambda, ...
    'Solver', 'lbfgs');

for foldIndex = 1:numFolds
    currentFold = foldValues(foldIndex);
    testMask = foldId == currentFold;
    trainMask = ~testMask;
    if ~any(testMask) || ~any(trainMask)
        error('EEG:EmptyFold', 'Fold %g has an empty train or test partition.', currentFold);
    end

    trainParticipants = unique(participantIds(trainMask));
    testParticipants = unique(participantIds(testMask));
    if ~isempty(intersect(trainParticipants, testParticipants))
        error('EEG:ParticipantLeakage', 'Fold %g shares participants across train and test.', currentFold);
    end
    trainParticipantCount(foldIndex) = numel(trainParticipants);
    testParticipantCount(foldIndex) = numel(testParticipants);

    missingTrainClasses = setdiff(classIds, unique(labels(trainMask)));
    if ~isempty(missingTrainClasses)
        error('EEG:MissingTrainingClass', ...
            'Fold %g training data lack class IDs: %s', ...
            currentFold, strjoin(string(missingTrainClasses), ', '));
    end

    trainingMean = mean(features(trainMask, :), 1);
    trainingScale = std(features(trainMask, :), 0, 1);
    trainingScale(~isfinite(trainingScale) | trainingScale == 0) = 1;
    normalization(foldIndex).mean = trainingMean;
    normalization(foldIndex).scale = trainingScale;

    standardizedTrain = (features(trainMask, :) - trainingMean) ./ trainingScale;
    standardizedTest = (features(testMask, :) - trainingMean) ./ trainingScale;

    model = fitcecoc(standardizedTrain, labels(trainMask), ...
        'Learners', learner, ...
        'Coding', 'onevsall', ...
        'ClassNames', classIds);
    outOfFoldPrediction(testMask) = predict(model, standardizedTest);

    majorityClass = mode(labels(trainMask));
    majorityPrediction(testMask) = majorityClass;

    foldMetrics = compute_classification_metrics( ...
        labels(testMask), outOfFoldPrediction(testMask), classIds);
    foldMacroF1(foldIndex) = foldMetrics.macroF1;
    foldBalancedAccuracy(foldIndex) = foldMetrics.balancedAccuracy;
    foldAccuracy(foldIndex) = foldMetrics.accuracy;
end

if any(~isfinite(outOfFoldPrediction)) || any(~isfinite(majorityPrediction))
    error('EEG:IncompletePrediction', 'At least one observation has no out-of-fold prediction.');
end

evaluation = struct();
evaluation.metrics = compute_classification_metrics(labels, outOfFoldPrediction, classIds);
evaluation.majorityMetrics = compute_classification_metrics(labels, majorityPrediction, classIds);
evaluation.outOfFoldPrediction = outOfFoldPrediction;
evaluation.majorityPrediction = majorityPrediction;
evaluation.foldMetrics = table( ...
    foldValues, trainParticipantCount, testParticipantCount, ...
    foldMacroF1, foldBalancedAccuracy, foldAccuracy, ...
    'VariableNames', {'fold_id', 'train_participants', 'test_participants', ...
    'macro_f1', 'balanced_accuracy', 'accuracy'});
evaluation.normalization = normalization;
evaluation.modelDescription = sprintf( ...
    'one-vs-all linear logistic ECOC, ridge lambda=%g', cfg.model.lambda);
end

