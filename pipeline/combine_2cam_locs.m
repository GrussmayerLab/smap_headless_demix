function locs = combine_2cam_locs(locA, locB, offsetX)
%COMBINE_2CAM_LOCS Concatenate two single-camera localization lists into
% one combined list laid out like the single-camera dual-view case:
% locA keeps its native coordinates, locB is shifted by offsetX
% (typically camera A's frame width in nm) so both populations coexist
% side-by-side in one synthetic canvas, matching the layout that
% register_2channel/RegisterLocs2 already expect (p.targetpos.selection
% ='left', reference on one side, target needing the transform on the
% other).
%
% locA and locB must have identical field names.

fn = fieldnames(locA);
locs = struct();
locBshifted = locB;
locBshifted.xnm = locB.xnm + offsetX;
for k = 1:numel(fn)
    locs.(fn{k}) = cat(1, locA.(fn{k}), locBshifted.(fn{k}));
end

end
