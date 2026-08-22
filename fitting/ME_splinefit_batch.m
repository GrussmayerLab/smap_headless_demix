%% script for batch-fitting and spectral demixing processing with SMAP 
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
root_folder = uigetdir('F:\moritz\ME034\data');
p.root_folder=root_folder;

ImageFilesFolder = dir(fullfile(root_folder, '*.*'));
ImageFilesFolder = ImageFilesFolder([ImageFilesFolder.isdir]);  % Keep only folders
ImageFilesFolder = ImageFilesFolder(~ismember({ImageFilesFolder.name}, {'.', '..', 'init'}));  % Remove calibration folder, '.' and '..'
%resort to filename

ImageFilesFolder = natsortfiles(ImageFilesFolder);

%% skip localisation step (if locs are already available
p.localise_raw=false;  %true, false
p.csv_import=false; % using csv or mat processing 
p.merge_locs=false; % whether to merge the single file locs into a single csv (default is true)
p.makeBlinkMovie=false; % create movie with a few frames of raw data overlapped with locs
p.blinkmovie_filerange=1:1:3; 
p.assign_multic=true; % do registration if necessary and assign colors
%% preview, FOV
p.preview=false; %true; %false;
p.previewframe=1000;
p.previewfilemax=[1,2,3];
p.fov_include = [1 1 580 640];

p.fov_include_autodetect = false;
%whole FOV[1 1 540 970];%  [y1 x1 h w], [y2 x2 h w]



%% peakfinder
p.peakfilter=1.2;%2;% filtersize (sigma, Gaussian filter) for peak finding; or DOG 
p.peakcutoff=[1300;240];%[620;100];%[35;180];%200;% absolute photon cutoff for peak finding, not recommended
p.peakdynamic=true;  %true, false, use dynamic peakfinder cutoff
p.peakdynamicfactor=[1.2;1.2]; % factor for dznamic peakfinding, needs to be [0,3], 0=rather nonspecific, fits some background, 3=only brightest locs
p.roifit=7;%size of the ROI in pixels
p.bidirectional=true;%use bi-directional fitting for 2D data
p.mirror=false;%mirror images if bead calibration was taken without EM gain
p.pixelsize=108;%nm
p.backgroundmode= 'DoG';  % none: 2, 1 DoG,   0, gaussian, 
p.use_mindistance = true;
p.mindistance = 7;
%% color processing
% apply color ratios
%p.photon_ratios = [0 0.5; 0.62 1];
%p.photon_ratios = [0 0.58; 0.62 0.78; 0.82 1];
%[0 1; 0 1]; %[0 0.04; 0.06 0.10; 0.14 1]; % dy634 0.34 af647 0.21, cf660 0.07 cf680 0.02 
%p.numcolors=1;
p.specificity = 0.9;
p.n_colors = 1;
%% Camera setup
% p.calfile: filename of calibration data (char);
% p.offset=ADU offset of data;
% p.conversion=conversion e-/ADU;
% p.preview: true if preview mode (fit only current image and display
% results).

% Define the folder where the calb file is located
CalbFilePath = 'D:\Tim\TF001\20231127\Bead stack_1\Bead stack_1_MMStack_Pos0.ome_3dcal.mat';
VarmapFilePath = 'D:\Accent_Ries\Prime_BSI_express\20220110_calibration\Var_25ms_tif.tif'; % needs to be .tif
%VarmapFilePath = 'U:\sr crosstalk\Prime_BSI_express\20220110_calibration\Var_25ms_tif.tif'; % needs to be .tif
%p.calfile = CalbFilePath; %None for gaussfit
p.calfile = 'none';
p.offset=100;
p.conversion=0.61;
%16bit_CMS=0.28;% 16bit_HDR=0.61;%
%11bit_G1=3.7; 11bit_G1=2.55; 11bit_G1=1.10;
    
%% drift correction
p.correctz=false;
p.correctxy=true;
p.drift_mirror2c.Value = 1; %1 all, 2 horizontal, 3 vertical

%% do summary statistics and visualisation
p.makesummary = true;
p.render_gaussian = false;

%% start localisation
for directory = 1:length(ImageFilesFolder)  
    
    if ~isfolder(fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name))
        continue
    end 

    processedFolder = fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name);
    
    p.processedFolder =processedFolder;
    if p.localise_raw
        fprintf('Localising directory nr. %d, %s \n', directory, processedFolder)
    end
    
    %% List all metadata files in the folder 
    % might require to copy them to the root of the processed folder to avoid sporadic MMStack handling
    %
    metaFiles = dir(fullfile(processedFolder, '*metadata.txt'));
    % clean up directorz to not get MMstack handling
    copy_rename_files_to_root(metaFiles, root_folder, processedFolder)

    metaFiles = dir(fullfile(processedFolder, '*_metadata.txt'));
    %p.roi = [405,871,1360,686];
    if ~isfield(p, "roi") && size(metaFiles,1) > 0
        meta_file = fullfile(processedFolder, metaFiles(1).name);
        fprintf('Parsing metadata file %s \n', meta_file)
        
        % write reduced metadata to metadata.mat to reduce processing time
        if isfile(fullfile(processedFolder,'_metadata.mat'))
            meta = load(fullfile(processedFolder,'_metadata.mat'));
        else 
            meta = parse_metafiles(meta_file);
            save(fullfile(processedFolder,'_metadata.mat'), '-struct', 'meta', 'Summary', 'FrameKey_0_0_0')
        end 
   
        roi = meta.FrameKey_0_0_0.ROI;
        % Extract integers using regexp
        matches = regexp(roi, '\d+', 'match');
        % Convert the matched strings to integers and store in a 1x4 array
        p.roi = cellfun(@str2double, matches);
        
        % check if gain setting is proper
        try
            gain = meta.FrameKey_0_0_0.BSIExpress-Gain; 
            if contains(gain, 'CMS')
                p.conversion = 0.28;
            elseif contains(gain, 'HDR')
                p.conversion = 0.61;
            end 
        catch 
        end 
    end 


    % List all TIF files in the folder
    ImageFiles = dir(fullfile(processedFolder, '*.tif*'));
    % sort ImageFiles to get proper basefile name
    numbers=cellfun(@extract_number,{ImageFiles.name});
    [~,order]=sort(numbers);
    ImageFiles=ImageFiles(order);
    % write basefile to struct
    [~, p.basefilename, ~] = fileparts(ImageFiles(1).name);
    p.basepath = processedFolder;
    p.mergedfilefolder =strcat(processedFolder, '\merge'); 
    p.outputfolder=p.mergedfilefolder;
    p.mergedfilename = strcat(p.basefilename, '_merge.csv');
    

    %% preview, FOV
    p.isscmos=true;% scmos camera used
    p.scmosfile=VarmapFilePath;%file contain scmos varmap
    
    %% image loader
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

    if p.localise_raw
        %% autodetect fovs
        % preload image stack of limited length
        % run field of view detection via edge detection on median(stack)
        try
        if p.fov_include_autodetect
            startframe=1 ;
            endframe= min(1000, p.currentfileinfo.Frames);
            stack_length = endframe-startframe;
            stack = zeros(p.currentfileinfo.Height, p.currentfileinfo.Width, stack_length);
    
            for tf=startframe:endframe
                % consider which reader is used 
                switch p.loader
                    case 1
                        stack(:,:,tf)=reader.read(tf);
                    case 2
                        stack(:,:,tf)= bfGetPlane(reader,tf);
                end 
            end
            %p.fov_include = findFieldOfViews(stack, p.offset);           
            clear stack startframe stack_length
        end 
    
        catch
            fprintf('skipping fov detection, something wrong with file loading\n')
        end 
        fprintf('Overwriting fov selection \n')
        p.fov_include = [1 1 p.currentfileinfo.Height-1 floor(p.currentfileinfo.Width/2); 1 floor(p.currentfileinfo.Width/2)+1 p.currentfileinfo.Height-1 floor(p.currentfileinfo.Width/2)-1];
        %p.fov_include = [1 1 p.currentfileinfo.Height-1 p.currentfileinfo.Width-1];
    %% GUI for updates 

        fh = figure;
        prompt ='Status update';
        h = uicontrol('Style','text','Position', [50 50 300 50],'String',prompt);
        p.status=h;%handle to a GUI object to display the status
        %% make bead calibration
        %run 3D calibration GUI and make 3D calibration
        %For fitting 2D datasets, create 3D calibration from 2D PSF stack (e.g. example_data/beadstacks_2D)
        % save e.g. as data/bead_2DPSF_3dcal.mat
        
        % or generate calibration files programmatically:
        %if ~exist([pwd filesep 'example_data' filesep 'bead_2DPSF_3dcal.mat'],'file') %only run if no calibration files have been generated, as this takes time.
        %    example_calibration
        %end
        %% load bead calibration
        %cal=load([pwd filesep 'example_data' filesep 'bead_2DPSF_3dcal.mat']); %load bead calibration
        % frame, x,y,z,phot,bg, errx,erry, errz,errphot, errbg,logLikelihood
        %load calibration
        if exist(p.calfile,'file')
            cal=load(p.calfile);% change ME
            p.dz=cal.SXY.cspline.dz;  %coordinate system of spline PSF is corner based and in units pixels / planes
            p.z0=cal.SXY.cspline.z0;
            p.coeff=cal.SXY.cspline.coeff;
            if iscell(p.coeff)
                p.coeff=p.coeff{1};
            end
            p.isspline=true;
        else
        %     errordlg('please select 3D calibration file')
            %warndlg('3D calibration file could not be loaded. Using Gaussian fitter instead.','Using Gaussian fit','replace');
            p.isspline=false;
        end
        %% preload variance map
        p.fitsperblock =300000;
        p.varmap=[];
        if p.isscmos
            p.varstack=ones(p.roifit,p.roifit,p.fitsperblock,'single');
            [~,~,ext]=fileparts(p.scmosfile);
            switch ext
                case '.tif'
                    p.varmap=imread(p.scmosfile);
                case '.mat'
                    p.varmap=load(p.scmosfile);
                    if isstruct(p.varmap)
                        fn=fieldnames(p.varmap);
                        p.varmap=p.varmap.(fn{1});
                    end
                otherwise
                    %errordlg('could not load variance map. No sCMOS noise model used.')
                    fprintf('could not load variance map. No sCMOS noise model used.\n')
                    p.isscmos=false;
                    p.varstack=0;
           end
        else
            p.varstack=0;
        end
        if isfield(p, 'roi') && size(p.varmap,1) ~= 0
            p.varmap=p.varmap(p.roi(2):p.roi(2)+p.roi(4)-1, p.roi(1):p.roi(1)+p.roi(3)-1);
        end

        %% load transformation
       %T_filename = fullfile(p.root_folder, 'manual_T.mat');
       %T_filename = fullfile(p.root_folder, 'beadstack_T.mat');
        %if isfile(T_filename)
        %    T = load(T_filename);
        %    transformation = T.transformation;
        %    p.Tfile =T_filename;
        %    p.useT=true;
        %end
        %% run fitter

        for f = 1:numel(ImageFiles) 
            
            if p.preview && ~ismember(f, p.previewfilemax )  
                continue
            end 
            p.filenumber =f;
            fprintf('Fitting %s\n', ImageFiles(f).name);
            % Remove the .tiff extension
            [~, baseFileName, ~] = fileparts(ImageFiles(f).name);
            p.imagefile=fullfile(processedFolder, ImageFiles(f).name);
            
            %adjust new filenames
            locFileName = strrep(baseFileName, '.tiff', '_sml.mat');
            %newFileName=fullfile(processedFolder, strcat(locFileName, '.csv')); 
            newFileName=fullfile(processedFolder, strcat(locFileName, '.mat'));
            p.outputfile=newFileName;%file to write the localization table to;
            p.outputformat='sml';
            %run fitter
            %csplinefitter_ME(p)
            csplinefitter2mat(p)
            %csplinefitter_dualchannel_Tvcandidates(p, transformation)
    

            % check whether MMSTACK (files merged and handled as one) or NDTIFF (handle
            % files separately)
            if contains( ImageFiles(f).name , 'MMStack' )
                break 
            end 
        end
        
    end
    %% merge localisations
    if ~p.preview && p.merge_locs
        if p.csv_import
        locDat = merge_SMAP_locs_csv(processedFolder, p);
        else
        locDat = merge_SMAP_locs_mat(processedFolder, p);
        end
    end
    
    %% create movie to check locs vs image
    if ~p.preview && p.makeBlinkMovie 
        makeBlinkMovie_ME(processedFolder, p);
    end
