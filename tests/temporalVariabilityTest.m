classdef temporalVariabilityTest < matlab.unittest.TestCase
    properties (TestParameter)
        rate = {128, 256}
    end
    methods (Test)
        function knownAlphaAmplitude(testCase, rate)
            cfg = default_config();
            cfg.data.samplingRateHz = rate;
            wave = sin(2*pi*10*(0:4*rate-1)'/rate);
            segment = repmat(wave, 1, 14);
            fixedSignal = repmat(segment, 5, 1);
            gain = repelem((1:5)', size(segment,1));
            [fixed, names] = extract_temporal_variability(fixedSignal, cfg);
            changing = extract_temporal_variability(fixedSignal .* gain, cfg);
            alpha = names == "AF3__alpha__sd5";
            testCase.verifySize(fixed, [1 70]);
            testCase.verifyEqual(fixed(alpha), 0, AbsTol=1e-10);
            testCase.verifyEqual(changing(alpha), std(20*log10(1:5)), AbsTol=1e-10);
        end
        function includesRemainder(testCase)
            cfg = default_config();
            [~,~,edges] = extract_temporal_variability(zeros(2563,14), cfg);
            testCase.verifyEqual(edges, [0 512 1025 1537 2050 2563]);
            testCase.verifyError(@() extract_temporal_variability(zeros(2559,14),cfg), ...
                'EEG:SegmentTooShort');
        end
    end
end
