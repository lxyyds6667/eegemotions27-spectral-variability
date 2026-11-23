function cfg = default_config()
%DEFAULT_CONFIG Frozen settings for the EEGEmotions-27 Fourier baseline.

projectRoot = fileparts(fileparts(mfilename('fullpath')));

cfg.paths.projectRoot = projectRoot;
cfg.paths.datasetRoot = fullfile(projectRoot, 'data', 'raw', 'EEGEmotions-27');
cfg.paths.rawData = fullfile(cfg.paths.datasetRoot, 'eeg_raw');
cfg.paths.participantInfo = fullfile(cfg.paths.datasetRoot, 'participants_info.csv');
cfg.paths.channelLocations = fullfile(cfg.paths.datasetRoot, 'emotivX_channels_location.ced');
cfg.paths.upstreamReadme = fullfile(cfg.paths.datasetRoot, 'readme.md');
cfg.paths.interim = fullfile(projectRoot, 'data', 'interim');
cfg.paths.outputs = fullfile(projectRoot, 'outputs');

cfg.data.samplingRateHz = 256;
cfg.data.expectedChannelCount = 14;
cfg.data.channelNames = { ...
    'AF3', 'F7', 'F3', 'FC5', 'T7', 'P7', 'O1', ...
    'O2', 'P8', 'T8', 'FC6', 'F4', 'F8', 'AF4'};
cfg.data.expectedEmotionIds = (1:27)';
cfg.data.emotionNames = { ...
    'admiration', 'adoration', 'aesthetic', 'amusement', 'anger', ...
    'anxiety', 'awes', 'awkwardness', 'boredom', 'calmness', ...
    'confusion', 'craving', 'disgust', 'empathic_pain', 'entrancement', ...
    'excitement', 'fear', 'horror', 'interest', 'joy', 'nostalgia', ...
    'relief', 'romance', 'sadness', 'satisfaction', 'sexual_desire', ...
    'surprised'};
cfg.data.expectedParticipantCount = 88;
cfg.data.units = 'unknown';
cfg.data.textDelimiter = char(9);

cfg.welch.windowSeconds = 2;
cfg.welch.overlapFraction = 0.50;
cfg.welch.nfftSeconds = 2;

cfg.bands.names = {'delta', 'theta', 'alpha', 'beta', 'low_gamma'};
cfg.bands.edgesHz = [ ...
     1,  4; ...
     4,  8; ...
     8, 12; ...
    12, 30; ...
    30, 40];

cfg.features.type = 'log_absolute_band_power';
cfg.features.powerFloor = realmin('double');

cfg.cv.numFolds = 5;
cfg.cv.seed = 2701;

cfg.model.learner = 'linear_logistic_ecoc';
cfg.model.lambda = 1e-3;

cfg.permutation.numRepeats = 100;
cfg.permutation.seed = 2702;
cfg.randomBaseline.numRepeats = 1000;
cfg.randomBaseline.seed = 2703;

cfg.audit.halfRateThreshold = 0.75;
cfg.audit.durationToleranceFraction = 0.05;
cfg.audit.nominalHighFrequencyBandHz = [50, 90];
cfg.audit.nominalLowFrequencyBandHz = [1, 40];
end

