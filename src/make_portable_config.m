function portable = make_portable_config(cfg)
%MAKE_PORTABLE_CONFIG Replace machine-specific absolute paths for outputs.

portable = cfg;
portable.paths = struct();
portable.paths.projectRoot = '.';
portable.paths.datasetRoot = fullfile('data', 'raw', 'EEGEmotions-27');
portable.paths.rawData = fullfile(portable.paths.datasetRoot, 'eeg_raw');
portable.paths.participantInfo = fullfile( ...
    portable.paths.datasetRoot, 'participants_info.csv');
portable.paths.channelLocations = fullfile( ...
    portable.paths.datasetRoot, 'emotivX_channels_location.ced');
portable.paths.upstreamReadme = fullfile(portable.paths.datasetRoot, 'readme.md');
portable.paths.interim = fullfile('data', 'interim');
portable.paths.outputs = 'outputs';
end
