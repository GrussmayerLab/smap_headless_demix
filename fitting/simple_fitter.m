%% Example script for batch-fitting with SMAP 
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
root_folder = uigetdir('D:\Tim\TF001\');
p.root_folder=root_folder;

ImageFilesFolder = dir(fullfile(root_folder, '*.*'));
ImageFilesFolder = ImageFilesFolder([ImageFilesFolder.isdir]);  % Keep only folders
ImageFilesFolder = ImageFilesFolder(~ismember({ImageFilesFolder.name}, {'.', '..'}));  % Remove '.' and '..'

%% skip localisation step (if locs are already available
p.localise_raw=true;  %true, false
p.merge_locs =true; % whether to merge the single file locs into a single csv (default is true)
p.assign_multic =true; % do registration if necessary and assign colors
%% preview, FOV
p.preview=false; %true; %false;
p.previewframe=3000;
p.previewfilemax=[2,3];
p.fov_include = [1 1 580 640];

p.fov_include_autodetect = false;
%whole FOV[1 1 540 970];%  [y1 x1 h w], [y2 x2 h w]

%% peakfinder
p.peakfilter=1.5;%2;% filtersize (sigma, Gaussian filter) for peak finding; or DOG 
p.peakcutoff=[1300;240];%[620;100];%[35;180];%200;% absolute photon cutoff for peak finding, not recommended
p.peakdynamic=true;  %true, false, use dynamic peakfinder cutoff
p.peakdynamicfactor=[1.2;1.2]; % factor for dznamic peakfinding, needs to be [0,3], 0=rather nonspecific, fits some background, 3=only brightest locs
p.roifit=7;%size of the ROI in pixels
p.bidirectional=true;%use bi-directional fitting for 2D data
p.mirror=false;%mirror images if bead calibration was taken without EM gain
p.pixelsize=108;%nm
p.backgroundmode='DoG'; %1, DoG   0, gaussian
%% color processing
% apply color ratios
p.photon_ratios = [0 0.04; 0.06 0.10; 0.14 1]; % af647 0.21, cf660 0.07 cf680 0.02 
p.numcolors=3;
%% Camera setup
% p.calfile: filename of calibration data (char);
% p.offset=ADU offset of data;
% p.conversion=conversion e-/ADU;
% p.preview: true if preview mode (fit only current image and display
% results).

% Define the folder where the calb file is located
%CalbFilePath = 'C:\Users\mengelhardt\data\local\ME019\spline_stack_3_MMStack_Pos0.ome_3dcal.mat';
CalbFilePath = 'D:\Tim\TF001\20231127\Bead stack_1\Bead stack_1_MMStack_Pos0.ome_3dcal.mat';
VarmapFilePath = 'D:\Accent_Ries\Prime_BSI_express\20220110_calibration\Var_25ms_tif.tif'; % needs to be .tif
%p.calfile = CalbFilePath; %None for gaussfit
p.calfile = 'none';
p.offset=100;
p.conversion=0.28;
%16bit_CMS=0.28;% 16bit_HDR=0.61;%
%11bit_G1=3.7; 11bit_G1=2.55; 11bit_G1=1.10;
    
%% drift correction
p.correctz=false;
p.correctxy=true;
p.drift_mirror2c.Value = 1; %1 all, 2 horizontal, 3 vertical

%% do summary statistics
p.makesummary = true;

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
    if ~isfield(p, "roi")
        meta_file = fullfile(processedFolder, metaFiles(1).name);
        fprintf('Parsing metadata file %s \n', meta_file)
        meta = parse_metafiles(meta_file);
   
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
    % write basefile to struct
    [p.basepath, p.basefilename, ~] = fileparts(ImageFiles(1).name);
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
        %p.fov_include = [1 1 p.currentfileinfo.Height-1 floor(p.currentfileinfo.Width/2); 1 floor(p.currentfileinfo.Width/2)+1 p.currentfileinfo.Height-1 floor(p.currentfileinfo.Width/2)-1];
        p.fov_include = [1 1 p.currentfileinfo.Height-1 p.currentfileinfo.Width-1];
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
            newFileName=fullfile(processedFolder, strcat(locFileName, '.csv'));
            p.outputfile=newFileName;%file to write the localization table to;
            p.outputformat='sml';
            %run fitter
            %csplinefitter_ME(p)
            csplinefitter2mat(p)
            %csplinefitter_dualchannel_Tcandidates(p, transformation)
    

            % check whether MMSTACK (files merged and handled as one) or NDTIFF (handle
            % files separately)
            if contains( ImageFiles(f).name , 'MMStack' )
                break 
            end 
        end
        
    end
    %% merge localisations
    if ~p.preview && p.merge_locs
        locDat = merge_SMAP_locs_csv(processedFolder, p);
        
        %write to .mat

        % prepare p
        p.currentfileinfo.cam_pixelsize_um = p.pixelsize/1000;
        p.mergedfilefolder =strcat(processedFolder, '\merge'); 

        % create SMAP struct
        LocData = interfaces.LocalizationData;
        LocData.addLocData(locDat);

        % set position in locdata
        guipar.sr_pos.content=[p.currentfileinfo.Width*p.pixelsize/2, p.currentfileinfo.Height*p.pixelsize/2];
        guipar.sr_pos.isGuiPar =false;
        guipar.sr_size.content=[p.currentfileinfo.Width*p.pixelsize, p.currentfileinfo.Height*p.pixelsize];
        guipar.sr_size.isGuiPar =false;
        LocData.P.par=guipar;

        fprintf('Saving directory nr. %d, %s \n saving as intermediate as .mat', directory, processedFolder)
        p.saveTo=fullfile(p.mergedfilefolder ,[p.basefilename, '_sml.mat']);
        p.saveroi=false;
        excludesavefields={'groupindex','numberInGroup','colorfield'};
        p.pluginpath={'SMLMsaver'};   
        savesml(LocData,p.saveTo,p,excludesavefields); 

        %locDat = merge_SMAP_locs_mat(ImageFilesFolder);
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
