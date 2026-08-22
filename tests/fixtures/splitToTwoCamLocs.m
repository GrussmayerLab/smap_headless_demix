function [locA, locB] = splitToTwoCamLocs(locs, splitX)
%SPLITTOTWOCAMLOCS Split one combined loc struct into two single-camera
% loc structs at splitX (nm), the inverse of combine_2cam_locs: locA
% keeps points with xnm < splitX unchanged, locB keeps points with
% xnm >= splitX with xnm rebased to start at its own camera's origin
% (xnm - splitX). Used to build 2-camera test fixtures out of the
% existing single-canvas dummy data generators.

fn = fieldnames(locs);
isA = locs.xnm < splitX;

locA = struct();
locB = struct();
for k = 1:numel(fn)
    locA.(fn{k}) = locs.(fn{k})(isA);
    locB.(fn{k}) = locs.(fn{k})(~isA);
end
locB.xnm = locB.xnm - splitX;

end
