% ME function to script regsitration for 2channel SD_STORM
function transformed_locDat=register_2channel(locDat,p)
%
set(0,'DefaultFigureVisible','on')
 
p.resultsfolder = strcat(p.processedFolder, '\results'); 
if ~exist(p.resultsfolder, 'dir')
   mkdir(p.resultsfolder)
end

if ~isfield(p, "targetpos.selection")
    p.targetpos.selection = 'left';
end 

%% check whether Tranformation file exists and load it
fprintf('Transformation ...')
Nfiles=max([max(locDat.loc.filenumber), 1]);
p.dataselect.Value=Nfiles;
%filepars = struct();
%filepars.info = struct();
for fnumber=1:Nfiles
    filepars.info.cam_pixelsize_um=p.pixelsize/1000;
    filepars.info.Width=p.currentfileinfo.Width;
    filepars.info.Height=p.currentfileinfo.Height;
    filepars.number=fnumber;
end 
locDat.files.file = filepars;

T_filename = fullfile(p.root_folder, 'backup_T.mat');
if isfile(T_filename)
    T = load(T_filename);
    transformation = T.transformation;
    p.Tfile =T_filename;
    p.useT=true;
else
%end
%% run transformation via plugin 
locregister= Process.Register.RegisterLocs2; 
locregister.attachLocData(locDat);
locregister.register_parameters = p.register_parameters;

for f=1:Nfiles
    p.dataselect.Value=f;
    locregister.run(p);
end 

transformation=locregister.transformation; %locregister.transformation.copy
locDat=locregister.locData;
end
fprintf(' done, saving transformation \n')

%% save transformation 
% convert transform to interface.LocaTransformN

%fn=strrep(p.imagefile,'_sml.mat','_T.mat');
fn=strcat(p.basefilename,'.csv','_T.mat');
save(fullfile(p.mergedfilefolder, fn),'transformation'); % transformation saving into processing folder
if isfield(p, "root_folder")
    save(fullfile(p.root_folder, 'backup_T.mat'),'transformation'); % backup transformation saving into root folder
end 

p.Tfile=fullfile(p.mergedfilefolder, fn);
%obj.setPar('transformationfile',fn);


%% match locs and assign color from phot % goes out of memmorz, do it manually for batch of frames
% need to add transformation file to locs
fprintf('Matching locs across channels ... ')
p.assignfield1.selection='intA1';
p.assignfield1.Value=0;
p.assignfield2.selection='intB1';
p.assignfield2.Value=0;

% reset register parameters for matching locs 
%p.register_parameters.maxlocsused=1e4;

locDat.files.file(p.dataselect.Value).transformation=transformation;
file=locDat.files.file(p.dataselect.Value);

framebatch=1000; %100
frames=1:framebatch;
fn=fieldnames(locDat.loc);
locs_subset=struct();
for F=1:framebatch:max(locDat.loc.frame)
    frames = [max([frames(1),F]),min([max(locDat.loc.frame),F+framebatch])];
    framecondition_ind = locDat.loc.frame>=frames(1) & locDat.loc.frame<frames(2);
    for k=1:numel(fn)
        locs_subset.(fn{k})=locDat.loc.(fn{k})(framecondition_ind, :);
    end
    
    if isempty(locs_subset.(fn{1}))
        continue
    end
    
    % fails to detect matches and throws error occasionally, wrapping it in
    % a trz catch for now
    try
        loco=get2Clocintensities_ME(locs_subset,transformation,file,p);
    catch 
        fprintf('Skipping frames %d - %d for matching\n', frames(1), frames(2));
        continue
    end 
    fn_new=fieldnames(loco);
    for kn=1:numel(fn_new)
        locs_subset.(fn_new{kn})=loco.(fn_new{kn});
    end

    if exist('transformed_locs', 'var')
        fn_full=fieldnames(locs_subset);
        for kn_full=1:numel(fn_full)
            transformed_locs.(fn_full{kn_full})=cat(1, transformed_locs.(fn_full{kn_full}), locs_subset.(fn_full{kn_full}));
        end
        %transformed_locs = [transformed_locs;loco];
    else 
        transformed_locs = locs_subset;
    end 

end 


fprintf('done \n')

%% clean up non paired localisations from loc file and regroup
fprintf('Removing non-paired localisations ...')
p.cleanup_locs= true; %false

if p.cleanup_locs 
    try
        if isfield(transformed_locs, 'xnm_merge')  
            transformed_locs.xnm=transformed_locs.xnm_merge;
            transformed_locs.ynm=transformed_locs.ynm_merge;
        end 
    catch 
    end 
    % remove fields from struct
    fn = fieldnames(transformed_locs);
    for ii=1:numel(fn)
        if contains( fn(ii) , 'err' ) || contains( fn(ii) , 'pix' ) || contains( fn(ii) , 'Gauss' ) || contains( fn(ii) , 'log' ) || contains( fn(ii) , 'merge' )
            transformed_locs = rmfield(transformed_locs,fn(ii));
        end 
    end 
    
    % remove unpaired locs
    idx = transformed_locs.intA1~=0;

    % remove loc at 0,0 
    idxnull = (transformed_locs.xnm~=0 & transformed_locs.ynm~=0); 
    idx = idx&idxnull; 

    fn = fieldnames(transformed_locs);
    for ii=1:numel(fn)
        transformed_locs.(fn{ii}) =  transformed_locs.(fn{ii})(idx);
    end 
    
