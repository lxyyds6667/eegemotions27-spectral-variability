function [featureTable, featureNames] = run_feature_extraction()
%RUN_FEATURE_EXTRACTION Build and cache the whole-trial Welch feature table.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = default_config();

auditFolder = fullfile(cfg.paths.outputs, 'audit');
summaryPath = fullfile(auditFolder, 'audit_summary.json');
manifestPath = fullfile(auditFolder, 'trial_manifest.csv');
if ~isfile(summaryPath) || ~isfile(manifestPath)
    error('EEG:AuditRequired', ...
        'Run run_data_audit before feature extraction.');
end

auditSummary = jsondecode(fileread(summaryPath));
if ~auditSummary.canProceedToFeatureExtraction
    error('EEG:AuditBlocked', ...
        'The saved audit does not allow feature extraction.');
end

trialManifest = readtable(manifestPath, 'TextType', 'string');
[featureTable, featureNames, representative] = ...
    build_feature_table(cfg, trialManifest);

if ~isfolder(cfg.paths.interim)
    mkdir(cfg.paths.interim);
end
featureMatPath = fullfile(cfg.paths.interim, 'welch_features.mat');
featureCsvPath = fullfile(cfg.paths.interim, 'welch_features.csv');
save(featureMatPath, 'featureTable', 'featureNames', 'cfg', '-v7.3');
writetable(featureTable, featureCsvPath);

outputFolder = fullfile(cfg.paths.outputs, 'features');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

psdFigure = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 820, 520]);
meanLogPsd = mean(10 * log10(max(representative.psd, ...
    cfg.features.powerFloor)), 2);
plot(representative.frequencyHz, meanLogPsd, ...
    'Color', [0.10, 0.35, 0.70], 'LineWidth', 1.4);
xlim([1, 45]);
xlabel('Frequency (Hz)');
ylabel('Mean channel PSD (dB, arbitrary units^2/Hz)');
title("Representative whole-trial Welch PSD: " + representative.trialId);
grid on;
box off;
for edge = unique(cfg.bands.edgesHz(:))'
    xline(edge, ':', 'Color', [0.55, 0.55, 0.55]);
end
exportgraphics(psdFigure, ...
    fullfile(outputFolder, 'representative_psd.png'), 'Resolution', 180);
close(psdFigure);

metadata = struct();
metadata.generatedAt = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
metadata.sourceAuditSha256 = char(sha256_file(string(summaryPath)));
metadata.upstream = auditSummary.upstream;
metadata.trialCount = height(featureTable);
metadata.featureCount = numel(featureNames);
metadata.featureNames = cellstr(featureNames);
metadata.channelNames = cfg.data.channelNames;
metadata.bandNames = cfg.bands.names;
metadata.bandEdgesHz = cfg.bands.edgesHz;
metadata.welch = cfg.welch;
metadata.featureType = cfg.features.type;
metadata.powerFloor = cfg.features.powerFloor;
metadata.signalUnits = cfg.data.units;
write_feature_metadata(fullfile(outputFolder, 'feature_metadata.json'), metadata);

fprintf('Feature table: %d trials x %d spectral features.\n', ...
    height(featureTable), numel(featureNames));
fprintf('Cached MAT: %s\n', featureMatPath);
fprintf('Cached CSV: %s\n', featureCsvPath);
end

function write_feature_metadata(filePath, metadata)
fileId = fopen(filePath, 'w');
if fileId < 0
    error('EEG:OutputOpenFailed', 'Cannot open output file: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(metadata, 'PrettyPrint', true));
end

