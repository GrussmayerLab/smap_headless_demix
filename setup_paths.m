function smap_path = setup_paths()
%SETUP_PATHS Add all tools/ subfolders and the vendored SMAP install to the MATLAB path.
% Call this from any entry-point script instead of hardcoding addpath lines.
% Returns the path to the vendored SMAP folder (for p.smappath bookkeeping).

tools_dir = fileparts(mfilename('fullpath'));

smap_path = fullfile(tools_dir, 'SMAP');
addpath(genpath(smap_path));

addpath(fullfile(tools_dir, 'pipeline'));
addpath(fullfile(tools_dir, 'fitting'));
addpath(fullfile(tools_dir, 'analysis'));
addpath(fullfile(tools_dir, 'utils'));
addpath(fullfile(tools_dir, 'external'));
addpath(fullfile(tools_dir, 'config'));

bioformats_candidates = {'E:\Program Files\bfmatlab', 'E:\GitHub\bfmatlab'};
bioformats_found = false;
for k = 1:numel(bioformats_candidates)
    if isfolder(bioformats_candidates{k})
        addpath(bioformats_candidates{k});
        bioformats_found = true;
        break
    end
end
if ~bioformats_found
    warning('setup_paths:bioformatsNotFound', ...
        'Bio-Formats not found in any known location; add it to the path manually if needed.');
end

end
