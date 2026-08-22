function locs = centerlocs(locs)
fn = {'xnm', 'ynm', 'xpix', 'ypix'};
for f=1:size(fn, 2)
    if isfield(locs, fn{f})
        locs.(fn{f}) = locs.(fn{f})- min(locs.(fn{f}), [], 'all');
    end 
end 

end