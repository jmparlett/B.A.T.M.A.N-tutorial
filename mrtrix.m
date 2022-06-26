M = readmatrix('/home/jp/Documents/drexel_docs/csdocs/t680/batman/project/DWI/hcpmmp1.csv');
% disp(M)
% image(M)

% hmo = HeatMap(M);
% hmo.Annotate = true;k
% hmo.ColorbarVisible = 'on';
h = heatmap(M);
h.GridVisible = 'off';
h.ColorLimits = [0 0.1];
% h.Colormap = hsv;
h.Colormap = turbo;
% h.CellLabelColor = 'none';
% h.CellLabelFormat='';
% image(h)
Ax = gca;
Ax.XDisplayLabels = nan(size(Ax.XDisplayData));
Ax.YDisplayLabels = nan(size(Ax.YDisplayData));
view(h)