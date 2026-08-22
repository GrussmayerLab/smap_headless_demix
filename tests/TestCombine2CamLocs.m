classdef TestCombine2CamLocs < matlab.unittest.TestCase
    % Tests for pipeline/combine_2cam_locs.m

    methods (Test)
        function shiftsOnlyCameraB(testCase)
            locA.xnm = [10; 20];
            locA.ynm = [1; 2];
            locB.xnm = [10; 20];
            locB.ynm = [3; 4];

            out = combine_2cam_locs(locA, locB, 1000);

            testCase.verifyEqual(out.xnm, [10; 20; 1010; 1020]);
            testCase.verifyEqual(out.ynm, [1; 2; 3; 4]);
        end

        function concatenatesAllFieldsInOrder(testCase)
            locA.xnm = [1; 2];
            locA.frame = [1; 2];
            locB.xnm = [3; 4];
            locB.frame = [1; 2];

            out = combine_2cam_locs(locA, locB, 0);

            testCase.verifyEqual(out.frame, [1; 2; 1; 2]);
            testCase.verifyEqual(numel(out.xnm), 4);
        end

        function doesNotMutateInputs(testCase)
            locA.xnm = [1; 2];
            locB.xnm = [3; 4];

            combine_2cam_locs(locA, locB, 500);

            testCase.verifyEqual(locB.xnm, [3; 4]);
        end

        function zeroOffsetIsPlainConcatenation(testCase)
            locA.xnm = [1; 2];
            locB.xnm = [3; 4];

            out = combine_2cam_locs(locA, locB, 0);

            testCase.verifyEqual(out.xnm, [1; 2; 3; 4]);
        end
    end
end
