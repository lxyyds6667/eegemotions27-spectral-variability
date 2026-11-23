function tests = test_foundation
%TEST_FOUNDATION Unit tests for the pre-data analysis foundation.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testFile = mfilename('fullpath');
projectRoot = fileparts(fileparts(testFile));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
testCase.TestData.cfg = default_config();
end

function testParseDocumentedFilenameForms(testCase)
first = parse_trial_filename("12_7.0.txt");
second = parse_trial_filename("12_7.txt");
verifyEqual(testCase, first.participantId, 12);
verifyEqual(testCase, first.emotionId, 7);
verifyEqual(testCase, second.participantId, 12);
verifyEqual(testCase, second.emotionId, 7);
verifyError(testCase, @() parse_trial_filename("participant12emotion7.txt"), ...
    'EEG:UnparseableFilename');
end

function testLoaderEnforcesTimeByChannel(testCase)
cfg = testCase.TestData.cfg;
temporaryFolder = tempname;
mkdir(temporaryFolder);
cleanup = onCleanup(@() rmdir(temporaryFolder, 's'));

validPath = fullfile(temporaryFolder, '1_1.0.txt');
validMatrix = reshape(1:(600 * 14), 600, 14);
writematrix(validMatrix, validPath, 'Delimiter', 'tab');
loaded = load_eeg_trial(string(validPath), cfg.data.expectedChannelCount);
verifyEqual(testCase, loaded, double(validMatrix));

