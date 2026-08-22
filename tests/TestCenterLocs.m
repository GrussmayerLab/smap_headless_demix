classdef TestCenterLocs < matlab.unittest.TestCase
    % Tests for pipeline/centerlocs.m

    methods (Test)
        function shiftsCoordinatesToOrigin(testCase)
            locs.xnm = [10 20 30];
            locs.ynm = [5 15 25];
            out = centerlocs(locs);
            testCase.verifyEqual(out.xnm, [0 10 20]);
            testCase.verifyEqual(out.ynm, [0 10 20]);
        end

        function handlesNegativeValues(testCase)
            locs.xpix = [-5 0 5];
            out = centerlocs(locs);
            testCase.verifyEqual(out.xpix, [0 5 10]);
        end

        function ignoresFieldsThatArentPresent(testCase)
            locs.xnm = [10 20];
            locs.otherfield = [1 2];
            out = centerlocs(locs);
            testCase.verifyFalse(isfield(out, 'ynm'));
            testCase.verifyEqual(out.otherfield, [1 2]);
        end

        function eachCoordinateFieldShiftsIndependently(testCase)
            locs.xnm = [100 200];
            locs.ynm = [1 2];
            out = centerlocs(locs);
            testCase.verifyEqual(out.xnm, [0 100]);
            testCase.verifyEqual(out.ynm, [0 1]);
        end
    end
end
