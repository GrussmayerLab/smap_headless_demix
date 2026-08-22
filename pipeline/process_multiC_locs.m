%% SMAP based fitting, spectral demixing on one or two cameras
clear;clc;close all;
%parameters:
% p.imagefile: fiename of data (char);
% p.calfile: filename of calibration data (char);
% p.offset=ADU offset of data;
% p.conversion=conversion e-/ADU;
% p.preview: true if preview mode (fit only current image and display
% results).
% p.previewframe=frame to preview;
% p.peakfilter=filtersize (sigma, Gaussian filter) for peak finding;
% p.peakcutoff=cutoff for peak finding
% p.roifit=size of the ROI in pixels
% p.bidirectional= use bi-directional fitting for 2D data
% p.mirror=mirror images if bead calibration was taken without EM gain
% p.status=handle to a GUI object to display the status;
% p.outputfile=file to write the localization table to;
% p.outputformat=Format of file;
% p.pixelsize=pixel size in nm;

% p.loader which loader to use
% p.mij if loader is fiji: this is the fiji handle
% p.isscmos scmos camera used
% p.scmosfile file containgn scmos varmap

%% add path to helper functions & bioformats
tools_dir = fileparts(fileparts(mfilename('fullpath')));
addpath(tools_dir);
smap_path = setup_paths();

p=struct();
p.smappath=smap_path;

%% acquisition modality
% 'onecam' - the two spectral channels are split side-by-side on one
%            sensor (one merged loc file per position, both channels
%            already in the same frame/coordinate space)
% 'twocam' - the same optical split instead lands on two synchronized
%            cameras (one merged loc file per position, per camera).
%            Frame numbers must line up 1:1 between the two cameras.
p.modality = 'onecam'; % 'onecam' | 'twocam'