transposedPath = fullfile(temporaryFolder, '1_2.0.txt');
writematrix(validMatrix', transposedPath, 'Delimiter', 'tab');
verifyError(testCase, ...
    @() load_eeg_trial(string(transposedPath), cfg.data.expectedChannelCount), ...
    'EEG:TransposedData');
end

function testSha256AndAuditDetectStructuralConflicts(testCase)
cfg = testCase.TestData.cfg;
temporaryFolder = tempname;
rawFolder = fullfile(temporaryFolder, 'eeg_raw');
mkdir(rawFolder);
cleanup = onCleanup(@() rmdir(temporaryFolder, 's'));
cfg.paths.datasetRoot = temporaryFolder;
cfg.paths.rawData = rawFolder;
cfg.data.expectedParticipantCount = 2;
cfg.data.expectedEmotionIds = (1:2)';

abcPath = fullfile(temporaryFolder, 'abc.bin');
fileId = fopen(abcPath, 'w');
fwrite(fileId, uint8('abc'), 'uint8');
fclose(fileId);
verifyEqual(testCase, sha256_file(string(abcPath)), ...
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");

first = reshape(1:(600 * 14), 600, 14);
second = first + 1;
writematrix(first, fullfile(rawFolder, '1_1.0.txt'), 'Delimiter', 'tab');
writematrix(second, fullfile(rawFolder, '1_1.txt'), 'Delimiter', 'tab');
writematrix(first', fullfile(rawFolder, '2_2.0.txt'), 'Delimiter', 'tab');
writematrix(first + 2, fullfile(rawFolder, '2_1.0.txt'), 'Delimiter', 'tab');

[audit, manifest, summary] = audit_dataset(cfg);
verifyEqual(testCase, height(audit), 4);
verifyEqual(testCase, summary.duplicateTrialFileCount, 2);
verifyEqual(testCase, sum(audit.orientation == "channel_by_time"), 1);
verifyFalse(testCase, summary.canProceedToFeatureExtraction);
verifyEqual(testCase, height(manifest), 1);
end

function testWelchFeaturesLocalizeKnownFrequencies(testCase)
cfg = testCase.TestData.cfg;
fs = cfg.data.samplingRateHz;
time = (0:(10 * fs - 1))' / fs;
eeg = zeros(numel(time), cfg.data.expectedChannelCount);
eeg(:, 1) = sin(2 * pi * 10 * time);
eeg(:, 2) = sin(2 * pi * 20 * time);

[features, names, diagnostics] = extract_welch_features(eeg, cfg);
verifySize(testCase, features, [1, 70]);
verifySize(testCase, names, [1, 70]);

alphaIndex = find(strcmp(cfg.bands.names, 'alpha'));
betaIndex = find(strcmp(cfg.bands.names, 'beta'));
verifyGreaterThan(testCase, diagnostics.bandPower(alphaIndex, 1), ...
    100 * diagnostics.bandPower(betaIndex, 1));
verifyGreaterThan(testCase, diagnostics.bandPower(betaIndex, 2), ...
    100 * diagnostics.bandPower(alphaIndex, 2));
verifyEqual(testCase, names(1), "AF3__delta");
verifyEqual(testCase, names(5), "AF3__low_gamma");
verifyEqual(testCase, names(6), "F7__delta");

boundaryFrequencies = [4, 8, 12, 30, 40];
expectedBands = [2, 3, 4, 5, 0];
for boundaryIndex = 1:numel(boundaryFrequencies)
    frequencyRow = find(diagnostics.frequencyHz == boundaryFrequencies(boundaryIndex), 1);
    membership = find(diagnostics.bandBinMask(frequencyRow, :));
    if expectedBands(boundaryIndex) == 0
        verifyEmpty(testCase, membership);
    else
        verifyEqual(testCase, membership, expectedBands(boundaryIndex));
    end
end
end

function testParticipantFoldsAreDisjointAndBalanced(testCase)
participants = repelem((1:88)', 27);
[foldId, assignment] = assign_participant_folds(participants, 5, 2701);

for participant = 1:88
    verifyEqual(testCase, numel(unique(foldId(participants == participant))), 1);
end

foldCounts = groupsummary(assignment, 'fold_id');
verifyLessThanOrEqual(testCase, ...
    max(foldCounts.GroupCount) - min(foldCounts.GroupCount), 1);

for fold = 1:5
    trainParticipants = unique(participants(foldId ~= fold));
    testParticipants = unique(participants(foldId == fold));
    verifyEmpty(testCase, intersect(trainParticipants, testParticipants));
end
end

function testMetricsForPerfectAndCollapsedPredictions(testCase)
classIds = (1:3)';
yTrue = [1; 1; 2; 2; 3; 3];

perfect = compute_classification_metrics(yTrue, yTrue, classIds);
verifyEqual(testCase, perfect.accuracy, 1);
verifyEqual(testCase, perfect.balancedAccuracy, 1);
verifyEqual(testCase, perfect.macroF1, 1);

collapsed = compute_classification_metrics(yTrue, ones(size(yTrue)), classIds);
verifyEqual(testCase, collapsed.accuracy, 1/3, 'AbsTol', 1e-12);
verifyEqual(testCase, collapsed.balancedAccuracy, 1/3, 'AbsTol', 1e-12);
verifyEqual(testCase, collapsed.f1(2:3), [0; 0]);

allClasses = (1:27)';
allClassMetrics = compute_classification_metrics(allClasses, allClasses, allClasses);
verifySize(testCase, allClassMetrics.confusionMatrix, [27, 27]);
verifyEqual(testCase, allClassMetrics.macroF1, 1);
end

function testGroupedEvaluationProducesHeldOutPredictions(testCase)
cfg = testCase.TestData.cfg;
cfg.data.expectedEmotionIds = (1:3)';
cfg.model.lambda = 1e-3;

previousState = rng;
cleanup = onCleanup(@() rng(previousState));
rng(41, 'twister');

numParticipants = 15;
numClasses = 3;
participantIds = repelem((1:numParticipants)', numClasses);
labels = repmat((1:numClasses)', numParticipants, 1);
features = zeros(numel(labels), 3);
classCenters = [4, 0, 0; 0, 4, 0; 0, 0, 4];
for row = 1:numel(labels)
    participantShift = 0.02 * participantIds(row);
    features(row, :) = classCenters(labels(row), :) + participantShift + ...
        0.05 * randn(1, 3);
end

[foldId, ~] = assign_participant_folds(participantIds, 5, 2701);
evaluation = evaluate_grouped_cv(features, labels, participantIds, foldId, cfg);
repeatEvaluation = evaluate_grouped_cv(features, labels, participantIds, foldId, cfg);

verifyGreaterThan(testCase, evaluation.metrics.macroF1, 0.95);
verifyGreaterThan(testCase, evaluation.metrics.balancedAccuracy, 0.95);
verifyEqual(testCase, numel(evaluation.outOfFoldPrediction), numel(labels));
verifyEqual(testCase, height(evaluation.foldMetrics), 5);
verifyEqual(testCase, evaluation.majorityMetrics.accuracy, 1/3, 'AbsTol', 1e-12);
verifyEqual(testCase, repeatEvaluation.outOfFoldPrediction, ...
    evaluation.outOfFoldPrediction);

firstFoldTest = foldId == min(foldId);
extremeTestFeatures = features;
extremeTestFeatures(firstFoldTest, :) = extremeTestFeatures(firstFoldTest, :) + 1e6;
extremeEvaluation = evaluate_grouped_cv( ...
    extremeTestFeatures, labels, participantIds, foldId, cfg);
verifyEqual(testCase, extremeEvaluation.normalization(1).mean, ...
    evaluation.normalization(1).mean, 'AbsTol', 1e-12);
verifyEqual(testCase, extremeEvaluation.normalization(1).scale, ...
    evaluation.normalization(1).scale, 'AbsTol', 1e-12);
end

function testStructuredPermutationPreservesParticipantHistograms(testCase)
labels = [1; 1; 2; 3; 1; 2; 2; 3; 3];
participants = [1; 1; 1; 1; 2; 2; 2; 2; 2];
permuted = permute_labels_within_participant(labels, participants, 19);

for participant = unique(participants)'
    originalLabels = sort(labels(participants == participant));
    permutedLabels = sort(permuted(participants == participant));
    verifyEqual(testCase, permutedLabels, originalLabels);
end
end

