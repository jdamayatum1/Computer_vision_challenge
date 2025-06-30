function preprocessedImages = preprocess_images(folder_path)
% PREPROCESS_IMAGES - Loads and processes satellite images from a folder.
%
% Requirements: Image Preprocessing Tool from MathWorks
%
% Input:
%    Path to folder with images (format: date must be in the filename: DDMMYYYY, MMYYYY or YYYY)
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
        if files(i).isdir
            continue  % skip directories like '.' and '..'
        end
        [~, ~, ext] = fileparts(files(i).name);
        if any(strcmpi(ext, valid_ext))
            imageFiles = [imageFiles; files(i)];
        else
            error('Invalid file detected: %s. Only image files with extensions %s are allowed.', ...
                  files(i).name, strjoin(valid_ext, ', '));
        end
    end

    % Try to detect date format DDMMYYYY, MMYYYY or YYYY
    dateStrings = {};
    for i = 1:length(imageFiles)
        name = imageFiles(i).name;
        base = name(1:min(end, 12)); 
        matched = false;
        formats = {'ddMMyyyy', 'MMyyyy', 'yyyy'};
        for f = 1:length(formats)
            try
                d = datetime(base(1:length(formats{f})), 'InputFormat', formats{f});
                dateStrings{end+1} = d;
                matched = true;
                break;
            catch
                % try next
            end
        end
        if ~matched
            error('Filename "%s" does not start with a valid date in format DDMMYYYY, MMYYYY or YYYY.', name);
        end
    end

    % Sort images by parsed dates
    [~, idx] = sort([dateStrings{:}]);
    imageFiles = imageFiles(idx);

    % First pass: find smallest image size (height x width)
    minSize = [Inf, Inf];  % [rows, cols]
    imageData = cell(length(imageFiles), 1);

    for i = 1:length(imageFiles)
        fname = fullfile(folder_path, imageFiles(i).name);
        img = imread(fname);
        
        % Store original image for later reuse
        imageData{i} = img;

        % Use color image size directly
        sz = size(img);
        sz = sz(1:2);  % only height and width

        if prod(sz) < prod(minSize)
            minSize = sz;
        end
    end

    % Output initialization
    preprocessedImages = struct('name', {}, 'image', {});

    % Loop through all images
    for i = 1:length(imageFiles)
        fname = fullfile(folder_path, imageFiles(i).name);
        img = imageData{i};

        % Normalize brightness with histogram equalization (on V channel in HSV)
        if size(img, 3) == 3
            img = im2double(img);  % Convert before HSV conversion
            hsv = rgb2hsv(img);
            hsv(:,:,3) = histeq(hsv(:,:,3));  % Only Value channel
            img = hsv2rgb(hsv);
        else
            img = histeq(img);
            img = im2double(img);  % Convert after equalization
        end

        % Apply light blur to reduce noise (optional!!!!!)
        img = imgaussfilt(img, 1); % gaussian blur with sigma = 1

        % Resize to smallest image
        img = imresize(img, minSize);

        % Save to output struct
        preprocessedImages(end+1).name = imageFiles(i).name;
        preprocessedImages(end).image = img;
    end
end
