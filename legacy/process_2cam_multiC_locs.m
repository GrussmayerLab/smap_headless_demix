%% script to do ratiometric multicolor processing with data from 2 cameras with the SMAP data processing tools 
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

%% Image files
% Define the folder where your TIFF & MAT files are located
start_folder = 'W:\staff-umbrella\KGLab\moritz\STHdh cells exp for Anton\250911 STHdh cells';
%root_folder = uigetdir(start_folder);
%p.root_folder=root_folder;

%r_file = uigetfile(root_folder);
%t_file = uigetfile(root_folder);
[p.filename, root_folder] = uigetfile(start_folder);
p.root_folder=root_folder;


%% camera setup
p.pixelsize=97;


%% color processing
% apply color ratios
p.photon_ratios =  [0.01 0.45; 0.55 1];
%[0 0.04; 0.06 0.10; 0.14 1];%[0 1; 0 1];%[0 0.04; 0.06 0.10; 0.14 1]; % af647 0.21, cf660 0.07 cf680 0.02 
p.numcolors=2;

    
%% drift correction
p.correctz=false;
p.correctxy=true;
p.drift_mirror2c.Value = 1; %1 all, 2 horizontal, 3 vertical

%% do summary statistics
p.makesummary = true;

% using csv or mat processing 
p.csv_import=false;


%% start processing
% initialise localisation storage
LocData = interfaces.LocalizationData;

%% load data 
loc_s = load(fullfile(p.rootfolder, p.filename));
LocData.addLocData(loc_s.saveloc.loc);

%% registration parameters
% set processing parameters
p.currentfileinfo.cam_pixelsize_um = p.pixelsize/1000;
p.allfiles=false;
p.currentfileinfo.roi=[0, 0, p.currentfileinfo.Width, p.currentfileinfo.Height];
p.targetmirror.selection='none';
p.transform.selection='affine';
p.targetpos.selection = 'center';
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
param.initialshiftx= (p.currentfileinfo.roi(3)/2)*p.pixelsize;
param.initialshifty= 0;
p.register_parameters = param;





    if ~isfolder(fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name))
        continue
    end 
    % get merged locs folder from within ImageFilesFolder
    processedFolder = fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name);
    p.processedFolder =processedFolder;
    p.mergedfilefolder =strcat(processedFolder, '\merge'); 

    if p.csv_import
            file_ending = '*.csv';
        else
            file_ending = '*sml.mat';
    end 

    merge_files = dir(fullfile(p.mergedfilefolder, file_ending));
    p.mergedfilename = merge_files(1).name;

    [p.basepath, p.basefilename, ~] = fileparts(p.mergedfilename);
    
   
    %% set up file names 
    % List all TIF files in the folder
    ImageFiles = dir(fullfile(processedFolder, '*.tif*'));

    numbers=cellfun(@extract_number,{ImageFiles.name});
    [~,order]=sort(numbers);
    ImageFiles=ImageFiles(order);
    % write basefile to struct
    [p.basepath, p.basefilename, ~] = fileparts(ImageFiles(1).name);
    p.mergedfilefolder =strcat(processedFolder, '\merge'); 
    p.outputfolder=p.mergedfilefolder;
    if p.csv_import
        file_ending = '*.csv';
    else
        file_ending = '*sml.mat';
    end  
    merge_files = dir(fullfile(p.mergedfilefolder, file_ending));
    p.mergedfilename = merge_files(1).name;

    [p.basepath, p.basefilename, ~] = fileparts(p.mergedfilename);
    
    fprintf('Processing directory nr. %d, %s \n', directory, processedFolder)
    %% get image size 
    p.loader=2;% which loader to use1:mytiff, 2:bioformatstiff, 3: fiji? 
    p.mij=nan; %if loader is fiji: this is the fiji handle
   
        p.imagefile=fullfile(processedFolder, ImageFiles(1).name);
            % get file info
            switch p.loader
             case 1
                reader=mytiffreader(p.imagefile);
                width=reader.info.width;
                
             case 2
                reader=bfGetReader(p.imagefile);
                p.currentfileinfo.Width= reader.getSizeX;
                p.currentfileinfo.Height=reader.getSizeY;
                p.currentfileinfo.Frames=reader.getSizeT;
            end

    %% register channels 
    % get transformation target left, reference right
    % apply transformation
    % get photonratio

    %img tab handle
    tg = uitabgroup;
    p.resultstabgroup=tg;

    % read file with SMAP loader and csv to sml conversion structure
    % get conversion structure
    if ~exist(p.calfile,'file') && p.csv_import
        p.importdef.selection = 'csv_KG_gaussfit.txt';
    else 
        p.importdef.selection = 'csv_KG_splinefit.txt';
    end

    % preinitialise
    LocData = interfaces.LocalizationData;

    if p.csv_import
        p.importdef.Value=0;
        csvreader= File.Load.Loader_csvAndMore; 
        csvreader.load(p,fullfile(p.mergedfilefolder, p.mergedfilename));
        LocData.addLocData(csvreader.locData);
    else
        loc_s = load(fullfile(p.mergedfilefolder, p.mergedfilename));
        LocData.addLocData(loc_s.saveloc.loc);
    end

    %% center localisations
    % need to correct for position if ROI on sensor is used
    LocData.loc = centerlocs(LocData.loc);

    %% filter all fits with negative photon counts & less precise loc
    p.check_phot=true; p.val_phot=[0 1e7];
    p.check_locprec=true; p.val_locprec=[0 30]; %p.val_locprec=[0 20];
    p.check_bg=false; p.val_bg=[0 25];
    p.check_LL=false; p.val_LL=[0 25];
    p.check_psf=false; p.val_psf=[0 200];
    p.check_xnm=true; p.val_xnm=[0 p.currentfileinfo.Width*p.pixelsize];
    p.check_ynm=true; p.val_ynm=[0 p.currentfileinfo.Height*p.pixelsize];
    %apply filter 
    LocData.loc=filterlocs(LocData.loc, p);

    % set processing parameters
    p.currentfileinfo.cam_pixelsize_um = p.pixelsize/1000;
    p.allfiles=false;
    p.currentfileinfo.roi=[0, 0, p.currentfileinfo.Width, p.currentfileinfo.Height];
    p.targetmirror.selection='none';
    p.transform.selection='affine';
    p.targetpos.selection = 'center';
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
    param.initialshiftx= (p.currentfileinfo.roi(3)/2)*p.pixelsize;
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

function val=extract_number(str)
try
tokens=regexp(str,'_(\d*)_sml.mat','tokens');
val=str2double(tokens{end}{end});
catch
    val = 0;
end 
end
