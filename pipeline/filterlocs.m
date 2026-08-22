% filter locs in localization data interface by smap
function locsout=filterlocs(locs, p)

    indin=true(size(locs.frame));
    %locprec
    if isfield(p, 'check_locprec') && p.check_locprec
        val=p.val_locprec;
        locprec = locs.locprecnm;
        indinh=locprec>=val(1)&locprec<=val(2);
        indin=indin&indinh;
    end


    %xnm
    if isfield(p, 'check_xnm') && p.check_xnm
        val=p.val_xnm;
        xnm = locs.xnm;
        indinh=xnm>=val(1)&xnm<=val(2);
        indin=indin&indinh;
    end

    %ynm
    if isfield(p, 'check_ynm') && p.check_ynm
        val=p.val_ynm;
        ynm = locs.ynm;
        indinh=ynm>=val(1)&ynm<=val(2);
        indin=indin&indinh;
    end
    
    %PSFxnm
    if isfield(p, 'check_psf') && p.check_psf && isfield(locs,'PSFxnm')
        %if isfield(locs,'PSFynm')
        %    psfnm = mean([locs.PSFxnm locs.PSFynm]);
        %else
            psfnm =locs.PSFxnm;
       % end 
        val=p.val_psf;
        indinh=psfnm>=val(1)&psfnm<=val(2);
        indin=indin&indinh;
    end
    
    %phot
    if isfield(p,'check_phot') && p.check_phot && isfield(locs,'phot')
        phot=locs.phot;
        val=p.val_phot;
        if length(val)==1
            val=[val inf];
        end
        indinh=phot>=val(1)&phot<=val(2);
        indin=indin&indinh;
    end 

        %bg
    if isfield(p,'check_bg') && p.check_bg && isfield(locs,'bg')
        bg=locs.bg;
        val=p.val_bg;
        if length(val)==1
            val=[0 val];
        end
        indinh=bg>=val(1)&bg<=val(2);
        indin=indin&indinh;
    end 
    
    %LL
    if isfield(locs,'check_LL') && p.check_LL && isfield(locs,'logLikelihood')
        ll=locs.logLikelihood;
        
        val=p.val_LL*p.loc_ROIsize^2/2;

        indinh=ll>=val;
        indin=indin&indinh;
    end 

     %remove all locs that contain NaN
    fn=fieldnames(locs);
    for k=1:length(fn)
        indin(isnan(locs.(fn{k})))=false;
%                     sum(isnan(locs.(fn{k})))
    end    
                
    for k=1:length(fn)
        locsout.(fn{k})=locs.(fn{k})(indin);
    end                
                