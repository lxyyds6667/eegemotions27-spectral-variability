function plot_fixed_window_control(scores, destination)
%PLOT_FIXED_WINDOW_CONTROL Show matched EEG scores for each fold and pooled trials.
methods = ["whole_trial","full_fifths","centered_3s"];
scopes = ["fold_"+string(1:5),"all"];
values = zeros(numel(scopes), numel(methods));
for s = 1:numel(scopes)
    for m = 1:numel(methods)
        rows = scores.scope == scopes(s) & scores.method == methods(m);
        values(s,m) = scores.macro_f1(rows);
    end
end

fig = figure('Visible','off','Color','white','Position',[100 100 780 425]);
cleanup = onCleanup(@() close(fig));
ax = axes(fig, 'Position',[0.13 0.22 0.82 0.64], 'Color','white');
hold(ax,'on');
columns = 1:3;
foldLines = plot(ax, columns, values(1:5,:)', '-o', ...
    'Color',[0.58 0.65 0.69], 'MarkerSize',4, 'LineWidth',1.2);
pooled = plot(ax, columns, values(end,:), '-o', 'Color',[0.04 0.30 0.43], ...
    'MarkerFaceColor',[0.04 0.30 0.43], 'MarkerSize',8, 'LineWidth',3);
for m = columns
    text(ax, m, values(end,m) + 0.004, sprintf('%.4f',values(end,m)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'Color',[0.04 0.24 0.34],'BackgroundColor','white','Margin',1, ...
        'FontSize',11,'FontWeight','bold');
end
set(ax, 'XTick',columns, 'XTickLabel',{'Whole-trial power', ...
    'Power + full-fifth SD','Power + centered 3-s SD'}, ...
    'FontSize',11, 'XColor',[0.16 0.20 0.23], 'YColor',[0.16 0.20 0.23]);
xlim(ax,[0.68 3.32]);
ylim(ax,[0, ceil((max(values,[],'all') + 0.012)*100)/100]);
ax.YGrid = 'on';
ax.GridAlpha = 0.16;
ylabel(ax,'Macro-F1');
title(ax,'Equalizing the data used for each spectral estimate', 'Color',[0.1 0.15 0.18]);
key = legend(ax, [pooled foldLines(1)], ...
    {'All held-out predictions pooled','Individual participant folds (5)'}, ...
    'Orientation','horizontal','Location','southoutside','Box','off');
key.TextColor = [0.16 0.20 0.23];
exportgraphics(fig,destination,'Resolution',160,'BackgroundColor','white', ...
    'Units','pixels','Padding',16);
end