%% Image files
% Define the folder where your TIFF & MAT files are located
root_folder = uigetdir('F:\moritz\ME034\data\B2_vim680_tub647\2024-10-07\');
%uigetdir('W:\staff-umbrella\sr crosstalk\Tim\TF001\20231127\2023-11-27\');
p.root_folder=root_folder;

if strcmp(p.modality, 'twocam')
    root_folder_B = uigetdir(root_folder, 'Select the matching root folder for camera B');
    p.root_folder_B = root_folder_B;
end

ImageFilesFolder = dir(fullfile(root_folder, '*.*'));
ImageFilesFolder = ImageFilesFolder([ImageFilesFolder.isdir]);  % Keep only folders
ImageFilesFolder = ImageFilesFolder(~ismember({ImageFilesFolder.name}, {'.', '..'}));  % Remove '.' and '..'
ImageFilesFolder = natsortfiles(ImageFilesFolder); % resort
%% camera setup
p.pixelsize=108;
CalbFilePath = 'D:\Tim\TF001\20231127\Bead stack_1\Bead stack_1_MMStack_Pos0.ome_3dcal.mat';
%p.calfile = CalbFilePath; %None for gaussfit
p.calfile = 'none';

%% color processing
% apply color ratios
p.photon_ratios =  [0.01 0.13; 0.17 1];
%[0 0.04; 0.06 0.10; 0.14 1];%[0 1; 0 1];%[0 0.04; 0.06 0.10; 0.14 1]; % af647 0.21, cf660 0.07 cf680 0.02
p.n_colors=2;
p.specificity = 0.9;
p.include_edge_ratios = 0;


%% drift correction
p.correctz=false;
p.correctxy=true;
p.drift_mirror2c.Value = 1; %1 all, 2 horizontal, 3 vertical

%% do summary statistics
p.makesummary = true;

% using csv or mat processing
p.csv_import=false;


% do channel registration, color assignment and drift correction
for directory = 1:length(ImageFilesFolder)

    if ~isfolder(fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name))
        continue
    end
    % get merged locs folder from within ImageFilesFolder
    processedFolder = fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name);
    p.processedFolder =processedFolder;

    fprintf('Processing directory nr. %d, %s \n', directory, processedFolder)

    p.loader=2;% which loader to use1:mytiff, 2:bioformatstiff, 3: fiji?
    p.mij=nan; %if loader is fiji: this is the fiji handle
    p.importdef.selection = 'csv_KG_splinefit.txt';
    if ~exist(p.calfile,'file') && p.csv_import
        p.importdef.selection = 'csv_KG_gaussfit.txt';
    end

    %% load camera A (always present)
    [locA, widthA, heightA] = load_camera_locs(processedFolder, p);
    if isempty(locA)
        fprintf('Skipping directory nr. %d, %s (no camera A data)\n', directory, processedFolder)
        continue
    end
    locA = centerlocs(locA);
    p.currentfileinfo.Width = widthA;
    p.currentfileinfo.Height = heightA;
    p.check_phot=true; p.val_phot=[0 1e7];
    p.check_locprec=true; p.val_locprec=[0 50]; %p.val_locprec=[0 20];
    p.check_bg=false; p.val_bg=[0 25];
    p.check_LL=false; p.val_LL=[0 25];
    p.check_psf=false; p.val_psf=[0 200];
    p.check_xnm=true; p.val_xnm=[0 (widthA*p.pixelsize)-10000];
    p.check_ynm=true; p.val_ynm=[0 heightA*p.pixelsize];
    locA=filterlocs(locA, p);

    %% two-camera mode: load camera B and combine into one synthetic
    % side-by-side canvas, exactly like the single-camera dual-view
    % layout register_2channel/RegisterLocs2 already expect (camera B's
    % xnm is shifted by camera A's frame width)
    if strcmp(p.modality, 'twocam')
        processedFolder_B = fullfile(root_folder_B, ImageFilesFolder(directory).name);
        if ~isfolder(processedFolder_B)
            fprintf('Skipping directory nr. %d, %s (no matching camera B folder)\n', directory, processedFolder)
            continue
        end
        [locB, widthB, heightB] = load_camera_locs(processedFolder_B, p);
        if isempty(locB)
            fprintf('Skipping directory nr. %d, %s (no camera B data)\n', directory, processedFolder)
            continue
        end
        locB = centerlocs(locB);
        p.check_xnm=true; p.val_xnm=[0 (widthB*p.pixelsize)-10000];
        p.check_ynm=true; p.val_ynm=[0 heightB*p.pixelsize];
        locB=filterlocs(locB, p);

        combined_loc = combine_2cam_locs(locA, locB, widthA*p.pixelsize);
        p.currentfileinfo.Width = widthA + widthB;
        p.currentfileinfo.Height = max(heightA, heightB);
    else
        combined_loc = locA;
    end

    %img tab handle
    tg = uitabgroup;
    p.resultstabgroup=tg;

    LocData = interfaces.LocalizationData;
    LocData.addLocData(combined_loc);

    % set processing parameters
    p.currentfileinfo.cam_pixelsize_um = p.pixelsize/1000;
    p.allfiles=false;
    p.currentfileinfo.roi= [0, 0, p.currentfileinfo.Width-20, p.currentfileinfo.Height];
    %[0, 0, p.currentfileinfo.Width, p.currentfileinfo.Height];
    p.targetmirror.selection='none';
    p.transform.selection='affine';
    p.targetpos.selection = 'left';
    p.transformparam=3;

    % set up registration parameters
    p.isz=false;
    p.useT=false;
    p.uselayers=false;
    param.pixelsizenm= [40, median(LocData.loc.locprecnm)];% [50, 30, 20, 10];
    param.maxshift_corr=[100000, 35000, 15000];
    param.maxlocsused=[floor(size(LocData.loc.frame, 1)/5) floor(size(LocData.loc.frame, 1)/3)];
    param.maxshift_match=[300, 100];
    param.initial_mag=1;
    if strcmp(p.modality, 'twocam')
        % camera B's locs were placed exactly widthA*pixelsize to the
        % right of camera A's, so that is the true initial guess
        param.initialshiftx = widthA*p.pixelsize;
    else
        param.initialshiftx= (p.currentfileinfo.roi(3)/2)*p.pixelsize;
    end
    param.initialshifty= 0;
    p.register_parameters = param;

    % set position in locdata
    guipar.sr_pos.content=[p.currentfileinfo.Width*p.pixelsize/2, p.currentfileinfo.Height*p.pixelsize/2];
    guipar.sr_pos.isGuiPar =false;
    guipar.sr_size.content=[p.currentfileinfo.Width*p.pixelsize, p.currentfileinfo.Height*p.pixelsize];
    guipar.sr_size.isGuiPar =false;
    LocData.P.par=guipar;
    %try
        transformed_locs=register_2channel(LocData,p);
    %catch
    %    fprintf('Skipping directory nr. %d, %s \n', directory, processedFolder)
    %    continue
    %end

end

function [loc, width, height] = load_camera_locs(processedFolder, p)
%LOAD_CAMERA_LOCS Read one camera's merged loc file plus its frame size
% from the TIFF stack in processedFolder. Returns loc=[] if no merged
% file / TIFF is found (caller decides whether to skip).
loc = [];
width = [];
height = [];

ImageFiles = dir(fullfile(processedFolder, '*.tif*'));
if isempty(ImageFiles)
    return
end
numbers=cellfun(@extract_number,{ImageFiles.name});
[~,order]=sort(numbers);
ImageFiles=ImageFiles(order);

mergedfilefolder = strcat(processedFolder, '\merge');
if p.csv_import
    file_ending = '*.csv';
else
    file_ending = '*sml.mat';
end
merge_files = dir(fullfile(mergedfilefolder, file_ending));
if isempty(merge_files)
    return
end
mergedfilename = merge_files(1).name;

imagefile=fullfile(processedFolder, ImageFiles(1).name);
switch p.loader
    case 1
        reader=mytiffreader(imagefile);
        width=reader.info.width;
    case 2
        reader=bfGetReader(imagefile);
        width= reader.getSizeX;
        height=reader.getSizeY;
end

if p.csv_import
    csvreader= File.Load.Loader_csvAndMore;
    csvreader.load(p,fullfile(mergedfilefolder, mergedfilename));
    loc = csvreader.locData;
else
    loc_s = load(fullfile(mergedfilefolder, mergedfilename));
    loc = loc_s.saveloc.loc;
end
end

function val=extract_number(str)
try
tokens=regexp(str,'_(\d*)_sml.mat','tokens');
val=str2double(tokens{end}{end});
catch
    val = 0;
end
end
