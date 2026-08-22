%Copyright (c)2017 Ries Lab, European Molecular Biology Laboratory,
%  Heidelberg.
%  
%  This file is part of GPUmleFit_LM Fitter.
%  
%  GPUmleFit_LM Fitter is free software: you can redistribute it and/or modify
%  it under the terms of the GNU General Public License as published by
%  the Free Software Foundation, either version 3 of the License, or
%  (at your option) any later version.
%  
%  GPUmleFit_LM Fitter is distributed in the hope that it will be useful,
%  but WITHOUT ANY WARRANTY; without even the implied warranty of
%  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%  GNU General Public License for more details.
%  
%  You should have received a copy of the GNU General Public License
%  along with GPUmleFit_LM Fitter.  If not, see <http://www.gnu.org/licenses/>.
%  
%  
%  Additional permission under GNU GPL version 3 section 7

function csplinefitter2mat(p)
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

fittime=0;
if isfield(p, 'fitsperblock')
    fitsperblock=p.fitsperblock;%50000;
else
    fitsperblock=30000;
end 
imstack=zeros(p.roifit,p.roifit,fitsperblock,'single');
peakcoordinates=zeros(fitsperblock,3);
indstack=0;
resultsind=1;
% bgmode='wavelet'; 
if contains(p.backgroundmode,'avelet')
    bgmode=3;
elseif contains(p.backgroundmode,'aussian')
     bgmode=1;
elseif contains(p.backgroundmode,'none')
    bgmode=2;
elseif contains(p.backgroundmode,'edian')
    bgmode=4;
else
    bgmode=0;
end

%scmos

varstack=p.varstack;
varmap = p.varmap;
varmap=varmap*p.conversion^2;
%results


p.dx=floor(p.roifit/2);
% readerome=bfGetReader(p.imagefile);
p.status.String=['Open tiff file' ]; drawnow

 switch p.loader
     case 1
            reader=mytiffreader(p.imagefile);
        numframes=reader.info.numberOfFrames;
     case 2
        reader=bfGetReader(p.imagefile);
        numframes=reader.getImageCount;
     case 3 %fiji
          ij=p.mij.imagej;
          ijframes=ij.getFrames;
          for k=1:length(ijframes)
            if strcmp(ijframes(k).class,'ij.gui.StackWindow')&&~isempty(ijframes(k).getImagePlus)    
                reader=ijframes(k).getImagePlus.getStack;
                break
            end
          end
          if ~exist('reader','var')
              p.status.String='Error... Check if image is loaded in ImageJ'; drawnow
              return
          end
%           numframes=reader.size;
          numframes=reader.getSize;
 end


if p.preview
    frames=min(p.previewframe,numframes);
else
    frames=1:numframes;
end

%loop over frames, do filtering/peakfinding
hgauss=fspecial('gaussian',max(3,ceil(3*p.peakfilter+1)),p.peakfilter);
rsize=max(ceil(6*p.peakfilter+1),3);
hdog=fspecial('gaussian',rsize,p.peakfilter)-fspecial('gaussian',rsize,max(1,2.5*p.peakfilter));
tshow=tic;

%if ~p.preview
% preload image stack to avoid double loading with multiple fovs
image_stack = get_image_stack(1:numframes, reader, p);

%if bgmode==4 %median background removal
    p.status.String=('Background removal, temporal median filter'); drawnow
    %bg_estimate = median(image_stack(:,:,1:3:end), 3, 'omitnan');
    bg_estimate = running_tempmedian(image_stack, 12);
    %bg_estimate = TemporalMedianFilterFullMovie(image_stack, 12);
    image_stack_bgfree = image_stack - bg_estimate;
    %image_stack(image_stack<0)=0;
%end 

