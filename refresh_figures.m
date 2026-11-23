function refresh_figures()
%REFRESH_FIGURES Recreate cached result figures without refitting models.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot, 'config'));
addpath(fullfile(projectRoot, 'src'));
cfg = default_config();
folder = fullfile(cfg.paths.outputs, 'modeling');

confusionTable = readtable(fullfile(folder, 'confusion_row_normalized.csv'));
confusion = confusionTable{:, 2:end};
confusionMaximum = max(confusion, [], 'all');
figureHandle = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 760, 680]);
imagesc(confusion, [0, confusionMaximum]);
axis square;
colormap(figureHandle, parula(256));
colorbar;
xlabel('Predicted condition ID');
ylabel('True condition ID');
title('Participant-held-out OOF confusion matrix (row-normalized)');
xticks(1:27); yticks(1:27);
exportgraphics(figureHandle, fullfile(folder, 'confusion_matrix.png'), ...
    'Resolution', 180);
close(figureHandle);

ablation = readtable(fullfile(folder, 'band_ablation.csv'), 'TextType', 'string');
ablationFolds = readtable( ...
    fullfile(folder, 'band_ablation_fold_metrics.csv'), 'TextType', 'string');
figureHandle = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 800, 520]);
rows = 2:height(ablation);
bar(1:numel(rows), ablation.delta_macro_f1(rows), ...
    'FaceColor', [0.25, 0.55, 0.72]);
hold on;
for bandIndex = 1:numel(rows)
    bandName = ablation.removedBand(rows(bandIndex));
    foldRows = ablationFolds.removed_band == bandName;
    scatter(repmat(bandIndex, sum(foldRows), 1), ...
        ablationFolds.delta_macro_f1(foldRows), 32, ...
        'filled', 'MarkerFaceColor', [0.12, 0.20, 0.30]);
end
yline(0, '--k');
xticks(1:numel(rows));
xticklabels(ablation.removedBand(rows));
set(gca, 'TickLabelInterpreter', 'none');
xlabel('Removed band (all channels)');
ylabel('\Delta macro-F1 vs all bands');
title('Paired leave-one-band-out predictive contribution');
grid on;
box off;
exportgraphics(figureHandle, fullfile(folder, 'band_ablation.png'), ...
    'Resolution', 180);
close(figureHandle);

permutation = readtable(fullfile(folder, 'structured_permutation_baseline.csv'));
metrics = readtable(fullfile(folder, 'metrics.csv'), 'TextType', 'string');
observed = metrics.macro_f1(metrics.model == "fourier_linear_ecoc");
majority = metrics.macro_f1(metrics.model == "train_fold_majority");
figureHandle = figure('Visible', 'off', 'Color', 'white', ...
    'Position', [100, 100, 760, 500]);
histogram(permutation.macro_f1, 20, ...
    'FaceColor', [0.55, 0.65, 0.72], 'EdgeColor', 'white');
hold on;
xline(observed, '-', 'Observed', 'Color', [0.80, 0.20, 0.15], 'LineWidth', 2);
xline(majority, '--', 'Majority', ...
    'Color', [0.20, 0.20, 0.20], 'LineWidth', 1.3);
xlabel('OOF macro-F1');
ylabel('Permutation count');
title('Within-participant structured permutation baseline');
box off;
exportgraphics(figureHandle, fullfile(folder, 'permutation_baseline.png'), ...
    'Resolution', 180);
close(figureHandle);

manifestPath = fullfile(folder, 'run_manifest.json');
manifest = jsondecode(fileread(manifestPath));
updatedNames = ["confusion_matrix.png", "band_ablation.png", ...
    "permutation_baseline.png"];
for nameIndex = 1:numel(updatedNames)
    outputIndex = find(string({manifest.outputs.outputName}) == updatedNames(nameIndex), 1);
    if isempty(outputIndex)
        error('EEG:ManifestOutputMissing', ...
            'Output is absent from run manifest: %s', updatedNames(nameIndex));
    end
    manifest.outputs(outputIndex).outputSha256 = char(sha256_file(string( ...
        fullfile(folder, updatedNames(nameIndex)))));
end
write_figure_manifest(manifestPath, manifest);
fprintf('Refreshed cached modeling figures and manifest hashes.\n');
end

function write_figure_manifest(filePath, manifest)
fileId = fopen(filePath, 'w');
if fileId < 0
    error('EEG:OutputOpenFailed', 'Cannot open output file: %s', filePath);
end
closeFile = onCleanup(@() fclose(fileId));
fprintf(fileId, '%s\n', jsonencode(manifest, 'PrettyPrint', true));
end

