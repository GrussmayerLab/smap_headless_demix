classdef TestDummyLineLocsPipeline < matlab.unittest.TestCase
    % Runs the tools/pipeline functions on synthetic horizontal/vertical
    % line data (fixtures/makeDummyLineLocs.m) and checks the outputs
    % against the known ground-truth layout.

    properties
        FixturesPath
    end

    methods (TestClassSetup)
        function addFixturesToPath(testCase)
            testCase.FixturesPath = fullfile(fileparts(mfilename('fullpath')), 'fixtures');
            addpath(testCase.FixturesPath);
        end
    end

    methods (Test)
        function generatedLinesMatchTargetPositions(testCase)
            [locs, truth] = makeDummyLineLocs();
            isHoriz = strcmp(truth.orientation, 'horizontal');

            % horizontal-line points should sit close to one of the
            % target Ys (within a wide multiple of locprec), same for
            % vertical-line points and their target Xs
            targetYs = [3000 9000 15000];
            targetXs = [5000 10000 15000];

            yDeviation = min(abs(double(locs.ynm(isHoriz)) - targetYs), [], 2);
            testCase.verifyLessThan(yDeviation, 10*double(locs.locprecnm(isHoriz)));

            xDeviation = min(abs(double(locs.xnm(~isHoriz)) - targetXs), [], 2);
            testCase.verifyLessThan(xDeviation, 10*double(locs.locprecnm(~isHoriz)));
        end

        function centerAndFilterPreserveCleanData(testCase)
            locs = makeDummyLineLocs();

            centered = centerlocs(locs);
            testCase.verifyEqual(min(centered.xnm, [], 'all'), single(0));
            testCase.verifyEqual(min(centered.ynm, [], 'all'), single(0));

            p = struct();
            p.check_locprec = true;  p.val_locprec = [0 50];
            p.check_phot = true;     p.val_phot = [0 1e7];
            p.check_xnm = true;      p.val_xnm = [0 max(centered.xnm, [], 'all')];
            p.check_ynm = true;      p.val_ynm = [0 max(centered.ynm, [], 'all')];

            filtered = filterlocs(centered, p);
            % synthetic data is clean/in-range, so filtering should not
            % drop any localizations
            testCase.verifyEqual(numel(filtered.frame), numel(locs.frame));
        end

        function colorAssignmentRecoversLineOrientation(testCase)
            [locs, truth] = makeDummyLineLocs();

            p = struct();
            p.assignfield1.Value = 0;
            p.assignfield1.selection = 'intA1';
            p.assignfield2.selection = 'intB1';
            p.n_colors = 2;
            p.specificity = 0.9;
            p.include_edge_ratios = 0;

            [out, ~] = apply_color_from_ratio(locs, [], p);

            % horizontal lines were generated with a low intA1/(intA1+intB1)
            % ratio, vertical lines with a high one, so the two GMM
            % components should line up with the two orientations
            isHoriz = strcmp(truth.orientation, 'horizontal');
            horizChannels = out.channel(isHoriz);
            vertChannels = out.channel(~isHoriz);

            % each orientation should map overwhelmingly onto a single,
            % distinct assigned channel
            testCase.verifyGreaterThan(mean(horizChannels == mode(horizChannels)), 0.95);
            testCase.verifyGreaterThan(mean(vertChannels == mode(vertChannels)), 0.95);
            testCase.verifyNotEqual(mode(horizChannels), mode(vertChannels));
        end
    end
end
