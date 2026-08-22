function summaryStats(data, path, fn, vis)
if nargin < 3
    fn = fieldnames(data);
end

% suppress display
if vis
    set(0,'DefaultFigureVisible','off');
end


%% per frame
frames = data.frame;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% batched processing
% 
% % Batch size
% batch_size = 100;
% 
% % Calculate mean and standard error for each unique frame
% for k = 1:numel(fn)
%     arr = data.(fn{k});
%     infarrs = ~isinf(arr);
%     arr_filt = arr(infarrs);
% 
%     % filter frames from inf arr values indices
%     arrframes = frames(infarrs);
% 
%     % Get the unique frames
%     uniqueFrames = unique(arrframes);
% 
%     % Calculate number of batches
%     numBatches = ceil(length(uniqueFrames) / batch_size);
% 
%     % Preallocate arrays for mean and standard error
%     meanValues = [];
%     stdErrorValues = [];
%     nlocs = [];
% 
%     for j = 1:numBatches
%         % Determine frames within the current batch
%         batch_start = (j - 1) * batch_size + 1;
%         batch_end = min(j * batch_size, length(uniqueFrames));
%         batchFrames = uniqueFrames(batch_start:batch_end);
% 
%         % Collect data for the frames in the current batch
%         batchData = [];
%         for i = 1:length(batchFrames)
%             frameIndex = arrframes == batchFrames(i);
%             frameData = arr_filt(frameIndex);
%             if isempty(batchData)
%                 batchData = frameData;
%             else 
%                 batchData = cat(1, batchData, frameData);
%             end 
%         end
% 
%         % Calculate mean and standard error for the batch
%         nlocs = [nlocs, length(batchData)];
%         meanValues = [meanValues, mean(batchData)];
%         stdErrorValues = [stdErrorValues, std(batchData) / sqrt(length(batchData))];
%     end
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Calculate mean and standard error for each unique frame
for k=1:numel(fn)
    arr = data.(fn{k});
    infarrs = ~isinf(arr);
    arr_filt = arr(infarrs);

    % filter frames from inf arr values indices
    arrframes = frames(infarrs);


    % Get the unique frames
    uniqueFrames = unique(arrframes);

    % Preallocate arrays for mean and standard error
    numUniqueFrames = length(uniqueFrames);
    meanValues = zeros(1, numUniqueFrames);
    stdErrorValues = zeros(1, numUniqueFrames);
    if k==1
        nlocs = zeros(1, numUniqueFrames);
    end 

    for i = 1:numUniqueFrames
       frameIndex = arrframes == uniqueFrames(i);
       frameData = arr_filt(frameIndex);
       nlocs(i) = length(frameData);
       meanValues(i) = mean(frameData);
       stdErrorValues(i) = std(frameData) / sqrt(length(frameData));

    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    f = figure;
    shadedErrorBar(uniqueFrames,meanValues, stdErrorValues,'lineprops','b'); 
    xlabel('Frame');
    ylabel(fn{k});
    title(fn{k});
    grid on;
    
    set(f,'Position',[100 100 700 500]);
    saveas(f, fullfile(path, append("stat_pf_",fn{k},".svg")));




    % plot locs per frame
    if k==1
        f = figure;
        plot(uniqueFrames, nlocs)
        xlabel('frame');
        ylabel('n_{locs}/frame');
        title(fn{k});
        grid on;
        
        set(f,'Position',[100 100 700 500]);
        saveas(f, fullfile(path, append("stat_locs_pf.svg")));

    end 

    %histogram
    f = figure;
    if isequal(fn{k}, 'ratio')
        arr = arr((arr>0.01) & (arr<1.01));
        histogram(arr, 100)
        xlim([-0.2, 1.2]);
        title(sprintf('%s, limit [0.01, 1.01], inf removed',fn{k}));

    else 
        topperc=95;
        bottomperc=5;
        histogram(arr)
        xlim([prctile(arr,bottomperc), prctile(arr,topperc)]);
        title(sprintf('%s, limit percentile [%d, %d ], inf removed',fn{k},bottomperc, topperc));

    end
    grid on;
 
    set(f,'Position',[100 100 700 500]);
    saveas(gcf, fullfile(path, append("stat_hist_",fn{k},".svg")));

end 

if isfield(data, 'intA1')
    f = figure;
    histogram2(data.intA1, data.intB1, 'DisplayStyle','tile','ShowEmptyBins','on');
    
    topperc=95;
    bottomperc=5;
    xlim([prctile(data.intA1,bottomperc), prctile(data.intA1,topperc)]);
    ylim([prctile(data.intB1,bottomperc), prctile(data.intB1,topperc)]);

    xlabel('intA1');
    ylabel('intB1');
    title('Bivariate intensity distribution across planes');

 
    set(f,'Position',[100 100 700 500]);
    saveas(gcf, fullfile(path, "bivariate_hist_int.svg"));

end 



if vis
% turn display on again
set(0,'DefaultFigureVisible','on')
end 
end