classdef TestTwoCamRoundTrip < matlab.unittest.TestCase
    % Splits the synthetic filament dataset into two single-camera loc
    % structs (as if it had been acquired on two separate synchronized
    % cameras instead of one split sensor), then verifies
    % combine_2cam_locs.m reconstructs the original combined layout -
    % the same offset+concatenate step process_multiC_locs.m performs
    % in 'twocam' modality.

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
        function reconstructsOriginalCoordinates(testCase)
            locs = makeDummyLineLocs();
            splitX = 10000; % nm, splits the 20000 nm FOV in half

            [locA, locB] = splitToTwoCamLocs(locs, splitX);
            recombined = combine_2cam_locs(locA, locB, splitX);

            testCase.verifyEqual(numel(recombined.xnm), numel(locs.xnm));
            testCase.verifyEqual(sort(double(recombined.xnm)), sort(double(locs.xnm)), 'AbsTol', 1e-3);
            testCase.verifyEqual(sort(double(recombined.ynm)), sort(double(locs.ynm)), 'AbsTol', 1e-3);
        end

        function cameraBLocalCoordinatesStartNearZero(testCase)
            locs = makeDummyLineLocs();
            splitX = 10000;

            [~, locB] = splitToTwoCamLocs(locs, splitX);

            % camera B's own points should mostly sit close to its local
            % origin, not still carry the shared-canvas offset
            testCase.verifyLessThan(min(double(locB.xnm)), 500);
        end
    end
end
