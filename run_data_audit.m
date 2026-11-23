function [fileAudit, trialManifest, summary] = run_data_audit()
%RUN_DATA_AUDIT Audit official raw files and write machine-readable evidence.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = default_config();

outputFolder = fullfile(cfg.paths.outputs, 'audit');
if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

[fileAudit, trialManifest, summary, participantSampling, conditionTiming] = ...
    audit_dataset(cfg);
participantSampling = validate_sampling_rate_spectra( ...
    fileAudit, participantSampling, cfg);
participantSampling = attach_participant_metadata( ...
    participantSampling, cfg.paths.participantInfo);
demographicCounts = summarize_sampling_demographics(participantSampling);
writetable(fileAudit, fullfile(outputFolder, 'data_audit.csv'));
writetable(trialManifest, fullfile(outputFolder, 'trial_manifest.csv'));
writetable(participantSampling, fullfile(outputFolder, 'participant_sampling_rates.csv'));
writetable(demographicCounts, ...
    fullfile(outputFolder, 'sampling_rate_demographics.csv'));
writetable(conditionTiming, fullfile(outputFolder, 'condition_timing.csv'));

parseable = fileAudit.parse_ok;
participants = unique(fileAudit.participant_id(parseable), 'sorted');
emotions = cfg.data.expectedEmotionIds(:)';
coverage = zeros(numel(participants), numel(emotions));
for row = 1:height(fileAudit)
    if ~fileAudit.parse_ok(row)
        continue;
    end
    participantIndex = find(participants == fileAudit.participant_id(row), 1);
    emotionIndex = find(emotions == fileAudit.emotion_id(row), 1);
    if ~isempty(participantIndex) && ~isempty(emotionIndex)
        coverage(participantIndex, emotionIndex) = coverage(participantIndex, emotionIndex) + 1;
    end
end
coverageTable = array2table(coverage, ...
    'VariableNames', compose('condition_%02d', emotions));
coverageTable = addvars(coverageTable, participants, 'Before', 1, ...
    'NewVariableNames', 'participant_id');
writetable(coverageTable, fullfile(outputFolder, 'participant_condition_coverage.csv'));

halfRate = participantSampling.inferred_sampling_rate_hz == 128;
fullRate = participantSampling.inferred_sampling_rate_hz == 256;
summary.spectralSamplingValidation = struct( ...
    'nominalHighBandHz', cfg.audit.nominalHighFrequencyBandHz, ...
    'nominalLowBandHz', cfg.audit.nominalLowFrequencyBandHz, ...
    'inferred128MedianLog10Ratio', median( ...
        participantSampling.log10_nominal_high_to_low_power_ratio(halfRate)), ...
    'consistent256MedianLog10Ratio', median( ...
        participantSampling.log10_nominal_high_to_low_power_ratio(fullRate)), ...
    'completeSeparation', min( ...
        participantSampling.log10_nominal_high_to_low_power_ratio(halfRate)) > ...
        max(participantSampling.log10_nominal_high_to_low_power_ratio(fullRate)));

samplingFigure = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 760, 520]);
hold on;
scatter(participantSampling.median_raw_length_ratio(fullRate), ...
    participantSampling.log10_nominal_high_to_low_power_ratio(fullRate), ...
    48, [0.10, 0.35, 0.70], 'filled', 'MarkerFaceAlpha', 0.75);
scatter(participantSampling.median_raw_length_ratio(halfRate), ...
    participantSampling.log10_nominal_high_to_low_power_ratio(halfRate), ...
    48, [0.85, 0.30, 0.15], 'filled', 'MarkerFaceAlpha', 0.75);
xline(cfg.audit.halfRateThreshold, '--k', 'Frozen threshold 0.75');
xlabel('Participant median row-count ratio to condition median');
ylabel('log_{10}(nominal 50--90 Hz power / 1--40 Hz power)');
title('Two participant-level sampling-rate clusters');
legend({'Consistent with 256 Hz', 'Inferred 128 Hz'}, 'Location', 'best');
grid on;
box off;
exportgraphics(samplingFigure, ...
    fullfile(outputFolder, 'sampling_rate_diagnostic.png'), 'Resolution', 180);
close(samplingFigure);

