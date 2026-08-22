function plot_dummy_pipeline(out_dir)
%PLOT_DUMMY_PIPELINE Render raw vs. color-unmixed scatter plots of the
% synthetic line dataset (makeDummyLineLocs) for visual inspection.
% Writes raw_locs.png, unmixed_locs.png, and unmixing_ratio_gmm.png
% (the ratio-histogram/GMM-cutoff figure from get_cutoff_ratios) to out_dir.

if nargin < 1
    out_dir = fileparts(mfilename('fullpath'));
end

[locs, truth] = makeDummyLineLocs();
centered = locs;
centered.xnm = centered.xnm - min(centered.xnm);
centered.ynm = centered.ynm - min(centered.ynm);

p = struct();
p.assignfield1.Value = 0;
p.assignfield1.selection = 'intA1';
p.assignfield2.selection = 'intB1';
p.n_colors = 2;
p.specificity = 0.9;
p.include_edge_ratios = 0;
close all; % so gcf below is unambiguously the figure get_cutoff_ratios draws
[unmixed, ~] = apply_color_from_ratio(centered, [], p);

% get_cutoff_ratios (called inside apply_color_from_ratio) draws the
% ratio-histogram + GMM-cutoff figure and leaves it open as the current
% figure; grab it as-is (this is exactly what the real pipeline produces)
fig0 = gcf;
fig0.Position = [100 100 900 550];
exportgraphics(fig0, fullfile(out_dir, 'unmixing_ratio_gmm.png'), 'Resolution', 150);
close(fig0);

surfaceColor = [0xfc 0xfc 0xfb]/255;
inkColor     = [0x0b 0x0b 0x0b]/255;
mutedColor   = [0x89 0x87 0x81]/255;
gridColor    = [0xe1 0xe0 0xd9]/255;
rawColor     = [0x52 0x51 0x4e]/255;   % secondary ink - identity not yet known
color1       = [0x2a 0x78 0xd6]/255;   % categorical slot 1 (blue)
color2       = [0x1b 0xaf 0x7a]/255;   % categorical slot 2 (aqua)

% --- raw (pre-unmixing) ---
fig1 = figure('Color', surfaceColor, 'Position', [100 100 700 700], 'Visible', 'off');
ax1 = axes(fig1, 'Color', surfaceColor);
scatter(ax1, centered.xnm, centered.ynm, 6, rawColor, 'filled', 'MarkerFaceAlpha', 0.6);
axis(ax1, 'equal'); box(ax1, 'on');
xlabel(ax1, 'x (nm)', 'Color', inkColor);
ylabel(ax1, 'y (nm)', 'Color', inkColor);
title(ax1, 'Raw localizations (pre-unmixing)', 'Color', inkColor);
ax1.XColor = mutedColor; ax1.YColor = mutedColor;
ax1.GridColor = gridColor; grid(ax1, 'on');
exportgraphics(fig1, fullfile(out_dir, 'raw_locs.png'), 'Resolution', 150);
close(fig1);

% --- unmixed (color-assigned) ---
fig2 = figure('Color', surfaceColor, 'Position', [100 100 700 700], 'Visible', 'off');
ax2 = axes(fig2, 'Color', surfaceColor);
hold(ax2, 'on');
isCh1 = unmixed.channel == 1;
isCh2 = unmixed.channel == 2;
scatter(ax2, unmixed.xnm(isCh1), unmixed.ynm(isCh1), 6, color1, 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', 'Channel 1 (horizontal)');
scatter(ax2, unmixed.xnm(isCh2), unmixed.ynm(isCh2), 6, color2, 'filled', 'MarkerFaceAlpha', 0.6, 'DisplayName', 'Channel 2 (vertical)');
hold(ax2, 'off');
axis(ax2, 'equal'); box(ax2, 'on');
xlabel(ax2, 'x (nm)', 'Color', inkColor);
ylabel(ax2, 'y (nm)', 'Color', inkColor);
title(ax2, 'Unmixed localizations (color-assigned)', 'Color', inkColor);
ax2.XColor = mutedColor; ax2.YColor = mutedColor;
ax2.GridColor = gridColor; grid(ax2, 'on');
lgd = legend(ax2, 'Location', 'northoutside', 'Orientation', 'horizontal');
lgd.TextColor = inkColor; lgd.Color = surfaceColor; lgd.Box = 'off';
exportgraphics(fig2, fullfile(out_dir, 'unmixed_locs.png'), 'Resolution', 150);
close(fig2);

fprintf('Assignment accuracy: horizontal=%.1f%%, vertical=%.1f%%\n', ...
    100*mean(unmixed.channel(strcmp(truth.orientation,'horizontal')) == 1), ...
    100*mean(unmixed.channel(strcmp(truth.orientation,'vertical')) == 2));

end
