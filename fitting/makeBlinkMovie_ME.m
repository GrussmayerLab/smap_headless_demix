function makeBlinkMovie_ME(path, p)

fprintf('Creating blink movie for folder %s \n', path)
outputfolder = fullfile(path, 'movie'); 
if ~exist(outputfolder, 'dir')
   mkdir(outputfolder)
end

if p.csv_import
    fileend ='.csv';
else 
    fileend ='.mat';
end 

% List all loc files in the folder
matfiles = dir(fullfile(path, ['*_sml' fileend]));
matfiles = natsortfiles(matfiles);

% List all img files in the folder
imagefiles = dir(fullfile(path, '*.tif'));
% TODO check tiff as well
imagefiles = natsortfiles(imagefiles);

if numel(matfiles) ~= numel(imagefiles)
    fprintf('Trying to match %d locfiles to %d imagefiles, might skip some', numel(matfiles), numel(imagefiles))
end 

if isfield(p, 'blinkmovie_filerange')
    filerange=p.blinkmovie_filerange;   
else 
    filerange=1:min([numel(matfiles),numel(imagefiles)], [], 'all');
end 

if isfield(p, 'blinkmovie_framemin')
    framerange=p.blinkmovie_framemin:p.blinkmovie_framemin+p.blinkmovie_numberOfFrames;
else 
    framerange=1:100;
end 

if ~isfield(p, 'framerate')
    p.framerate=1;
end 


gaussfac=0.7;
%pix_cam=filestruc.info.cam_pixelsize_um*1000;
pix_cam=[p.pixelsize, p.pixelsize];

%roi=filestruc.info.roi;
p.sr_pixrec=108;%nm


% preload 1 frame to get spacing
%imgfname = fullfile(path, imagefiles(1).name);
%reader=bfGetReader(imgfname);

%frame=double(bfGetPlane(reader,1))';
%[w, h] = size(frame);

for ff=filerange
% try

    % load locs
    locfname = fullfile(path, matfiles(ff).name);
    loc = load(locfname);
    loc = loc.saveloc.loc;
    
    % filter locs for outliers
    %proc = {};
    %proc.check_xnm = true;  proc.val_xnm = [0, w*p.sr_pixrec];
    %proc.check_ynm = true; proc.val_ynm = [0, h*p.sr_pixrec];
    
    %loc = filterlocs(loc, proc);
    
    
    % 
    roi= [min(loc.xnm, [], 'all'),  min(loc.ynm, [], 'all'), ...
    max(loc.xnm, [], 'all'), max(loc.ynm, [], 'all')];
    
    p.sr_size=[(max(loc.xnm, [],'all')-min(loc.xnm, [],'all'))/2, ...
        (max(loc.ynm, [],'all')-min(loc.ynm, [],'all'))/2];

    p.sr_pos=[min(loc.xnm, [],'all')+p.sr_size(1), ...
        min(loc.ynm, [],'all')+p.sr_size(2)];

    %function internal process file
    
    pfile.path=outputfolder;
    pfile.bufferSize=200;

    sr=round(2*pix_cam(1)/p.sr_pixrec);
    rx=round(((p.sr_pos(1)-p.sr_size(1))/p.sr_pixrec:(p.sr_pos(1)+p.sr_size(1))/p.sr_pixrec));
    ry=round(((p.sr_pos(2)-p.sr_size(2))/p.sr_pixrec:(p.sr_pos(2)+p.sr_size(2))/p.sr_pixrec));
    
    pos.x=loc.xnm;pos.y=loc.ynm;pos.s=max(loc.locprecnm*gaussfac,p.sr_pixrec/2);
    rangex=[p.sr_pos(1)-p.sr_size(1) p.sr_pos(1)+p.sr_size(1)];
    rangey=[p.sr_pos(2)-p.sr_size(2) p.sr_pos(2)+p.sr_size(2)];
    
    [srimfinal,nlocs,G]=gaussrender(pos,rangex, rangey, p.sr_pixrec, p.sr_pixrec);
    
    srimadd=0*srimfinal;
    average=0;
    
    ssr=size(srimfinal);
    %ax1=initaxis(p.resultstabgroup,'running movie');
    % ax2=initaxis(p.resultstabgroup,'final');
    %axes(ax1)
    
    frames=framerange;

    ind=strfind(path,filesep);
    p2=path(1:ind(end-1));

    ext='.mp4';

    outfilename = strrep(matfiles(ff).name, fileend, ext);
    outfile=fullfile(outputfolder, outfilename);

    p.outputFormat.selection = 'MPEG-4';
    aviobj=VideoWriter(outfile,p.outputFormat.selection);
    
    aviobj.FrameRate=p.framerate;
    open(aviobj);
    
    %initialise image reader
    imgfname = fullfile(path, imagefiles(ff).name);
    reader=bfGetReader(imgfname);

    % render loc image
    sumcollage = [];
    for k=frames
        ind=find(loc.frame==k);
        if ~isempty(ind)
            pos.x=loc.xnm(ind);pos.y=loc.ynm(ind);pos.s=max(loc.locprecnm*gaussfac,p.sr_pixrec);
            srimhere=gaussrender(pos,rangex, rangey, p.sr_pixrec, p.sr_pixrec,[],[],G);
            srimadd=srimadd+srimhere;
    
            
            % imgs =zeros(p.currentfileinfo.Height, p.currentfileinfo.Width, framerange(2)-framerange(1),'uint16');
            % for F=framerange
            %     %imgs = cat(3, imgs, getimage(F,reader,p));
            %     imgs(:,:,F-framerange(1)+1)= getimage(F,reader,p);
            % end 
    
            imf=double(bfGetPlane(reader,k))';
            
            if ~isempty(imf)
    
                imb=imresize(imf,pix_cam(1)/p.sr_pixrec,'nearest');
                %imcut=imb(rx(rx>0),ry(ry>0)); %imb(rx,ry); ME change 
                imcut=imb;
                
                imcut=imcut-min(imcut(:));
                imcut=imcut/myquantile(imcut(:),0.99995);
                
                average=imcut+average;
                
                
                xp=(loc.xnm(ind)-p.sr_pos(1)+p.sr_size(1))/p.sr_pixrec;
                yp=(loc.ynm(ind)-p.sr_pos(2)+p.sr_size(2))/p.sr_pixrec;
                ims=plotsquares(imcut,xp,yp,sr,ssr);
                
                sumcollage = cat(4,sumcollage,ims);
                collage=makecollage(srimadd,ims);
    
                collage=uint8(collage*255);
                
                writeVideo(aviobj,collage);
                % write(tifobj,uint8(collage*255));
                % indmov=indmov+1;
    
            end
        end
    end