end 



transformed_locDat=locDat;
transformed_locDat.setPar('mode',1);
%locDat.mode=1;
transformed_locDat.loc=transformed_locs;

p.group_dx=30;
p.group_dt=2;
p.group_mode=1;
transformed_locDat.regroup(p.group_dx,p.group_dt,p.group_mode);
transformed_locDat.setPar('locFields',fieldnames(locDat.loc));
transformed_locDat.P.globalSettings.saveas7.object=false;

fprintf('done \n')

%% recenter locs
if p.cleanup_locs 
    transformed_locDat.loc = centerlocs(transformed_locDat.loc); 
end 

%% assign color based on custom ratio
fprintf('Assigning color channels ...')
[transformed_locDat.loc, p] = apply_color_from_ratio(transformed_locDat.loc, p.photon_ratios, p);
fprintf('done \n')
%% apply transform to overlap images
%p.allfiles = true;
%p.transformwhat.Value=2; % circumvent _T search per file in applytransformation script

%loc=apply_transform_locsN(transformed_locDat.loc,transformation,transformed_locDat.files.file(1),p);
%transformed_locDat.loc = copyfields(transformed_locDat.loc,loc);
%transformed_locDat.regroup(p.group_dx,p.group_dt,p.group_mode);
%transformed_locDat.regroup;
%transformed_locDat.setPar('locFields',fieldnames(locDat.loc));
%transformed_locDat.P.globalSettings.saveas7.object=false;

%% apply drift correction
fprintf('Applying drift correction ...')
if p.correctxy || p.correctz
    transformed_locDat.setPar('group_mode',1);

    p.drift_whatfiles.selection='all';
    p.drift_timepoints=15;
    p.drift_mirror2c.Value=1; %all locs, no mirror
    p.drift_pixrec=10;
    p.drift_window=7;
    p.drift_maxdrift=1000;
    p.drift_maxpixels=4096;
    p.smoothpar=[];
    p.smoothmode.Value=1;
    p.showresults=1;
    p.drift_reference=0; % whether last frame is reference frame
    p.drift_ask=0; % pop up a window to ask whether to apply estimated drift 
    p.save_dc=0;
    p.singlebead = 0;

    driftcorrect=Process.Drift.driftcorrectionXYZ;
    driftcorrect.attachLocData(transformed_locDat);
    driftcorrect.setPar('mode',1);
    driftcorrect.setPar('group_mode',1);

    % give driftc script a variable to write drift info
    %driftcorrect.locData.files.file.driftinfo='none';
    driftcorrect.locData.files.filenumberEnd=1;
    roi=[min(transformed_locDat.loc.xnm);min(transformed_locDat.loc.ynm); ...
        max(transformed_locDat.loc.xnm);max(transformed_locDat.loc.ynm);];
    driftcorrect.locData.files.file.info.roi=roi;
    driftcorrect.locData.files.file.name=p.basefilename;

    driftcorrect.run(p);

    transformed_locDat=driftcorrect.locData;
end 

fprintf('done \n')

%% write colors to different layers for rendering purposes
channels=unique(transformed_locDat.loc.channel);
for c=1:length(channels)
    transformed_locDat.layer(c).filter = transformed_locDat.loc.channel == channels(c);
end 

%% write ratios to figure and save
%rat_fig = figure(10);
%transformed_locDat.loc.ratios

%% write locs with smlm saver plugin

p.saveTo=fullfile(p.resultsfolder ,[p.basefilename, '.mat']);
p.saveroi=false;
excludesavefields={'groupindex','numberInGroup','colorfield'};
p.pluginpath={'SMLMsaver'};   

% adjust image boundaries in display
roi=[min(transformed_locDat.loc.xnm);min(transformed_locDat.loc.ynm); ...
        max(transformed_locDat.loc.xnm);max(transformed_locDat.loc.ynm);];
transformed_locDat.files.file.info.roi=roi;

savesml(transformed_locDat,p.saveTo,p,excludesavefields); 

%% prepare loc statistics - unused
p.filter= false; p.useroi= false; p.overview= true;
%eval_dat ={transformed_locDat.loc, transformed_locDat.loc};
p.photrange=[0 50000];
p.lifetimerange=[0 10];


%% save processing parameters file
% reduce p footprint
p.resultstabgroup=0;
save(fullfile(p.resultsfolder,'p.mat'),'p'); % transformation saving into processing folder

%% bilinear histogram rendering (ImDecorr function)
pps = 20;%5;
fov= [max(transformed_locDat.loc.xnm, [], 'all') - min(transformed_locDat.loc.xnm, [], 'all'), ...
    max(transformed_locDat.loc.ynm, [], 'all')-min(transformed_locDat.loc.ynm, [], 'all')];
