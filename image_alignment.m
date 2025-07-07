% Load the images
fixedImage = imread('12_1990.jpg'); % Replace with your fixed image
movingImage = imread('12_2020.jpg');    % Replace with your moving image
% For these two, image should be in the same folder

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
[tform, inlierIdx] = estimateGeometricTransform(matchedPointsMoving, matchedPointsFixed, 'affine', 'MaxNumTrials', 5000, 'Confidence', 90);

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
