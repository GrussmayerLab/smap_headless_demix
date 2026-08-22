function med = running_tempmedian(stack,delta)
% temporal median using keyframe method, see
% https://www.nature.com/articles/srep03854 

if nargin < 2
    delta = 12;
end 
tdim = 3;
dims = [1 2 3];
xydim = dims(dims~=tdim);

frames=1:delta;
maxFrames=size(stack,tdim);
s=size(stack,[xydim(1) ,xydim(2)]);
allframes=transpose(linspace(1,maxFrames,maxFrames));
med=zeros(size(stack));
med_temp=zeros([s(1) s(2) ceil(maxFrames/delta)]);
%kernel = [1 1 delta];

mean_stack = squeeze(mean(stack, xydim));
norm_stack = stack ./ reshape(mean_stack,1,1,[]);
permuteorder=[3 1 2];
%[XI,YI]=meshgrid(1:xydim(1),1:xydim(2));
evalframes = [];
for F=1:delta:maxFrames

    frames = [ceil(max([frames(1),F])-delta\2),min([maxFrames,ceil(F+delta\2)])];
    evalframes = cat(1, evalframes, F);
    tempframes = norm_stack(:,:,frames(1):frames(2));

    if frames(1)< 1
        frames=frames+frames(1);
    elseif frames(2)>maxFrames
        frames=frames-(frames(2)-maxFrames);
    end 
    
    med_temp(:,:,floor(F/delta)+1) = reshape(fast_median(permute(tempframes, permuteorder)),s(1),s(2))*mean_stack(F);
end 

%interpolate pixelwise between sliding window
for ii=1:size(stack,xydim(1))
    for jj=1:size(stack,xydim(2))
        med(ii,jj,:)=interp1(evalframes,squeeze(med_temp(ii,jj,:)),allframes);
    end 
end

end 