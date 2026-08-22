function [locs, p] = apply_color_from_ratio(locs,ratios, p)
%applz color channels from ratios
% color channels are assigned as integers in order of given ratios
% ratios need to be given as (min,max) intervals

if p.assignfield1.Value==1%run from WF
    p.assignfield1.selection='intB1';
    p.assignfield2.selection='intA1';
end

field1=p.assignfield1.selection;
field2=p.assignfield2.selection;

ratio_locs = locs.(field1)./(locs.(field2)+locs.(field1));
locs.channel = zeros(size(ratio_locs, 1), 1, "int16");
locs.ratio = ratio_locs;

%% add multi-gaussian fit to define ratio boundaries
%p.specificity = 0.75;
%p.n_colors = 2;

% filter for non-assigned values (0,1)
filtered_ratio_locs = ratio_locs((ratio_locs>0) & (ratio_locs<1));
%filtered_ratio_locs = ratio_locs;

% get cutoffs
ratios = get_cutoff_ratios(filtered_ratio_locs, p);
p.photon_ratios = ratios;

%include edge ratios to ratios
if p.include_edge_ratios

end 

%% assign color to each localisation


for r=1:length(ratio_locs)
    for c=1:length(ratios) 
        range = ratios(c,[1 2]);
       if ratio_locs(r) > range(1) && ratio_locs(r) < range(2)
           locs.channel(r) = c;
       end 
    end 
end 
end