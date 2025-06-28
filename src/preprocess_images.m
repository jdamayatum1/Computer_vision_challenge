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

    % Output initialization
    preprocessedImages = struct('name', {}, 'image', {});

    % Loop through all images
    for i = 1:length(imageFiles)
        fname = fullfile(folder_path, imageFiles(i).name);
        img = imread(fname);

        % Normalize brightness with histogram equalization
        img = histeq(img);

        % Convert to double for processing
        img = im2double(img);

        % Apply light blur to reduce noise (optional!!!!!)
        img = imgaussfilt(img, 1); % gaussian blur with sigma = 1

        % Resize to match the first image (Can be changed to a manual set of # of Pixels)
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