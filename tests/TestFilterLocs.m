classdef TestFilterLocs < matlab.unittest.TestCase
    % Tests for pipeline/filterlocs.m

    methods (Test)
        function noChecksReturnsAllLocs(testCase)
            locs = baseLocs();
            p = struct();
            out = filterlocs(locs, p);
            testCase.verifyEqual(out.frame, locs.frame);
            testCase.verifyEqual(out.xnm, locs.xnm);
        end

        function filtersByLocPrecRange(testCase)
            locs = baseLocs();
            p = struct();
            p.check_locprec = true;
            p.val_locprec = [0 20];
            out = filterlocs(locs, p);
            testCase.verifyEqual(out.locprecnm, locs.locprecnm(locs.locprecnm <= 20));
        end

        function filtersByXAndYBounds(testCase)
            locs = baseLocs();
            p = struct();
            p.check_xnm = true;
            p.val_xnm = [0 25];
            p.check_ynm = true;
            p.val_ynm = [0 25];
            out = filterlocs(locs, p);
            testCase.verifyEqual(out.xnm, [0;10;20]);
            testCase.verifyEqual(out.ynm, [0;10;20]);
        end

        function removesLocsWithNaNInAnyField(testCase)
            locs = baseLocs();
            locs.xnm(3) = NaN;
            p = struct();
            out = filterlocs(locs, p);
            testCase.verifyEqual(numel(out.frame), numel(locs.frame) - 1);
            testCase.verifyFalse(any(isnan(out.xnm)));
        end

        % Regression test: check_phot used to be gated on isfield(locs,
        % 'check_phot') instead of isfield(p, 'check_phot'), so it never
        % activated even when p.check_phot was true.
        function photFilterActuallyActivates(testCase)
            locs = baseLocs();
            locs.phot = [-100 500 1000 2000 3000]';
            p = struct();
            p.check_phot = true;
            p.val_phot = [0 1e7];
            out = filterlocs(locs, p);
            testCase.verifyEqual(numel(out.frame), numel(locs.frame) - 1);
            testCase.verifyTrue(all(out.phot >= 0));
        end

        % Regression test: same isfield(locs, ...) typo existed for check_bg.
        function bgFilterActuallyActivates(testCase)
            locs = baseLocs();
            locs.bg = [1 2 3 4 100]';
            p = struct();
            p.check_bg = true;
            p.val_bg = [0 25];
            out = filterlocs(locs, p);
            testCase.verifyEqual(numel(out.frame), numel(locs.frame) - 1);
            testCase.verifyTrue(all(out.bg <= 25));
        end
    end
end

function locs = baseLocs()
locs.frame = (1:5)';
locs.locprecnm = [5 10 15 25 30]';
locs.xnm = [0 10 20 30 40]';
locs.ynm = [0 10 20 30 40]';
end
