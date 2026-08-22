function [locs, truth] = makeDummyLineLocs(varargin)
%MAKEDUMMYLINELOCS Synthetic two-color localization data arranged in
% horizontal and vertical lines, mimicking a ratiometric cytoskeleton
% (filament) dataset, for exercising the tools/pipeline functions without
% real acquired data.
%
% [locs, truth] = makeDummyLineLocs('Name', Value, ...)
%
% Fields of locs match the layout of saveloc.loc in
% tools/data/P1_A1_tub647_..._sml.mat: xnm, ynm, phot, bg, PSFxnm,
% PSFynm, locprecnm, frame, filenumber, channel, intA1, intB1.
%
% truth.orientation ('horizontal'/'vertical') and truth.lineindex give
% the ground-truth line each localization belongs to, for asserting
% pipeline outputs (e.g. color assignment) against a known layout.
%
% Name-Value options:
%   NPerLine       localizations per line (default 300)
%   FOV            field of view in nm (default 20000)
%   HorizontalYs   y-positions (nm) of horizontal lines (default [3000 9000 15000])
%   VerticalXs     x-positions (nm) of vertical lines (default [5000 10000 15000])
%   Seed           RNG seed for reproducibility (default 1)

p = inputParser;
addParameter(p, 'NPerLine', 300);
addParameter(p, 'FOV', 20000);
addParameter(p, 'HorizontalYs', [3000 9000 15000]);
addParameter(p, 'VerticalXs', [5000 10000 15000]);
addParameter(p, 'Seed', 1);
parse(p, varargin{:});
opt = p.Results;

rng(opt.Seed);

xnm = [];
ynm = [];
orientation = {};
lineidx = [];

% horizontal lines -> low-ratio "color 1" population
for k = 1:numel(opt.HorizontalYs)
    n = opt.NPerLine;
    x = linspace(500, opt.FOV-500, n)';
    y = repmat(opt.HorizontalYs(k), n, 1);
    xnm = [xnm; x]; %#ok<AGROW>
    ynm = [ynm; y]; %#ok<AGROW>
    orientation = [orientation; repmat({'horizontal'}, n, 1)]; %#ok<AGROW>
    lineidx = [lineidx; repmat(k, n, 1)]; %#ok<AGROW>
end

% vertical lines -> high-ratio "color 2" population
for k = 1:numel(opt.VerticalXs)
    n = opt.NPerLine;
    y = linspace(500, opt.FOV-500, n)';
    x = repmat(opt.VerticalXs(k), n, 1);
    xnm = [xnm; x]; %#ok<AGROW>
    ynm = [ynm; y]; %#ok<AGROW>
    orientation = [orientation; repmat({'vertical'}, n, 1)]; %#ok<AGROW>
    lineidx = [lineidx; repmat(k, n, 1)]; %#ok<AGROW>
end

N = numel(xnm);
isHoriz = strcmp(orientation, 'horizontal');

% per-localization precision, then jitter positions isotropically by it
locprecnm = 5 + 25*rand(N, 1);
xnm = xnm + locprecnm .* randn(N, 1);
ynm = ynm + locprecnm .* randn(N, 1);

% two clearly-separated ratio populations, within the [0.01 0.13] /
% [0.17 1] bands used as p.photon_ratios in the real entry scripts
ratio = zeros(N, 1);
ratio(isHoriz)  = 0.08 + 0.02*randn(sum(isHoriz), 1);
ratio(~isHoriz) = 0.55 + 0.10*randn(sum(~isHoriz), 1);
ratio = min(max(ratio, 0.001), 0.999);

phot = 3000 + 500*randn(N, 1);
phot(phot < 200) = 200;
intA1 = single(ratio .* phot);
intB1 = single((1-ratio) .* phot);

bg = single(max(5, 20 + 5*randn(N, 1)));
PSFxnm = single(max(60, 120 + 10*randn(N, 1)));
PSFynm = single(max(60, 120 + 10*randn(N, 1)));
frame = double(randi([1 5000], N, 1));
filenumber = single(ones(N, 1));
channel = int16(zeros(N, 1));
channel(isHoriz) = 1;
channel(~isHoriz) = 2;

locs.xnm = single(xnm);
locs.ynm = single(ynm);
locs.phot = single(phot);
locs.bg = bg;
locs.PSFxnm = PSFxnm;
locs.PSFynm = PSFynm;
locs.locprecnm = single(locprecnm);
locs.frame = frame;
locs.filenumber = filenumber;
locs.channel = channel;
locs.intA1 = intA1;
locs.intB1 = intB1;

truth.orientation = orientation;
truth.lineindex = lineidx;
truth.channel = channel;

end
