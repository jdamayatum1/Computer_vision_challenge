% % Load the images
% fixedImage = imread('12_2000.jpg'); % Replace with your fixed image
% movingImage = imread('12_2006.jpg');    % Replace with your moving image
% % For these two, image should be in the same folder


% Prompt user to select the fixed image
[fixedImageFile, fixedImagePath] = uigetfile({'*.jpg;*.png;*.tif', 'Image Files (*.jpg, *.png, *.tif)'}, 'Select Fixed Image');
if isequal(fixedImageFile, 0)
    disp('User canceled the selection.');
    return; % Exit if no file is selected
end
fixedImage = imread(fullfile(fixedImagePath, fixedImageFile));

% Prompt user to select the moving image
[movingImageFile, movingImagePath] = uigetfile({'*.jpg;*.png;*.tif', 'Image Files (*.jpg, *.png, *.tif)'}, 'Select Moving Image');
if isequal(movingImageFile, 0)
    disp('User canceled the selection.');
    return; % Exit if no file is selected
end
movingImage = imread(fullfile(movingImagePath, movingImageFile));



% Convert to grayscale if necessary
if size(fixedImage, 3) == 3
    fixedImage = rgb2gray(fixedImage);
end
if size(movingImage, 3) == 3
    movingImage = rgb2gray(movingImage);
end

% Detect features
pointsFixed = detectSURFFeatures(fixedImage);
pointsMoving = detectSURFFeatures(movingImage);

% Extract features
[featuresFixed, validPointsFixed] = extractFeatures(fixedImage, pointsFixed);
[featuresMoving, validPointsMoving] = extractFeatures(movingImage, pointsMoving);

% Match features
indexPairs = matchFeatures(featuresFixed, featuresMoving);
matchedPointsFixed = validPointsFixed(indexPairs(:, 1), :);
matchedPointsMoving = validPointsMoving(indexPairs(:, 2), :);

% Estimate geometric transformation
if isempty(indexPairs)
    disp('Automatic feature matching failed. Please select control points manually.');
    [movingPoints, fixedPoints] = cpselect(movingImage, fixedImage, 'Wait', true);
    % Estimate transformation using selected control points
    [tform, inlierIdx] = estimateGeometricTransform(matchedPointsMoving, matchedPointsFixed, 'rigid');
else
    [tform, inlierIdx] = estimateGeometricTransform(matchedPointsMoving, matchedPointsFixed, 'affine', 'MaxNumTrials', 5000, 'Confidence', 90);
end

% Check condition number
conditionNumber = cond(tform.T);
if conditionNumber > 1e10
    warning('Transformation matrix is ill-conditioned.');
end

% Apply transformation
alignedImage = imwarp(movingImage, tform, 'OutputView', imref2d(size(fixedImage)));

% Display results
figure;
subplot(1, 3, 1);
imshow(fixedImage);
title('Fixed Image');

subplot(1, 3, 2);
imshow(movingImage);
title('Moving Image');

subplot(1, 3, 3);
imshow(alignedImage);
title('Aligned Image');
