classdef fixedWindowVariabilityTest < matlab.unittest.TestCase
    %FIXEDWINDOWVARIABILITYTEST Fixed three-second temporal windows.

    properties (TestParameter)
        rate = {128, 256}
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'src')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectRoot, 'config')));
        end
    end

    methods (Test)
        function defaultModeMatchesExplicitFullMode(testCase, rate)
            cfg = default_config();
            cfg.data.samplingRateHz = rate;
            segmentLength = 4 * rate;
            wave = sin(2 * pi * 10 * (0:segmentLength - 1)' / rate);
            segment = repmat(wave, 1, cfg.data.expectedChannelCount);
            eeg = repmat(segment, 5, 1);

            [defaultValues, defaultNames, defaultEdges, defaultBlocks] = ...
                extract_temporal_variability(eeg, cfg);
            [fullValues, fullNames, fullEdges, fullBlocks] = ...
                extract_temporal_variability(eeg, cfg, "full");

            testCase.verifyEqual(defaultValues, fullValues, AbsTol=1e-12);
            testCase.verifyEqual(defaultNames, fullNames);
            testCase.verifyEqual(defaultEdges, fullEdges);
            testCase.verifyEqual(defaultBlocks, fullBlocks);
        end

        function centeredBlocksUseFloorEdgesAndOneBasedIndices(testCase, rate)
            cfg = default_config();
            cfg.data.samplingRateHz = rate;
            baseLength = 3 * rate + 2;
            sampleCount = 5 * baseLength + 3;
            eeg = zeros(sampleCount, cfg.data.expectedChannelCount);

            [~, names, edges, blocks] = ...
                extract_temporal_variability(eeg, cfg, "centered3s");

            expectedEdges = floor((0:5) * sampleCount / 5);
            segmentLengths = diff(expectedEdges);
            centerLength = 3 * rate;
            leftSkip = floor((segmentLengths - centerLength) / 2);
            expectedStarts = expectedEdges(1:5)' + leftSkip' + 1;
            expectedBlocks = [expectedStarts, expectedStarts + centerLength - 1];

            testCase.verifyEqual(edges, expectedEdges);
            testCase.verifyEqual(blocks, expectedBlocks);
            testCase.verifyEqual(blocks(:, 2) - blocks(:, 1) + 1, ...
                repmat(centerLength, 5, 1));
            testCase.verifyTrue(all(endsWith(names, "__sd5_centered3s")));
            testCase.verifyEqual(names(1), "AF3__delta__sd5_centered3s");
        end

        function centeredExactThreeSecondsGivesTwoWelchWindows(testCase, rate)
            cfg = default_config();
            cfg.data.samplingRateHz = rate;
            centerLength = 3 * rate;
            eeg = zeros(5 * centerLength, cfg.data.expectedChannelCount);

            [variability, ~, edges, blocks] = ...
                extract_temporal_variability(eeg, cfg, "centered3s");

            expectedEdges = 0:centerLength:5 * centerLength;
            windowLength = round(cfg.welch.windowSeconds * rate);
            overlapLength = round(cfg.welch.overlapFraction * windowLength);
            stepLength = windowLength - overlapLength;
            windowCount = floor((centerLength - overlapLength) / stepLength);

            testCase.verifyEqual(edges, expectedEdges);
            testCase.verifyEqual(blocks, ...
                [(1:centerLength:5 * centerLength)', ...
                 (centerLength:centerLength:5 * centerLength)']);
            testCase.verifyEqual(blocks(:, 2) - blocks(:, 1) + 1, ...
                repmat(centerLength, 5, 1));
            testCase.verifyEqual(windowCount, 2);
            testCase.verifyEqual(variability, zeros(size(variability)), ...
                AbsTol=1e-12);
        end

        function centeredModeRejectsAnyShortFifth(testCase, rate)
            cfg = default_config();
            cfg.data.samplingRateHz = rate;
            centerLength = 3 * rate;
            eeg = zeros(5 * centerLength - 1, cfg.data.expectedChannelCount);

            testCase.verifyError(@() extract_temporal_variability( ...
                eeg, cfg, "centered3s"), 'EEG:SegmentTooShort');
        end

        function centeredModeUsesTheMiddleThreeSeconds(testCase, rate)
            cfg = default_config();
            cfg.data.samplingRateHz = rate;
            segmentLength = 6 * rate;
            centerLength = 3 * rate;
            leftSkip = floor((segmentLength - centerLength) / 2);
            time = (0:segmentLength - 1)' / rate;
            alphaWave = sin(2 * pi * 10 * time);
            centerGain = (1:5)';
            outsideGain = 6 - centerGain;
            segments = centerGain * alphaWave';
            segments(:, 1:leftSkip) = outsideGain * alphaWave(1:leftSkip)';
            segments(:, leftSkip + centerLength + 1:end) = ...
                outsideGain * alphaWave(leftSkip + centerLength + 1:end)';
            eeg = repmat(reshape(segments', [], 1), ...
                1, cfg.data.expectedChannelCount);

            [centeredValues, centeredNames, ~, blocks] = ...
                extract_temporal_variability(eeg, cfg, "centered3s");
            [fullValues, fullNames] = extract_temporal_variability(eeg, cfg);
            alphaCentered = centeredValues(centeredNames == ...
                "AF3__alpha__sd5_centered3s");
            alphaFull = fullValues(fullNames == "AF3__alpha__sd5");
            expectedCentered = std(20 * log10(centerGain));

            testCase.verifyEqual(alphaCentered, expectedCentered, AbsTol=1e-10);
            testCase.verifyGreaterThan(abs(alphaFull - alphaCentered), 1);
            testCase.verifyEqual(blocks(:, 2) - blocks(:, 1) + 1, ...
                repmat(centerLength, 5, 1));
        end
    end
end