%fov = [p.currentfileinfo.Width*p.pixelsize, p.currentfileinfo.Height*p.pixelsize];
bbox = cast(fov./pps, 'int32');
d = transformed_locDat.loc;
for c=1:length(channels)
    if isfield(d,'PSFynm')
        dat = [d.ynm(transformed_locDat.layer(c).filter), d.xnm(transformed_locDat.layer(c).filter), d.PSFynm(transformed_locDat.layer(c).filter), d.PSFxnm(transformed_locDat.layer(c).filter) ];
    else
        dat = [d.ynm(transformed_locDat.layer(c).filter), d.xnm(transformed_locDat.layer(c).filter), d.PSFxnm(transformed_locDat.layer(c).filter), d.PSFxnm(transformed_locDat.layer(c).filter) ];
    end
        % filter out nans and infs
    idx = any( isnan( dat ) | isinf( dat ), 2 ); 
    dat = dat( ~idx ,:);

    dat_bilinear = [dat(:,2) dat(:,1)];
    %try
        [render,p.pps] = smlmHist(dat_bilinear,pps,max(fov)); % fov only takes a single input [,2] no proper supported )
        % limit file size to actual pixels
        render=render(1:bbox(2), 1:bbox(1));
        imwrite(render, fullfile(p.resultsfolder, append("render_bilin_ch",num2str(c),".tiff")));
    %catch
        %fprintf('Skipping rendering, something went wrong\n')
    %end 

    %% gaussian rendering as well
    if isfield(p, 'render_gaussian') && p.render_gaussian
        render = loc_gauss_std_blur(dat, 10, 10, fov(2), fov(1));
        imwrite(render, fullfile(p.resultsfolder, append("render_gauss_ch",num2str(c),".png")));
    end 
    
end 


%% make  loc statistics and write to file
%frame_stats = make_statistics2(eval_dat,p,true); 
%save(fullfile(p.mergedfilefolder,'frame_stats.mat'),'frame_stats');
%frame_locstats_name = fullfile(p.mergedfilefolder, "frame_locstats.svg");
%saveas(gcf,frame_locstats_name);

if p.makesummary
    fprintf('Summary statistics ...')
    summaryStats(transformed_locDat.loc, p.resultsfolder, {'locprecnm', 'phot', 'bg', 'ratio', 'frame'}, true, p);
    fprintf('done \n')
end 
%% locstats_global
%p.sr_layerson=channels;
%transformed_locDat.files.file.name=p.mergedfilename;
%locstats=Analyze.measure.Locstatistics;
%locstats.attachLocData(transformed_locDat);
%locstats.setPar('mode',1);
%locstats.setPar('group_mode',1);
%locstats.run(p);


%locstats_name = fullfile(p.mergedfilefolder, "locstats.fig");
%saveas(gcf,locstats_name);




%% FRC resolution
% p.sameimage=true;
% p.takeimage=false;
% p.frc_blocks=10;
% p.pixrec_frc=200;
% p.sr_pos=[p.currentfileinfo.Width*p.pixelsize/2 p.currentfileinfo.Height*p.pixelsize/2];
% p.sr_size=[max(p.currentfileinfo.Width,p.currentfileinfo.Height)*p.pixelsize/2 max(p.currentfileinfo.Width,p.currentfileinfo.Height)*p.pixelsize/2];
% p.blockassignment.selection = 'random';
% 
% frc=Analyze.measure.FRCresolution;
% frc.attachLocData(transformed_locDat);
% frc_graph =frc.run(p);
% frc_name = fullfile(p.mergedfilefolder, "frc.svg");
% saveas(gcf,frc_name);


%% render image and write to file 
% 
% p.rendermode.selection = 'tiff';
% p.sr_pos=[p.currentfileinfo.Width*p.pixelsize/2 p.currentfileinfo.Height*p.pixelsize/2];
% p.shiftxy_min = 0;
% p.shiftxy_max = max(p.currentfileinfo.Width,p.currentfileinfo.Height)*p.pixelsize/2;
% p.ch_filelist.Value=1;
% p.render_colormode.Value=1;
% p.sr_plotcomposite=true;
% p.layercheck=true;
% 
% p.groupcheck=false;
% transformed_locDat.filter('phot', [] , 'inlist' , [0 1e7]);
% transformed_locDat.filter('locprecnm', [] , 'inlist' , [0 30]);
% 
% % write layerc parameter files
% for c=1:length(channels)
%    layer=num2str(channels(c));
%     layername='layer'+layer+'_';
%     transformed_locDat.setPar(layername, p);
%     %transformed_locDat.attachPar(layername);
%    % transformed_locDat.layername =p;
% end 
% 
% imout=TotalRender(transformed_locDat, p);
% 
% render_name = fullfile(p.mergedfilefolder, strcat(p.basefilename, "dft_render_.tif"));
% imwrite(imout,render_name,"tif");


end
