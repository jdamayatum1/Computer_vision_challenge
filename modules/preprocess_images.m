function preprocessedImages = preprocess_images(folder_path)
% PREPROCESS_IMAGES - Loads and processes satellite images from a folder.
%
% Input:
%   folder_path - Path to folder with images (format: 'DDMMYYYY.jpg')
%
% Output:
%   preprocessedImages - Struct array with fields:
%       .name  - file name
%       .image - preprocessed grayscale image

    % Supported image formats
    valid_ext = {'.jpg', '.jpeg', '.png', '.tif', '.tiff'};

    % Get all files in folder
    files = dir(folder_path);
    imageFiles = [];

    % Keep only images with valid extension
    for i = 1:length(files)
        [~, ~, ext] = fileparts(files(i).name);
        if any(strcmpi(ext, valid_ext))
            imageFiles = [imageFiles; files(i)];
        else
            error('Invalid file detected: %s. Only image files with extensions %s are allowed.', files(i).name, strjoin(valid_ext, ', '));
        end
    end

    % Sort images by date in filename (format: DDMMYYYY.jpg)
    dates = datetime(cellfun(@(f) f(1:8), {imageFiles.name}, 'UniformOutput', false), 'InputFormat', 'ddMMyyyy');
    [~, idx] = sort(dates);
    imageFiles = imageFiles(idx);

    % Output initialization
    preprocessedImages = struct('name', {}, 'image', {});

    % Loop through all images
    for i = 1:length(imageFiles)
        fname = fullfile(folder_path, imageFiles(i).name);
        img = imread(fname);

        % Convert to grayscale if it's a color image
        if size(img,3) == 3
            img = rgb2gray(img);
        end

        % Normalize brightness with histogram equalization
        img = histeq(img);

        % Convert to double for processing
        img = im2double(img);

        % Apply light blur to reduce noise (optional!!!!!)
        img = imgaussfilt(img, 1); % gaussian blur with sigma = 1

        % Resize to match the first image (It can also be set to a defined Pixel number)
        if i == 1
            refSize = size(img);
        else
            img = imresize(img, refSize);
        end

        % Save to output struct
        preprocessedImages(end+1).name = imageFiles(i).name;
        preprocessedImages(end).image = img;
    end
end
