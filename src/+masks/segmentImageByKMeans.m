function [segmentedImage, dominantMask, clusterMasksRGB, clusterColors] = segmentImageByKMeans(image, numClusters)
%SEGMENTIMAGEBYKMEANS Segments an image using k-means into a variable number of clusters.
% Returns segmented image, dominant mask, RGB-colored cluster masks, and cluster colors.

    if nargin < 2
        numClusters = 3;
    end

    % Convert to LAB + grayscale + entropy
    labImage = rgb2lab(image);
    ab = labImage(:,:,2:3); ab = im2single(ab);
    [h, w, ~] = size(image);
    gray = rgb2gray(image);
    entropyMap = mat2gray(entropyfilt(gray));
    L = rescale(labImage(:,:,1));

    % Combine features
    pixelData = [reshape(ab(:,:,1), [], 1), ...
                 reshape(ab(:,:,2), [], 1), ...
                 reshape(entropyMap, [], 1), ...
                 reshape(L, [], 1)];

    % Run K-means
    [clusterIdx, ~] = kmeans(pixelData, numClusters, 'Distance','sqeuclidean', ...
                             'Replicates', 3, 'MaxIter', 1000);
    pixelLabels = reshape(clusterIdx, h, w);

    % Generate distinguishable colors automatically
    cmap = uint8(255 * lines(numClusters));
    clusterColors = cmap;

    % Create segmented image
    segmentedImage = zeros(h, w, 3, 'uint8');
    for k = 1:numClusters
        mask = (pixelLabels == k);
        for c = 1:3
            segmentedImage(:,:,c) = segmentedImage(:,:,c) + clusterColors(k,c) .* uint8(mask);
        end
    end

    % Create RGB-colored masks per cluster
    clusterMasksRGB = zeros(h, w, 3, numClusters, 'uint8');
    for k = 1:numClusters
        mask = (pixelLabels == k);
        rgbMask = zeros(h, w, 3, 'uint8');
        for c = 1:3
            rgbMask(:,:,c) = uint8(double(mask) * double(clusterColors(k,c)));
        end
        clusterMasksRGB(:,:,:,k) = rgbMask;
    end

    % Determine dominant cluster
    counts = histcounts(clusterIdx, 1:numClusters+1);
    totalPixels = h * w;

    hsvImg = rgb2hsv(image);
    H = hsvImg(:,:,1); S = hsvImg(:,:,2); V = hsvImg(:,:,3);
    likelyWater = false(1, numClusters);

    for k = 1:numClusters
        mask = (pixelLabels == k);
        hAvg = mean(H(mask));
        sAvg = mean(S(mask));
        vAvg = mean(V(mask));
        if hAvg > 0.5 && hAvg < 0.75 && sAvg > 0.2 && vAvg > 0.15 && vAvg < 0.7
            likelyWater(k) = true;
        end
    end

    [sortedCounts, order] = sort(counts, 'descend');
    dominantCluster = order(1);
    if likelyWater(dominantCluster) && sortedCounts(1)/totalPixels < 0.5
        for i = 2:numClusters
            if ~likelyWater(order(i))
                dominantCluster = order(i);
                break;
            end
        end
    end

    dominantMask = (pixelLabels == dominantCluster);

    % Visualization
    figure;
    subplot(2, ceil((3+numClusters)/2), 1); imshow(image); title('Original Image');
    subplot(2, ceil((3+numClusters)/2), 2); imshow(segmentedImage); title('Segmented Image');
    subplot(2, ceil((3+numClusters)/2), 3); imshow(dominantMask); title('Dominant Mask');

    for k = 1:numClusters
        subplot(2, ceil((3+numClusters)/2), 3+k);
        imshow(clusterMasksRGB(:,:,:,k));
        title(sprintf('Cluster %d Mask', k));
    end
end