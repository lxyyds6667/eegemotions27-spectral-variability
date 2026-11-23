classdef makeTrialManifestTest < matlab.unittest.TestCase
    %MAKETRIALMANIFESTTEST Explicit trial-selection policy checks.

    properties
        Cfg
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'src')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'config')));
            testCase.Cfg = default_config();
        end
    end

    methods (Test)
        function testSelectedRowsBecomeSortedTrials(testCase)
            fileAudit = makeTrialManifestTest.exampleAudit();

            result = make_trial_manifest( ...
                fileAudit, testCase.Cfg, [true; false; true]);

            testCase.verifyEqual(result.trial_id, ["P002_E03"; "P003_E01"]);
            testCase.verifyEqual(result.participant_id, [2; 3]);
            testCase.verifyEqual(result.condition_id, [3; 1]);
            testCase.verifyEqual(result.sample_count, [640; 512]);
            testCase.verifyEqual(result.sampling_rate_hz, [128; 256]);
        end

        function testSelectionLengthErrors(testCase)
            fileAudit = makeTrialManifestTest.exampleAudit();

            testCase.verifyError(@() make_trial_manifest( ...
                fileAudit, testCase.Cfg, [true; false]), ...
                'EEG:ManifestSelectionLength');
        end
    end

    methods (Static, Access = private)
        function fileAudit = exampleAudit()
            participantId = [2; 1; 3];
            emotionId = [3; 2; 1];
            sourceRelativePath = ["eeg_raw/2_3.0.txt"; ...
                "eeg_raw/1_2.0.txt"; "eeg_raw/3_1.0.txt"];
            fileBytes = [1000; 1100; 1200];
            sha256 = ["a"; "b"; "c"];
            numRows = [640; 700; 512];
            inferredSamplingRateHz = [128; 256; 256];
            samplingRateBasis = ["inferred"; "documented"; "documented"];
            fileAudit = table(participantId, emotionId, sourceRelativePath, ...
                fileBytes, sha256, numRows, inferredSamplingRateHz, ...
                samplingRateBasis, 'VariableNames', {'participant_id', ...
                'emotion_id', 'source_relative_path', 'file_bytes', 'sha256', ...
                'num_rows', 'inferred_sampling_rate_hz', 'sampling_rate_basis'});
        end
    end
end
