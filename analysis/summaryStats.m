function summaryStats(data, path, fn, vis, p)
if nargin < 3
    fn = fieldnames(data);
end

if nargin < 4
    vis = false;
end

if nargin < 5
    p = {};
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
     arr = arr(infarrs);
%     arr_filt = arr(infarrs);
% 
%     % filter frames from inf arr values indices
%     arrframes = frames(infarrs);
% 
% 
%     % Get the unique frames
%     uniqueFrames = unique(arrframes);
% 
%     % Preallocate arrays for mean and standard error
%     numUniqueFrames = length(uniqueFrames);
%     meanValues = zeros(1, numUniqueFrames);
%     stdErrorValues = zeros(1, numUniqueFrames);
%     if k==1
%         nlocs = zeros(1, numUniqueFrames);
%     end 
% 
%     for i = 1:numUniqueFrames
%        frameIndex = arrframes == uniqueFrames(i);
%        frameData = arr_filt(frameIndex);
%        nlocs(i) = length(frameData);
%        meanValues(i) = mean(frameData);
%        stdErrorValues(i) = std(frameData) / sqrt(length(frameData));
% 
%     end
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     f = figure;
%     shadedErrorBar(uniqueFrames,meanValues, stdErrorValues,'lineprops','b'); 
%     xlabel('Frame');
%     ylabel(fn{k});
%     title(fn{k});
%     grid on;
% 
%     set(f,'Position',[100 100 700 500]);
%     saveas(f, fullfile(path, append("stat_pf_",fn{k},".svg")));
% 
% 
% 
% 
%     % plot locs per frame
%     if k==1
%         f = figure;
%         plot(uniqueFrames, nlocs)
%         xlabel('frame');
%         ylabel('n_{locs}/frame');
%         title(fn{k});
%         grid on;
% 
%         set(f,'Position',[100 100 700 500]);
%         saveas(f, fullfile(path, append("stat_locs_pf.svg")));
% 
%     end 
    


    %histogram
    f = figure;
    if isequal(fn{k}, 'ratio')
        upperlim =10;
        arr = arr((arr>0.01) & (arr<upperlim));
        
        % if photon ratios are available, color in which ratios belong to
        % which color
        if isfield(p, 'photon_ratios')
            colors = ["#4DBEEE", "#A2142F", "#000000", "#EDB120", "#D95319"];
            ratios =p.photon_ratios;
            
            upperlim =max(ratios, [],'all');
            arr = arr((arr>0.001) & (arr<upperlim));

            for c=1:length(ratios) 
                ratio_bin = ratios(c,[1 2]);
                bin_edges = ratio_bin(1):.01:ratio_bin(2);

                mask = arr((arr>ratio_bin(1)) & (arr<ratio_bin(2)));
                histogram(mask, bin_edges, 'FaceColor',colors(c), 'EdgeColor', 'none');
                hold on
            end 
            
            bin_edges = 0:.01:upperlim;
            histogram(arr, bin_edges, 'FaceAlpha', 0.1)
            xlim([-0.1, upperlim]);
        
        end 


        title(sprintf('%s, limit [0.001, %d], inf removed',fn{k}, upperlim));
    
    elseif isequal(fn{k}, 'frame')
        histogram(arr)
        title('Locs per frame');
    else 
        topperc=95;
        bottomperc=5;
        bottomval =prctile(arr,bottomperc);
        topval =prctile(arr,topperc);

        arr = arr((arr>bottomval) & (arr<topval));
        bin_edges = bottomval:.01:topval;
        histogram(arr, bin_edges, 'EdgeColor', 'none')
        %xlim([prctile(arr,bottomperc), prctile(arr,topperc)]);
        title(sprintf('%s, limit percentile [%d, %d ], inf removed',fn{k},bottomperc, topperc));

    end
    grid on;
 
    set(f,'Position',[100 100 700 500]);
    saveas(gcf, fullfile(path, append("stat_hist_",fn{k},".svg")));

end 

if isfield(data, 'intA1')
    f = figure;

    A1 = data.intA1;
    infarrs = ~isinf(A1);
    A1 = A1(infarrs);

    B1 = data.intB1;
    infarrs = ~isinf(B1);
    B1 = B1(infarrs);

    %h = histogram2(A1, B1, 'DisplayStyle','tile','ShowEmptyBins','on');

    %nbins= [round((max(A1) - min(A1))/20)  round((max(B1) - min(B1))/20)];
    %h.NumBins = nbins;
    
    scatter(A1, B1,1,'.'); %scatter with points, size 1, maybe prefer pdf?
    topperc=95;
    bottomperc=1;
    xlim([prctile(A1,bottomperc), prctile(A1,topperc)]);
    ylim([prctile(B1,bottomperc), prctile(B1,topperc)]);
    
    xlabel('intA1');
    ylabel('intB1');
    title('Bivariate photon count distribution');

 
    set(f,'Position',[100 100 700 500]);
    saveas(gcf, fullfile(path, "bivariate_hist_int.svg"));

end 



if vis
% turn display on again
set(0,'DefaultFigureVisible','on')
end 
end