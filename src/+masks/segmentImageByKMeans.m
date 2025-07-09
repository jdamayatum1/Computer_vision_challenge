function [segmentedImage, dominantMask, maskedRGB] = segmentImageByKMeans(image, numClusters)
%SEGMENTIMAGEBYKMEANS Automatically segments an image using k-means clustering in LAB color space.
% Returns the segmented image, binary mask of dominant cluster, and masked RGB result.

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
    segmentedImage = label2rgb(pixelLabels);

    % Analyze cluster stats
    counts = histcounts(clusterIdx, 1:numClusters+1);
    totalPixels = h * w;
    percent = counts / totalPixels;

    % Heuristic: check each cluster's average HSV
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

    % Choose dominant cluster with condition
    [sortedCounts, order] = sort(counts, 'descend');
    dominantCluster = order(1);
    if likelyWater(dominantCluster) && sortedCounts(1)/totalPixels < 0.5
        % Choose next cluster that is not water
        for i = 2:numClusters
            if ~likelyWater(order(i))
                dominantCluster = order(i);
                break;
            end
        end
    end

    dominantMask = (pixelLabels == dominantCluster);
    maskedRGB = image;
    maskedRGB(repmat(~dominantMask,[1,1,3])) = 0;

    % Plot
    figure;
    subplot(2,2,1); imshow(image); title('Original Image');
    subplot(2,2,2); imshow(segmentedImage); title('K-Means Segmentation');
    subplot(2,2,3); imshow(dominantMask); title('Binary Mask (Dominant Cluster)');
    subplot(2,2,4); imshow(maskedRGB); title('Masked RGB Region');


end