averageout=plotsquares(average,[],[],sr,ssr);
averageout=averageout-min(averageout(:));

% axes(ax2);
collage=makecollage(srimfinal/max(srimfinal(:))*3,averageout/myquantile(averageout(:),0.99997));
close(aviobj);
% tifobj.close();
imwrite(collage,[outfile(1:end-4) '_all.tif'])

%sumcollage=permute(sumcollage,[2 1 4 3]);
sumcollage = squeeze(sumcollage(:,:,1,:));
bfsave(sumcollage,[outfile(1:end-4) '_sumcollage.tif'], 'BigTiff', true)
%reader.close;

% catch
%     fprintf('Skipping movie creation in %d \n', ff);
% end 

end 






function collage=makecollage(srimage,dlimage)
ssr=size(srimage);
%norm=max(myquantile(srimage(:),0.9995));
norm=max(myquantile(srimage(:),0.9));
srimplot=srimage/norm;
srimplot(srimplot>1)=1;
srimplot(1,1)=1;
lut=hot(257);
srimplotrgb=ind2rgb(ceil(srimplot*255+1),lut);

collage=zeros(ssr(1),ssr(2)*2,3);
for c=1:3
    collage(:,1:ssr(2),c)=dlimage(:,:,c)';
    collage(:,ssr(2)+1:2*ssr(2),c)=srimplotrgb(:,:,c);
end
collage(collage>1)=1;

function imoutf=plotsquares(image,x,y,sr,ssr)
s=size(image);
badind=x<1|x>s(1)|y<1|y>s(2);
x(badind)=[];
y(badind)=[];
imout=zeros(s(1)+2*sr+4,s(2)+2*sr+4,3);
sim=size(image);
for k=1:3
    imout(sr+1:sr+sim(1),sr+1:sr+sim(2),k)=image;
end
x=round(x+sr);
y=round(y+sr);
sc=5;
for loc=1:length(x)
    imout(x(loc)-sr:x(loc)+sr,y(loc)+sr,1:3)=1;
    imout(x(loc)-sr:x(loc)+sr,y(loc)-sr,1:3)=1;
    imout(x(loc)+sr,y(loc)-sr:y(loc)+sr,1:3)=1;
    imout(x(loc)-sr,y(loc)-sr:y(loc)+sr,1:3)=1;
%     
%     imout(x(loc)-sc:x(loc)+sc,y(loc),:)=0;
%     imout(x(loc),y(loc)-sc:y(loc)+sc,:)=0;
%         imout(x(loc)-sc:x(loc)+sc,y(loc),1)=1;
%     imout(x(loc),y(loc)-sc:y(loc)+sc,1)=1;
end

imoutf=imout(sr+1:sr+ssr(2),sr+1:sr+ssr(1),:);







