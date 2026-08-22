function loco=get2Clocintensities_ME(loc,transform,file,p)

 p.datapart.selection='all';
loct=apply_transform_locs(loc,transform,file,p);
indref=transform.getRef(loc.xnm,loc.ynm);
indreff=find(indref);
indtarf=find(~indref);

locr=copystructReduce(loc,indref);
loctr=copystructReduce(loct,~indref);

[iA,iB,uiA,uiB]=matchlocsall(renamefields(locr),renamefields(loctr),0,0,200); 

iA=indreff(iA);
iB=indtarf(iB);
uiA=indreff(uiA);
uiB=indtarf(uiB);

%loco.intA1=zeros(size(loc.xnm),'single')-100;
%loco.intB1=zeros(size(loc.xnm),'single')-100;
loco.intA1=zeros(size(loc.xnm),'single');
loco.intB1=zeros(size(loc.xnm),'single');
loco.intA1(iA)=loc.phot(iA);
loco.intB1(iA)=loc.phot(iB);
loco.intA1(iB)=loc.phot(iA);
loco.intB1(iB)=loc.phot(iB);

loco.xnm_r=zeros(size(loc.xnm),'single');
loco.ynm_r=zeros(size(loc.xnm),'single');
loco.xnm_t=zeros(size(loc.xnm),'single');
loco.ynm_t=zeros(size(loc.xnm),'single');

loco.xnm_r(iA)=loc.xnm(iA);
loco.ynm_r(iA)=loc.ynm(iA);

loco.xnm_t(iA)=loct.xnm(iB); % transformed coordinates
loco.ynm_t(iA)=loct.ynm(iB); 

% unassigned, changed to include unmatched locs, remove if causing issues
loco.xnm_r(uiA)=loc.xnm(uiA);
loco.ynm_r(uiA)=loc.ynm(uiA);

loco.xnm_r(uiB)=loc.xnm(uiB);
loco.ynm_r(uiB)=loc.ynm(uiB);

loco.xnm_t(uiA)=loc.xnm(uiA);
loco.ynm_t(uiA)=loc.ynm(uiA);

loco.xnm_t(uiB)=loc.xnm(uiB);
loco.ynm_t(uiB)=loc.ynm(uiB);


% keep in
loco.intA1(uiA)=1; %loc.phot(uiA);
loco.intB1(uiA)=0; %loc.phot(uiA);
loco.intA1(uiB)=0; %=0; %loc.phot(uiB);
loco.intB1(uiB)=1; %=0; %loc.phot(uiB);

%loco.intA1(uiA)=0;
%loco.intB1(uiB)=0;

loco = weighted_merge_locs(loco, p);


function loco=renamefields(loci)
    loco.x=loci.xnm;
    loco.y=loci.ynm;
    loco.frame=loci.frame;


function loco=weighted_merge_locs(loci, p)
    loco.xnm_merge=zeros(size(loci.xnm_r),'single');
    loco.ynm_merge=zeros(size(loci.xnm_r),'single');
    
    if p.assignfield1.Value==1
        p.assignfield1.selection='intB1';
        p.assignfield2.selection='intA1';
    end
    
    field1=p.assignfield1.selection;
    field2=p.assignfield2.selection;
    r = loci.(field1)./loci.(field2);
    loco.xnm_merge= (loci.xnm_t./ (1+r))+ (r.*loci.xnm_r./(1+r));
    loco.ynm_merge= (loci.ynm_t./ (1+r))+ (r.*loci.ynm_r./(1+r));
    
    loco.intA1=loci.intA1; 
    loco.intB1=loci.intB1; 
