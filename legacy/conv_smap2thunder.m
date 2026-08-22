% load .mat file, convert to thunderstorm (.csv) format with proper headers
% should be importable to sharpvisu

[file,location] = uigetfile();
% get descriptors
[basepath, basefilename, ext] = fileparts(fullfile(location, file));
%load to workspace
f = load(fullfile(location, file));
% get locs 
l = saveloc.loc;
%initialise 
out = table;
%id for each loc
out.id = linspace(1, numel(l.frame), numel(l.frame));
% frame numbers
out.frame = l.frame.';
%xy pos
out.('x [nm]') = l.xnm.';
out.('y [nm]') = l.ynm.';
% znm if 3d set
if isfield(l,'znm')
    out.('z [nm]') = l.znm.';
end 

% rest
out.('sigma [nm]') = l.PSFxnm.';
out.('intensity [photon]') = l.phot.';  
out.('offset [photon]') = l.photerr.';
out.('bkgstd [photon]') =  l.bg.';
out.('uncertainty [nm]') = l.locprecnm.';

%write to same folder as csv
writetable(out, fullfile(basepath, [basefilename '.csv']))

