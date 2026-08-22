%% stitch two stacks next to each other with a small frame around
bioformats_path='E:\Program Files\bfmatlab';
addpath(bioformats_path);
% filenames
%rootpath='D:\Tim\TF001\test';
%r_name = fullfile(rootpath, "r_channel_div2.tif");
%t_name = fullfile(rootpath, "t_channel.tif");

rootpath='D:\Tim\TF001\test_af647_divs';
outpath = fullfile(rootpath, 'stitched/');
r_files = dir(fullfile(rootpath, 'r_*.*'));
t = "t_.tif";


for r_idx=1:length(r_files)  
    %r = "r_div2.tif";
    r = r_files(r_idx).name;
    r_name = fullfile(rootpath, r);
    t_name = fullfile(rootpath, t);
    
    
    
    % reflection stack 
    reader=bfGetReader(char(r_name));
    rFrames=reader.getSizeZ;
    rHeight=reader.getSizeY;
    rWidth=reader.getSizeX;
    rstack = zeros(rHeight, rWidth, rFrames);
    
    for rf = 1:rFrames
        rstack(:,:,rf)= bfGetPlane(reader,rf);
    end 
    
    
    % transmission stack 
    reader=bfGetReader(char(t_name));
    tFrames=reader.getSizeZ;
    tHeight=reader.getSizeY;
    tWidth=reader.getSizeX;
    tstack = zeros(tHeight, tWidth, tFrames);
    
    for tf = 1:tFrames
        tstack(:,:,tf)= bfGetPlane(reader,tf);
    end 
    
    % create final stack with a bit of buffer 
    final_stack = zeros(tHeight+10, 2*(tWidth+10), tFrames, "int16");
    
    for tf = 1:tFrames
        final_stack(5:tHeight+4,5:tWidth+4,tf)= tstack(:,:,tf) ;
        final_stack(5:tHeight+4,tWidth+15:2*tWidth+14,tf)= rstack(:,:,tf) ;
    end 
    %close reader
    reader.close()
    
    outfile = strcat('merge_t_', r);
    % write image 
    %bfsave(final_stack, char(fullfile(rootpath, "merge.tif")), 'dimensionOrder', 'XYTCZ', 'BigTiff', true)
    bfsave(final_stack, char(fullfile(outpath, outfile)), 'dimensionOrder', 'XYTCZ', 'BigTiff', true)
    %bfsave(final_stack, char(fullfile(rootpath, "merge.tif")))
    
    fprintf('merging done\n');
end 
