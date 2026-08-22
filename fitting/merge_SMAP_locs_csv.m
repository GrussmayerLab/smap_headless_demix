function T = merge_SMAP_locs_csv(path, p)
   %path: path to the folder containign localisation csv files
    fprintf('Merging localisations in %s ', path)
    clear T
    outputfolder = strcat(path, '\merge'); 
    if ~exist(outputfolder, 'dir')
       mkdir(outputfolder)
    end
    if exist('p', 'var')
        p.locoutputfilepath =outputfolder;
    end
    % List all csv files in the folder
    matFiles = dir(fullfile(path, '*.csv'));
    %matFiles = natsortfiles(matFiles);
    numbers=cellfun(@extract_number,{matFiles.name});
    [~,order]=sort(numbers);
    matFiles=matFiles(order);
    
    
    % Remove the .mat extension
    [~, baseFileName, ~] = fileparts(matFiles(1).name);
    
    % Add "_merge_sml.mat" to the base file name
    % Define the name for the output MAT file
    newFileName = strcat(baseFileName, '_merge');
    
    % Initialize an empty table to store the appended data
    max_frame = 0;
    
    
    % Loop through each csv file
    for fileIdx = 1:numel(matFiles)
        % Load the csv file
        matFileName = fullfile(path, matFiles(fileIdx).name);
        T_temp = readtable(matFileName, 'VariableNamingRule', 'preserve');
        T_temp.filenumber= zeros(height(T_temp),1)+fileIdx;
        T_temp.frame = T_temp.frame+max_frame;
        % check if znm is in table and create if not
        if ~any("znm" == string(T_temp.Properties.VariableNames))
            T_temp.znm= zeros(height(T_temp),1);
        end 

        if exist('T', 'var')
            T = [T;T_temp];
        else 
            T = T_temp;
        end 
        
        max_frame = max(T.frame);
        
    end
    outputfilepath = fullfile(outputfolder, append(newFileName, '.csv'));

    writetable(T, outputfilepath)
    
    % Display a message indicating the process is complete
    fprintf('Appended data saved to %s\n', outputfilepath);
end


function val=extract_number(str)
try
tokens=regexp(str,'_(\d*)_csv.mat','tokens');
val=str2double(tokens{end}{end});
catch
    val = 0;
end 
end