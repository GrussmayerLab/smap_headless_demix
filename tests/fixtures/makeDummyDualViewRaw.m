function [raw, W] = makeDummyDualViewRaw(varargin)
%MAKEDUMMYDUALVIEWRAW Synthetic single-camera dual-view (spectral-split)
% raw localization list: N molecules, each imaged on both the
% "reference" and "target" halves of one combined frame (mimicking a
% dichroic-split sensor before registration), with independent
% per-channel localization noise and a bimodal intA1/intB1 ratio (for
% exercising color classification). Suitable as input to
% register_2channel via interfaces.LocalizationData - see
% TestRegister2ChannelEndToEnd.m for the full required p/LocData setup.
%
% [raw, roiWidthNm] = makeDummyDualViewRaw('Name', Value, ...)
%
% Name-Value options:
%   N          number of molecules (default 6000 - the FFT
%              cross-correlation inside register_2channel needs a dense
%              enough point cloud to find a clean, non-edge peak)
%   ROIWidth   single-ROI width in nm (default 10000)
%   FOVy       frame height in nm (default 20000)
%   Jitter     per-channel positional noise std, nm (default 15 - a
%              noiseless duplicate makes the correlation peak too
%              narrow for the sub-pixel Gaussian fit to converge)
%   Seed       RNG seed (default 1)
%
% Notes on constraints discovered while getting register_2channel to run
% headlessly (see fixed test for the full setup):
%   - raw.frame must be globally sorted ascending: matchlocsall does a
%     sliding two-pointer scan assuming sorted input, not a real search.
%   - raw.channel must exist (zeros = unassigned): apply_transform_locs
%     copies it unconditionally before color assignment ever runs.
%   - molecule positions must stay clear of the ROI-derived
%     reference/target split boundary (roughly ROIWidth, offset by a
%     "-20 px" margin baked into the real pipeline's ROI setup) or
%     points leak across into the wrong side.

p = inputParser;
addParameter(p, 'N', 6000);
addParameter(p, 'ROIWidth', 10000);
addParameter(p, 'FOVy', 20000);
addParameter(p, 'Jitter', 15);
addParameter(p, 'Seed', 1);
parse(p, varargin{:});
opt = p.Results;

rng(opt.Seed);
W = opt.ROIWidth;
N = opt.N;

merged.xnm = 1000 + (W-3000)*rand(N,1);
merged.ynm = 500 + (opt.FOVy-1000)*rand(N,1);

ratio = 0.08 + 0.02*randn(N,1);
ratio(1:2:end) = 0.55 + 0.10*randn(numel(1:2:N),1);
ratio = min(max(ratio, 0.05), 0.95);
phot = 3000 + 500*randn(N,1);
merged.intA1 = ratio.*phot;
merged.intB1 = (1-ratio).*phot;
merged.bg = max(5, 20+5*randn(N,1));
merged.PSFxnm = max(60, 120+10*randn(N,1));
merged.PSFynm = max(60, 120+10*randn(N,1));
merged.locprecnm = 5 + 25*rand(N,1);
merged.frame = sort(double(randi([1 20000], N, 1)));
merged.filenumber = ones(N,1);
merged.channel = zeros(N,1,'int16');

target.xnm = merged.xnm + opt.Jitter*randn(N,1);
target.ynm = merged.ynm + opt.Jitter*randn(N,1);
target.phot = double(merged.intB1);

ref.xnm = merged.xnm + W + opt.Jitter*randn(N,1);
ref.ynm = merged.ynm + opt.Jitter*randn(N,1);
ref.phot = double(merged.intA1);

fn_common = {'bg','PSFxnm','PSFynm','locprecnm','frame','filenumber','channel'};
for k = 1:numel(fn_common)
    target.(fn_common{k}) = merged.(fn_common{k});
    ref.(fn_common{k}) = merged.(fn_common{k});
end

raw = struct();
fn = fieldnames(target);
for k = 1:numel(fn)
    raw.(fn{k}) = cat(1, ref.(fn{k}), target.(fn{k}));
end
[~, frameorder] = sort(raw.frame);
for k = 1:numel(fn)
    raw.(fn{k}) = raw.(fn{k})(frameorder);
end

end
