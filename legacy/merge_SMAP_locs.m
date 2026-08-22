clear
% Define the folder where your MAT files are located
matFilesFolder = 'C:\Users\mengelhardt\data\local\ME019\locs';

% List all MAT files in the folder
matFiles = dir(fullfile(matFilesFolder, '*.mat'));

% Remove the .mat extension
[~, baseFileName, ~] = fileparts(matFiles(1).name);

% Add "_merge_sml.mat" to the base file name
% Define the name for the output MAT file
newFileName = strrep(baseFileName, 'sml', 'merge_sml');

% Initialize an empty table to store the appended data
appendedData = struct();

fileCount = 1;

% Loop through each MAT file
for fileIdx = 1:numel(matFiles)
    % Load the MAT file
    matFileName = fullfile(matFilesFolder, matFiles(fileIdx).name);
    load(matFileName);
    
    % Check if 'saveloc' variable exists
    if exist('saveloc', 'var') == 1
        % Read the 'saveloc' structure
        savelocData = saveloc.loc;
        if fileCount == 1
            appendedData = savelocData;
        else
            % Loop through all fields in the 'saveloc' structure
            fieldNames = fieldnames(savelocData);
            for fieldIdx = 1:numel(fieldNames)
                fieldName = fieldNames{fieldIdx};
            
                % update the 'frame' field by adding maximum counted frames until now
                if strcmp(fieldName, 'frame')
                    maxframe = max(appendedData.(fieldName));
                    savelocData.(fieldName) = savelocData.(fieldName) + maxframe;
                end

                % update the 'file' field to determine file that the loc was in
                if strcmp(fieldName, 'field')
                    fileCount = max(appendedData.(fieldName));
                    savelocData.(fieldName) = savelocData.(fieldName) + fileCount;
                end

                 % Check if the field exists in the appended data struct
                if isfield(appendedData, fieldName)
                    % Append the data to the existing field
                    appendedData.(fieldName) = [appendedData.(fieldName); savelocData.(fieldName)];
                else
                    % Create the field in the appended data struct
                    appendedData.(fieldName) = savelocData.(fieldName);
                end
            end
        end
    end
    fileCount = fileCount+1;
    
end

maxframe = max(appendedData.('frame'));

% create the output struct from input file
file_old = load(fullfile(matFilesFolder, matFiles(1).name));

out=struct('saveloc',file_old.saveloc,'fileformat',file_old.fileformat,'parameters',file_old.parameters);
out.saveloc.loc = appendedData;

% update some info on the file
out.saveloc.file.info.numberOfFrames = maxframe;
out.saveloc.file.name = append(newFileName, '.mat');


%save(newFileName, "-struct","file");
%save(matFiles(1).name, "-struct","file");
%save(matFiles(1).name, "-struct","file", "-v7");
ver="-v7";
v=saverightversion(append(newFileName, '.mat'),out,ver);
    disp(['saved as version ' v])

% Display a message indicating the process is complete
fprintf('Appended data saved to %s\n', newFileName);