function plot_temporal_comparison()
% Show the paired held-out scores for the five fixed participant folds.
folder = fullfile(fileparts(mfilename('fullpath')),'outputs','temporal_extension');
scores = readtable(fullfile(folder,'paired_metrics.csv'),'TextType','string');
folds = scores(startsWith(scores.scope,"fold_"),:);
fig = figure('Visible','off','Color','white','Position',[100 100 700 400]);
cleanup = onCleanup(@() close(fig));
ax = axes(fig);
hold(ax,'on');
y = (1:height(folds))';
for k = y'
    plot(ax,[folds.baseline_f1(k) folds.extended_f1(k)],[k k], ...
        'Color',[0.74 0.77 0.79],'LineWidth',2);
end
a = scatter(ax,folds.baseline_f1,y,65,[0.23 0.35 0.50],'o','filled');
b = scatter(ax,folds.extended_f1,y,72,[0.76 0.30 0.08],'d','filled');
set(ax,'YDir','reverse','YTick',y,'YTickLabel',compose("Fold %d",y),'FontSize',12);
ylim(ax,[0.5 height(folds)+0.5]);
xlim(ax,[0 ceil(100*max([folds.baseline_f1;folds.extended_f1]))/100+0.01]);
xlabel(ax,'Held-out macro-F1');
title(ax,'Adding within-trial spectral variability');
ax.XGrid = 'on';
legend(ax,[a b],{'Whole-trial power','Power + variability'}, ...
    'Location','southoutside','Orientation','horizontal','Box','off');
exportgraphics(fig,fullfile(folder,'paired_folds.png'),'Resolution',160);
end
