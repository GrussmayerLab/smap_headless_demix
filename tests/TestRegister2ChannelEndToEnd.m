classdef TestRegister2ChannelEndToEnd < matlab.unittest.TestCase
    % Drives the real, unmodified pipeline/register_2channel.m end to
    % end (registration -> cross-channel matching -> GMM color
    % classification -> drift correction -> save -> summary stats) on
    % synthetic dual-view data, with no SMAP GUI open. register_2channel
    % only needs an invisible-figure-backed uitabgroup for its internal
    % plotting calls plus correctly populated LocData.files.file(1).info.

    properties
        FixturesPath
        ScratchDir
    end

    methods (TestClassSetup)
        function addFixturesToPath(testCase)
            testCase.FixturesPath = fullfile(fileparts(mfilename('fullpath')), 'fixtures');
            addpath(testCase.FixturesPath);
        end
    end

    methods (TestMethodSetup)
        function makeScratchDir(testCase)
            testCase.ScratchDir = fullfile(tempdir, ['register2channel_test_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
            mkdir(testCase.ScratchDir);
            testCase.addTeardown(@() rmdir(testCase.ScratchDir, 's'));
        end
    end

    methods (Test)
        function runsHeadlesslyAndClassifiesColor(testCase)
            [raw, W] = makeDummyDualViewRaw();
            pixelsize = 108;

            p = struct();
            p.processedFolder = testCase.ScratchDir;
            p.mergedfilefolder = testCase.ScratchDir;
            p.root_folder = testCase.ScratchDir;
            p.basefilename = 'dummy_dualview';
            p.pixelsize = pixelsize;
            p.currentfileinfo.Width = 2*W/pixelsize;
            p.currentfileinfo.Height = 20000/pixelsize;
            p.currentfileinfo.cam_pixelsize_um = pixelsize/1000;
            p.allfiles = false;
            p.currentfileinfo.roi = [0, 0, p.currentfileinfo.Width-20, p.currentfileinfo.Height];
            p.targetmirror.selection = 'none';
            p.transform.selection = 'affine';
            p.targetpos.selection = 'left';
            p.transformparam = 3;
            p.isz = false;
            p.useT = false;
            p.uselayers = false;

            param.pixelsizenm = 40;
            param.maxshift_corr = 100000; % nFFT-capped in practice, but must clear the sparse-data edge case
            param.maxlocsused = numel(raw.frame);
            param.maxshift_match = 300;
            param.initial_mag = 1;
            param.initialshiftx = W;
            param.initialshifty = 0;
            p.register_parameters = param;

            p.assignfield1.Value = 0;
            p.assignfield1.selection = 'intA1';
            p.assignfield2.selection = 'intB1';
            p.n_colors = 2;
            p.specificity = 0.9;
            p.include_edge_ratios = 0;
            p.photon_ratios = [0.01 0.13; 0.17 1];

            p.correctz = false;
            p.correctxy = true;
            p.drift_mirror2c.Value = 1;
            p.makesummary = true;
            p.dataselect.Value = 1;

            fig_gui = figure('Visible', 'off');
            testCase.addTeardown(@() close(fig_gui));
            p.resultstabgroup = uitabgroup(fig_gui);

            guipar.sr_pos.content = [p.currentfileinfo.Width*pixelsize/2, p.currentfileinfo.Height*pixelsize/2];
            guipar.sr_pos.isGuiPar = false;
            guipar.sr_size.content = [p.currentfileinfo.Width*pixelsize, p.currentfileinfo.Height*pixelsize];
            guipar.sr_size.isGuiPar = false;

            LocData = interfaces.LocalizationData;
            LocData.addLocData(raw);
            LocData.P.par = guipar;
            LocData.files.file(1).number = 1;
            LocData.files.file(1).info.roi = [0 0 p.currentfileinfo.Width p.currentfileinfo.Height];
            LocData.files.file(1).info.cam_pixelsize_um = [pixelsize/1000 pixelsize/1000];
            LocData.files.filenumberEnd = 1;

            transformed = register_2channel(LocData, p);

            testCase.verifyGreaterThan(numel(transformed.loc.xnm), 0.5*numel(raw.xnm)/2);
            testCase.verifyEqual(numel(transformed.loc.channel), numel(transformed.loc.xnm));
            testCase.verifyTrue(any(transformed.loc.channel == 1));
            testCase.verifyTrue(any(transformed.loc.channel == 2));
        end
    end
end