coverageFigure = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 900, 620]);
imagesc(emotions, 1:numel(participants), coverage);
colormap(coverageFigure, [0.85, 0.85, 0.85; 0.15, 0.55, 0.35; 0.75, 0.20, 0.20]);
clim([-0.5, 2.5]);
colorbar('Ticks', [0, 1, 2]);
xlabel('Condition ID');
ylabel('Participant row (sorted ID)');
title('Participant-condition file coverage (0 missing, 1 present)');
exportgraphics(coverageFigure, ...
    fullfile(outputFolder, 'participant_condition_coverage.png'), 'Resolution', 180);
close(coverageFigure);

summary.upstream = upstream_provenance(cfg.paths.datasetRoot);
summary.generatedAt = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
summary.matlab = struct( ...
    'version', version, ...
    'release', version('-release'), ...
    'computer', computer, ...
    'signalToolbox', toolbox_version('signal'), ...
    'statisticsToolbox', toolbox_version('stats'));

write_text_file(fullfile(outputFolder, 'audit_summary.json'), ...
    jsonencode(summary, 'PrettyPrint', true));

fprintf('Audited %d raw TXT files.\n', summary.fileCount);
fprintf('Analysis-ready files: %d; excluded files: %d.\n', ...
    summary.analysisReadyFileCount, summary.excludedFileCount);
fprintf('Participants: %d (documentation: %d); conditions: %d (documentation: %d).\n', ...
    summary.uniqueParticipantCount, summary.expectedParticipantCount, ...
    summary.uniqueEmotionCount, summary.expectedEmotionCount);
fprintf('Audit outputs: %s\n', outputFolder);
fprintf('Inferred sampling groups: %d participants at 128 Hz; %d at 256 Hz.\n', ...
    summary.inferred128ParticipantCount, summary.consistent256ParticipantCount);
fprintf('Sampling spectral diagnostic complete separation: %d.\n', ...
    summary.spectralSamplingValidation.completeSeparation);

if ~summary.canProceedToFeatureExtraction
    error('EEG:AuditBlocked', ...
        ['Dataset audit found unresolved structural problems. Inspect ' ...
         'data_audit.csv before feature extraction.']);
end
end

function provenance = upstream_provenance(datasetRoot)
provenance = struct();
provenance.url = 'https://github.com/huytungst/EEGEmotions-27';
provenance.license = 'CC BY-NC 4.0';
provenance.commit = 'unknown';

gitFolder = fullfile(datasetRoot, '.git');
if ~isfolder(gitFolder)
    return;
end
command = sprintf('git -C "%s" rev-parse HEAD', datasetRoot);
[status, output] = system(command);
if status == 0
    provenance.commit = strtrim(output);
end
end

function toolboxVersion = toolbox_version(shortName)
toolbox = ver(shortName);
if isempty(toolbox)
    toolboxVersion = 'missing';
else
    toolboxVersion = toolbox.Version;
end
end

function write_text_file(filePath, content)
fileId = fopen(filePath, 'w');
if fileId < 0
    error('EEG:OutputOpenFailed', 'Cannot open output file: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', content);
end

function participantSampling = attach_participant_metadata( ...
    participantSampling, participantInfoPath)
participantInfo = readtable(participantInfoPath);
[knownParticipant, location] = ismember( ...
    participantSampling.participant_id, participantInfo.Participant_ID);
if ~all(knownParticipant)
    error('EEG:ParticipantMetadataMismatch', ...
        'Sampling-rate table contains a participant absent from metadata.');
end

participantSampling.age_group = participantInfo.Age(location);
participantSampling.gender_code = participantInfo.Gender(location);
participantSampling.nation_code = participantInfo.Nation(location);
end

function output = summarize_sampling_demographics(participantSampling)
variableNames = ["nation_code", "gender_code", "age_group"];
output = table('Size', [0, 4], ...
    'VariableTypes', {'string', 'double', 'double', 'double'}, ...
    'VariableNames', {'demographic_variable', 'demographic_code', ...
    'sampling_rate_hz', 'participant_count'});

for variableIndex = 1:numel(variableNames)
    variableName = variableNames(variableIndex);
    values = participantSampling.(variableName);
    [group, demographicCode, samplingRateHz] = findgroups( ...
        values, participantSampling.inferred_sampling_rate_hz);
    participantCount = splitapply(@numel, values, group);
    demographicVariable = repmat(variableName, numel(demographicCode), 1);
    rows = table(demographicVariable, demographicCode, samplingRateHz, ...
        participantCount, 'VariableNames', output.Properties.VariableNames);
    output = [output; rows]; %#ok<AGROW>
end
output = sortrows(output, ...
    {'demographic_variable', 'demographic_code', 'sampling_rate_hz'});
end

