%original script from KIT, recieved bz miyase tekpinar 
% adapted by Mority engelhardt, TU Delft, Grussmayer Lab
%bin the localization data with pixel
%input:
%1) loc: col1 x, col2 y, col3 sig_x, col4 sig_y(cam px unit)
%2) pixel: pixel size of the blurred image
%3) height of the raw image
%4) width of the raw image
%output: img: gaussian blurred image
%==========================================================================
function img = loc_gauss_std_blur(loc, pixel, std_bin, height, width)
pixel = 1 / pixel;
img = single(zeros(floor(pixel .* height) + 1, ...
    floor(pixel .* width + 1)));
loc_tmp = round(loc(:, 1 : 2) .* pixel);
loc = loc(loc_tmp(:, 1) > 0 & loc_tmp(:, 1) <= size(img, 1) & ...
    loc_tmp(:, 2) > 0 & loc_tmp(:, 2) <= size(img, 2), :);
img_tmp = img;
std_lower = 0;
std_upper = 75;
for std = std_lower : std_bin : std_upper
   loc_good = find(mean(loc(:, 3 : 4), 2) <= std + std_bin & ...
       mean(loc(:, 3 : 4), 2) > std);
   if ~isempty(loc_good)
       ind = round(pixel .* loc(loc_good, 1)) + ...
           size(img, 1) .* round(pixel .* loc(loc_good, 2) - 1);
       img_tmp(ind) = 1;
       h = fspecial('gaussian', [7, 7], pixel .* (std + std_bin - 1));
       img_tmp = imfilter(img_tmp, h);
       img = img + single(img_tmp);
       img_tmp = 0.* img_tmp;
   end
end
end