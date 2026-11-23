classdef computeSamplingGroupMetricsTest < matlab.unittest.TestCase
    %COMPUTESAMPLINGGROUPMETRICSTEST Sampling-rate subgroup diagnostics.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'src')));
        end
    end

    methods (Test)
        function testKnownGroupMetrics(testCase)
            yTrue = [1; 2; 1; 2; 1; 2; 1; 2];
            yPredicted = [1; 2; 1; 2; 1; 1; 1; 1];
            participantIds = [1; 1; 2; 2; 3; 3; 4; 4];
            samplingRateHz = [128; 128; 128; 128; 256; 256; 256; 256];

            result = compute_sampling_group_metrics( ...
                yTrue, yPredicted, participantIds, samplingRateHz, (1:2)');

            testCase.verifyEqual(result.sampling_rate_hz, [128; 256]);
            testCase.verifyEqual(result.participant_count, [2; 2]);
            testCase.verifyEqual(result.trial_count, [4; 4]);
            testCase.verifyEqual(result.macro_f1, [1; 1/3], AbsTol=1e-12);
            testCase.verifyEqual(result.balanced_accuracy, [1; 1/2], AbsTol=1e-12);
            testCase.verifyEqual(result.accuracy, [1; 1/2], AbsTol=1e-12);
        end

        function testParticipantRateConflictErrors(testCase)
            testCase.verifyError(@() compute_sampling_group_metrics( ...
                [1; 2], [1; 2], [1; 1], [128; 256], (1:2)'), ...
                'EEG:ParticipantSamplingConflict');
        end

        function testLengthMismatchErrors(testCase)
            testCase.verifyError(@() compute_sampling_group_metrics( ...
                [1; 2], 1, [1; 2], [128; 128], (1:2)'), ...
                'EEG:SubgroupLengthMismatch');
        end
    end
end
