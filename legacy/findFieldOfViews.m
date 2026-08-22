function bboxs = findFieldOfViews(imageStack, show_fovs, offset)
    % Calculate the median image along the third dimension
    medianImage = median(imageStack, 3, 'omitnan');

    % get dimensions of image input
    % size and bounding box dimensions are flipped, so argmin, argmax are
    % assigned flipped
    [N_large, argmin] = max(size(medianImage));
    [N_small, argmax] = min(size(medianImage));
    
    % processing 
    medianImage = medianImage-min(medianImage);
   %medianImage = adapthisteq(medianImage, 'ClipLimit',0.7); %'NumTiles',[8 8], 'Distribution','rayleigh'
    %medianImage=imadjust(medianImage);
    %medianImage = mean(imageStack, 3, 'native');
    
    
    % Apply Gaussian blur to reduce noise and improve edge detection
    blurred = imgaussfilt(medianImage, 2);

    % Use edge detection to find edges in the image
    edges = edge(blurred, 'Canny');
    
    % Create a figure to display the original median image
    if show_fovs
        figure;
        imshow(blurred, []);
        hold on;
    end
    
    % Find connected components in the binary image
    cc = bwconncomp(edges);

    % Get region properties for connected components
    stats = regionprops(cc); % , 'BoundingBox', 'Area', 'PixelValues'

    bboxs = [];
    % Iterate through the region properties and identify fields of view
    for i = 1:length(stats)
        n_large = stats(i).BoundingBox(2+argmax);
        n_small = stats(i).BoundingBox(2+argmin);
               
        if n_large < N_large / 2 && n_large > N_large / 4 && n_small < N_small  && n_small > N_small / 2
        
            rectangle('Position', stats(i).BoundingBox, 'EdgeColor', 'r', 'LineWidth', 2);
            t_bbox=stats(i).BoundingBox;
            bboxs=cat(1, bboxs, [int(t_bbox(2)),int(t_bbox(1)),int(t_bbox(4)),int(t_bbox(3))]);
            %bboxs=cat(1, bboxs, t_bbox);
        
        
        end 
    end
    if show_fovs
         % Display the original median image with rectangles
        hold off;
        title('Identified Fields of View (Median Image)');
    end
   
   % reshape (better do it outside of the function
   % bboxs = reshape(bboxs,[2 4]);
end