clear results_all maxgood_all
% filter fov
for fov=1:size(p.fov_include, 1)
    bbox = p.fov_include(fov,:);
    %reset resultsindex and image coordinate index to not append coordinates across fovs before the
    %actual merging
    resultsind=1;
    indstack=0;
    for F=frames
        %if p.preview
        %    frameimage=getimage(F,reader,p);
        %else
            frameimage=image_stack(:,:,F);
            frameimage_bgfree=image_stack_bgfree(:,:,F);
        %end 
        
        %ADU 2 phot
        %whole frame, raw stack 
        imphot_frame =(single(frameimage)-p.offset)*p.conversion;
        %whole frame, background corrected stack 
        imphot_frame_bgfree =(single(frameimage_bgfree)-p.offset)*p.conversion;

        % crop fov
        imphot = imphot_frame(bbox(1):bbox(1)+bbox(3),bbox(2):bbox(2)+bbox(4)); %crop raw stack
        imphot_bgfree = imphot_frame_bgfree(bbox(1):bbox(1)+bbox(3),bbox(2):bbox(2)+bbox(4));%crop bgfree stack
        sim=size(imphot);
        %imphot=(single(image)-p.offset)*p.conversion;
        
        %peakfinder 
        if bgmode==3% wavelet
    %         bg=mywaveletfilter(imphot,3,false,true);
        elseif bgmode==1
            impf=filter2(hdog,sqrt(imphot_bgfree));
        elseif bgmode==0
            impf=filter2(hgauss,(imphot_bgfree));
        elseif bgmode==2 % no background removal
            impf=imphot_bgfree;
        else % no background removal
            impf=imphot_bgfree;
        end

        maxima=maximumfindcall(impf);

        if p.peakdynamic
            p.peakcutoff(fov) = getdynamiccutoff(maxima,p.peakdynamicfactor(fov)); 
        end 
        
        indmgood=maxima(:,3)>(p.peakcutoff(fov));
        indmgood=indmgood&maxima(:,1)>p.dx &maxima(:,1)<=sim(2)-p.dx;
        indmgood=indmgood&maxima(:,2)>p.dx &maxima(:,2)<=sim(1)-p.dx;
        maxgood=maxima(indmgood,:);
        
        if p.use_mindistance
            maxgood=maxgood(~tooclose(maxgood(:,1),maxgood(:,2),p.mindistance), :); % p.mindistance) & ~tooclose(,p.mindistance);
        end
        
        if p.preview && size(maxgood,1)>2000
            p.status.String=('increase cutoff');
            %return
        elseif p.preview && size(maxgood,1)==0
            p.status.String=('No localizations found, decrease cutoff');
            %return
        end
        
        %cut out images
        for k=1:size(maxgood,1)
            if maxgood(k,1)>p.dx && maxgood(k,2)>p.dx && maxgood(k,1)<= sim(2)-p.dx && maxgood(k,2)<=sim(1)-p.dx 
                indstack=indstack+1;
                if p.mirror
                    imstack(:,:,indstack)=imphot(maxgood(k,2)-p.dx:maxgood(k,2)+p.dx,maxgood(k,1)+p.dx:-1:maxgood(k,1)-p.dx);
                else
                    imstack(:,:,indstack)=imphot(maxgood(k,2)-p.dx:maxgood(k,2)+p.dx,maxgood(k,1)-p.dx:maxgood(k,1)+p.dx);
                end
                if p.isscmos
                    varstack(:,:,indstack)=varmap(maxgood(k,2)-p.dx:maxgood(k,2)+p.dx,maxgood(k,1)-p.dx:maxgood(k,1)+p.dx);
                end
                peakcoordinates(indstack,1:2)=maxgood(k,1:2);
                peakcoordinates(indstack,3)=F;
       
                if indstack==fitsperblock
                    p.status.String=['Fitting...' ]; drawnow
                    t=tic;
                    resultsh=fitspline(imstack,peakcoordinates,p,varstack);
                    fittime=fittime+toc(t);
                    
                    results(resultsind:resultsind+fitsperblock-1,:)=resultsh;
                    resultsind=resultsind+fitsperblock;
                    
                    indstack=0;
                end
            end
           
        end
        if toc(tshow)>1
            tshow=tic;
            p.status.String=['Loading FOV ' num2str(fov) '\' num2str(size(p.fov_include, 1)) ', frame ' num2str(F) ' of ' num2str(numframes)]; drawnow
        end
    end 

    closereader(reader,p);
    p.status.String=['Fitting last stack...' ]; drawnow
    t=tic;
    if indstack<1
        p.status.String=['No localizations found. Increase cutoff?' ]; drawnow

    end
    if p.isscmos
        varh=varstack(:,:,1:indstack);
    else
        varh=0;
    end
    
    try
        resultsh=fitspline(imstack(:,:,1:indstack),peakcoordinates(1:indstack,:),p,varh); %fit all the rest
        results(resultsind:resultsind+indstack-1,:)=resultsh;
    catch
        p.status.String=['Skipping localisation']; drawnow
        results = zeros(1,12,'double');
    end 
    fittime=fittime+toc(t);
    
    
    
    % add fov starting coordinates to results 
    results(:,[2, 7]) = results(:,[2, 7])+bbox(2)-1; 
    results(:,[3, 8]) = results(:,[3, 8])+bbox(1)-1;
    maxgood(:,1) = maxgood(:,1)+bbox(2)-1; % not sure about the -1 here, but candidates seem to be shifted by 1 in xy
    maxgood(:,2) = maxgood(:,2)+bbox(1)-1;
    %results(:,13) = results(:,13)+bbox(1)*p.pixelsize; 
    %results(:,14) = results(:,14)+bbox(2)*p.pixelsize;

    if exist('results_all','var')
        results_all = cat(1,results_all,results);
        maxgood_all = cat(1,maxgood_all, maxgood);
    else
        results_all = results;
        maxgood_all = maxgood;
    %results(n_locs:n_locs+resultsind)=results_fov;
    end
    clear results
end
results = results_all;
% preview window with peaks, coords and bounding boxes
if p.preview
    %figure(201)
    [~, baseFileName, ~] = fileparts(p.imagefile);
    if ~isfield(p,'tabgrouphandle')
        figure('Name',baseFileName)
    else
        t = uitab(p.tabgrouphandle,"Title",p.basefilename);
        axes = uiaxes(t, 'Position', [0, 0, 500, 500]);
    end
%     imagesc(impf.^2);
    preview_image=getimage(frames,reader,p);
    preview_image=single(preview_image)-bg_estimate(:,:,frames);
    imphot=(single(preview_image)-p.offset)*p.conversion;
    %background determination
    if bgmode==3% wavelet
%         bg=mywaveletfilter(imphot,3,false,true);
    elseif bgmode==1
         impf=filter2(hdog,sqrt(imphot));
    elseif bgmode==0
        impf=filter2(hgauss,(imphot));
    else % no background removal
        impf=imphot;
    end
    if ~isfield(p,'tabgrouphandle')
        imagesc(impf);
         colorbar
        hold on
        plot(maxgood_all(:,1),maxgood_all(:,2),'wo')
        plot(results_all(:,2),results_all(:,3),'k+')
        for fov=1:size(p.fov_include, 1)
            bbox = p.fov_include(fov,:);
            rectangle('Position',[bbox(2) bbox(1) bbox(4) bbox(3)])
        end 
        hold off
    else 
        imshow(impf, 'Parent', axes);
        colormap(hot)
        if any(maxgood_all)
             hold on
            plot(maxgood_all(:,1),maxgood_all(:,2),'wo')
            plot(results_all(:,2),results_all(:,3),'k+')
            for fov=1:size(p.fov_include, 1)
                bbox = p.fov_include(fov,:);
                rectangle('Position',[bbox(2) bbox(1) bbox(4) bbox(3)])
            end 
            hold off
        end 
    end 
   
    p.status.String=['Preview done. ' num2str(size(results,1)/fittime,'%3.0f') ' fits/s. ' num2str(size(results,1),'%3.0f') ' localizations.']; drawnow
else
    p.status.String=['Fitting done. ' num2str(size(results,1)/fittime,'%3.0f') ' fits/s. ' num2str(size(results,1),'%3.0f') ' localizations. Saving now.']; drawnow
    results(:,[13,15])=results(:,[2, 7])*p.pixelsize(1);
    results(:,[14,16])=results(:,[3, 8])*p.pixelsize(end);
    
    if p.isspline
        resultstable=array2table(results,'VariableNames',{'frame','x_pix','y_pix','z_nm','photons','background','crlb_x','crlb_y','crlb_z','crlb_photons','crlb_background','logLikelyhood','xnm','ynm','crlb_xnm','crlb_ynm'});
    else
        resultstable=array2table(results,'VariableNames',{'frame','x_pix','y_pix','PSFxnm','PSFynm','photons','background','crlb_x','crlb_y','crlb_photons','crlb_background','logLikelyhood','xnm','ynm','crlb_xnm','crlb_ynm'});
    end
    % 
    %writenames=true;
    %del=',';
    %writetable(resultstable,p.outputfile,'Delimiter',del,'FileType','text','WriteVariableNames',writenames);
    %p.status.String=['Fitting done. ' num2str(size(results,1)/fittime,'%3.0f') ' fits/s. ' num2str(size(results,1),'%3.0f') ' localizations. Saved.']; drawnow

     %% .mat saver

    resultstable.filenumber =  zeros(size(resultstable,1),1)+1;%p.filenumber;
    locdat = interfaces.LocalizationData;
    s=struct(table2struct(resultstable,"ToScalar",true));
    locdat.addLocData(s);

    locdat.P.globalSettings.saveas7.object=false;
    locdat.files.file(1).number=1; %p.filenumber;
    locdat.files.file.info.roi=[0 0 p.currentfileinfo.Width p.currentfileinfo.Height];
    locdat.files.file.info.pixsize=[p.pixelsize p.pixelsize];
    locdat.loc.locprecnm=sqrt((locdat.loc.crlb_x.\p.pixelsize+locdat.loc.crlb_y.\p.pixelsize)/2);
    p.saveTo=fullfile(p.outputfile);
    p.saveroi=false;
    excludesavefields={'groupindex','numberInGroup','colorfield', 'Row', 'Properties', 'Variables'};
    p.pluginpath={'SMLMsaver'};   
    savesml(locdat,p.saveTo,p,excludesavefields); 


end
end

function results=fitspline(imstack,peakcoordinates,p,varstack)
if p.isspline
    if p.bidirectional
        fitmode=5;
        zstart=[-300 300]/p.dz;
    else
        fitmode=5;
        zstart=0;
    end
    fitpar=single(p.coeff);
else
    if p.bidirectional
        fitmode=2;
        zstart=0;
    else
        fitmode=4;
        zstart=0;
    end
    fitpar=single(1);
end

%[Pcspline,CRLB,LL]=mleFit_LM(imstack,fitmode,50,fitpar,varstack,1,zstart);
[Pcspline,CRLB,LL]=GPUmleFit_LM(imstack,fitmode,50,fitpar,varstack,1,zstart);
results=zeros(size(imstack,3),12);
results(:,1)=peakcoordinates(:,3);
if  p.mirror
    results(:,2)=p.dx-Pcspline(:,2)+peakcoordinates(:,1);
else
    results(:,2)=Pcspline(:,2)-p.dx+peakcoordinates(:,1);
    
end


if p.isspline
    % frame, x,y,z,phot,bg, errx,erry, errz,errphot, errbg,logLikelihood
results(:,3)=Pcspline(:,1)-p.dx+peakcoordinates(:,2); %x,y in pixels 
results(:,4)=(Pcspline(:,5)-p.z0)*p.dz;
results(:,5:6)=Pcspline(:,3:4);
results(:,7:8)=real(sqrt(CRLB(:,[2 1])));
results(:,9)=real(sqrt(CRLB(:,5)*p.dz));
results(:,10:11)=real(sqrt(CRLB(:,3:4)));
results(:,12)=LL;
else
        % frame, x,y,sx,sy,phot,bg, errx,erry,errphot, errbg,logLikelihood
results(:,3)=Pcspline(:,1)-p.dx+peakcoordinates(:,2); %x,y in pixels 
results(:,4)=Pcspline(:,5);
if p.bidirectional
    results(:,5)=results(:,4);
else
    results(:,5)=Pcspline(:,6);
end
results(:,6:7)=Pcspline(:,3:4);

results(:,8:9)=real(sqrt(CRLB(:,[2 1])));

results(:,10:11)=real(sqrt(CRLB(:,3:4)));
results(:,12)=LL;
end

end

function img=getimage(F,reader,p)
    switch p.loader
        case 1
            img=reader.read(F);
        case 2
            img=bfGetPlane(reader,F);
        case 3        
            ss=[reader.getWidth reader.getHeight reader.getSize];
            if F>0&&F<=ss(3)
                pixel=reader.getPixels(F);
                img=reshape(pixel,ss(1),ss(2))';
            else
                img=[];
            end
    end

end

%% preload whole dataset to speed up loading operation
function imgs = get_image_stack(frames, reader, p)
imgs = zeros(p.currentfileinfo.Height, p.currentfileinfo.Width, p.currentfileinfo.Frames,'uint16');
    for F=frames
        %imgs = cat(3, imgs, getimage(F,reader,p));
        imgs(:,:,F)= getimage(F,reader,p);
    end 
end     




function closereader(reader,p)
switch p.loader
     case 1
         reader.close;
    case 2
    case 3        

end

end

% dynamic definition of peakfinder threshold instead of absolute photons
% derived from simpleSTORM script
function co=getdynamiccutoff(maxima,factor)
ps=[.2 .5 .8];
if size(maxima,1)<10
    if isempty(maxima)
        co=0;
    else
        co=mean(maxima(:,3))*factor;
    end
else
    
qs=myquantilefast(maxima(:,3),ps);
slope=(qs(3)-qs(1))/(ps(3)-ps(1));
co=qs(2)+slope*0.5*2*factor;
%co=qs(2)+slope*0.5*1.5*factor;
end
end