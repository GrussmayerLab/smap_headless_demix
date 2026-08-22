function T = merge_SMAP_locs_mat(path, p)
   %path: path to the folder containign localisation csv files
    fprintf('Merging localisations in %s ', path)
    clear T

    outputfolder = strcat(path, '\merge'); 

    if ~exist(outputfolder, 'dir')
       mkdir(outputfolder)
    end

    % List all sml.mat files in the folder
    matFiles = dir(fullfile(path, '*_sml.mat'));
    %matFiles = natsortfiles(matFiles); % ignores the first file without index
    numbers=cellfun(@extract_number,{matFiles.name});
    [~,order]=sort(numbers);
    matFiles=matFiles(order);
    
    % Remove the .mat extension
    [~, baseFileName, ~] = fileparts(matFiles(1).name);
    
    % Add "_merge_sml.mat" to the base file name
    % Define the name for the output MAT file
    newFileName = strcat(baseFileName, '_merge');
    
    % Initialize an empty locdata to store the appended data
    max_frame = 0;

    locdat = interfaces.LocalizationData;    
    locdat.P.globalSettings.saveas7.object=false;
    locdat.files.file(1).number=1;
    p.saveroi=false;
    excludesavefields={'groupindex','numberInGroup','colorfield', 'Row', 'Properties', 'Variables'};
    p.pluginpath={'SMLMsaver'};   
    
    
    % Loop through each csv file
    for fileIdx = 1:numel(matFiles)
        % Load the csv file
        matFileName = fullfile(path, matFiles(fileIdx).name);
        loc_s = load(matFileName);
        T_temp = loc_s.saveloc.loc;



        %T_temp.filenumber= zeros(height(T_temp),1)+fileIdx;
        T_temp.frame = T_temp.frame+max_frame;
        % check if znm is in table and create if not
        if ~isfield(T_temp, 'znm')
            T_temp.znm= zeros(height(T_temp)-1,1);
        end 

        % check if locprecnm exists 
        if ~isfield(T_temp, 'locprecnm')
            T_temp.locprecnm= sqrt((T_temp.crlb_x.*p.pixelsize^2+T_temp.crlb_y.*p.pixelsize^2)/2);
        end 

        % check if channel exists 
        if ~isfield(T_temp, 'channel')
            T_temp.channel= zeros(height(T_temp)-1,1);
        end 
        
        % check photon channel name (needs to be phot) 
        if ~isfield(T_temp, 'phot')
            T_temp.phot= T_temp.photons;
            T_temp = rmfield(T_temp,'photons');
        end 

            % check bkg channel name (needs to be phot) 
        if ~isfield(T_temp, 'bg')
            T_temp.bg= T_temp.background;
            T_temp = rmfield(T_temp,'background');
        end 

        if exist('T', 'var')
            fn =fieldnames(T);
            for k=1:length(fn)
                T.(fn{k})=cat(1,T.(fn{k}),T_temp.(fn{k}));
            end 
       
            %T = [T;T_temp];
        else 
            T = T_temp;
        end 
        max_frame = max(T.frame);
    end

    outputfilepath = fullfile(outputfolder, append(newFileName, '.mat'));
    locdat.files.file.info = struct();
    locdat.files.file.info.roi=[0 0 p.currentfileinfo.Width p.currentfileinfo.Height];
    locdat.files.file.info.pixsize=[p.pixelsize p.pixelsize];
    %writetable(T, outputfilepath)
    locdat.addLocData(T);
    p.saveTo=outputfilepath;
    savesml(locdat,p.saveTo,p,excludesavefields);

    % Display a message indicating the process is complete
    fprintf('Appended data saved to %s\n', outputfilepath);
end





function val=extract_number(str)
try
tokens=regexp(str,'_(\d*)_sml.mat','tokens');
val=str2double(tokens{end}{end});
catch
    val = 0;
end 
end