end 
clear locDat

if ~p.preview && p.assign_multic
    % do channel registration, color assignment and drift correction
    for directory = 1:length(ImageFilesFolder)
    
        if ~isfolder(fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name))
            continue
        end 
        % get merged locs folder from within ImageFilesFolder
        processedFolder = fullfile(ImageFilesFolder(directory).folder, ImageFilesFolder(directory).name);
        p.processedFolder = processedFolder;
        p.mergedfilefolder =strcat(processedFolder, '\merge'); 
        
        if p.csv_import
            file_ending = '*.csv';
        else
            file_ending = '*sml.mat';
        end 
        merge_files = dir(fullfile(p.mergedfilefolder, file_ending));
        p.mergedfilename = merge_files(1).name;
    
        [p.basepath, p.basefilename, ~] = fileparts(p.mergedfilename);
        
        fprintf('Processing directory nr. %d, %s \n', directory, processedFolder)
    
        %% register channels 
        % get transformation target left, reference right
        % apply transformation
        % get photonratio
        if ~p.preview
            
            % set processing parameters
            p.currentfileinfo.cam_pixelsize_um = p.pixelsize/1000;
            p.allfiles=false;
            p.currentfileinfo.roi=[0, 0, p.currentfileinfo.Width, p.currentfileinfo.Height];
            p.targetmirror.selection='none';
            p.transform.selection='affine'; %projective
            p.targetpos.selection = 'left';
            p.transformparam=3;
        
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
            p.check_phot=false; p.val_phot=[0 1e7];
            p.check_locprec=true; p.val_locprec=[0 50]; %p.val_locprec=[0 20];
            p.check_bg=false; p.val_bg=[0 25];
            p.check_LL=false; p.val_LL=[0 25];
            p.check_psf=true; p.val_psf=[100 250];
            p.check_xnm=false; p.val_xnm=[prctile(LocData.loc.xnm,0.1) prctile(LocData.loc.xnm,99.9)]; %p.currentfileinfo.Width*p.pixelsize];
            p.check_ynm=false; p.val_ynm=[prctile(LocData.loc.ynm,0.1) prctile(LocData.loc.ynm,99.9)]; % [0 p.currentfileinfo.Height*p.pixelsize];
        
            LocData.loc=filterlocs(LocData.loc, p);
            
            %% center localisations again
            % need to correct for loc filters
            LocData.loc = centerlocs(LocData.loc);


            % set up registration parameters
            p.isz=false;
            p.useT=false;
            p.uselayers=false;
            param.pixelsizenm= [50, 40, median(LocData.loc.locprecnm)];% [50, 30, 20, 10];  Around size of the localization precision. If the correlation image is dotty and the wrong maximum is found, increase this siz
            param.maxshift_corr=[100000, 35000, 15000]; % reduce, if wrong maximum is found. Increase, if true maximum is outside
            param.maxlocsused=[floor(size(LocData.loc.frame, 1)/5) floor(size(LocData.loc.frame, 1)/3)];
            param.maxshift_match=[300, 150]; %  distance that corresponding localizations can be apart (after shift is applied). 250-500 nm typically. If this value is too large, random localizations are matched, this can introduce systematic error
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
    end
end 



%%  helpers
function copy_rename_files_to_root(metaFiles, root_folder, processedFolder)
   for f = 1:numel(metaFiles) 
       meta_copy_file = fullfile(processedFolder, metaFiles(f).name);
       if ~exist(fullfile(root_folder, metaFiles(f).name), "file")
           copyfile(meta_copy_file, root_folder);
       end
       if contains(metaFiles(f).name, 'NDTiffStack')
            movefile(meta_copy_file, fullfile(processedFolder, '_metadata.txt'));
       end
       clear meta_copy_file
    end
end 


function parse_file = parse_metafiles(filename)
    raw = fileread(filename);
    %parse_file = regexp( raw , '\n', 'split'); if its not in json format
    parse_file = jsondecode(raw);
end 


function val=extract_number(str)
try
tokens=regexp(str,'_(\d*)_sml.mat','tokens');
val=str2double(tokens{end}{end});
catch
    val = 0;
end 
end 