function [Breg, Ttotal, info, debug] = registerImages(A, B, opts)
% registerImages  Align preprocessed B onto preprocessed A
%   [Breg, Ttotal, info, debug] = registerImages(A, B, opts)
%
%   A, B      : preprocessed grayscale images (double [0,1], same size)
%   opts      : struct with fields (all optional)
%                .MetricThreshold (default:250)
%                .NumOctaves      (default:6)
%                .MaxRatio        (default:0.6)
%                .MatchThreshold  (default:50)
%                .MaxDistance     (default:6)
%                .MaxNumTrials    (default:6000)
%                .DoPlotMatches   (default:false)
%
%   Breg      : B warped into A's frame
%   Ttotal    : projective2d transform object
%   info      : struct with .numMatches, .numInliers, .inlierRatio
%   debug     : struct with raw keypoints & match data

    %% 1) Parse + validate opts
    p = inputParser();
    addParameter(p, 'MetricThreshold', 1000, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'NumOctaves'     ,    6, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'MaxRatio'       ,  0.5, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'MatchThreshold' ,   30, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'MaxDistance'    ,    4, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'MaxNumTrials'   , 6000, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'Confidence'     , 99.0, @(x) isnumeric(x) && isscalar(x));
    addParameter(p, 'DoPlotMatches'  , false, @islogical);
    parse(p, opts);
    o = p.Results;

    %% 2) Convert to single floats (if not already)
    gA = im2single(A);
    gB = im2single(B);

    %% 3) Coarse alignment via phase correlation
    [dx,dy] = phaseCorrShift(imresize(gA,0.25), imresize(gB,0.25));
    Tcoarse = affine2d([1 0 0; 0 1 0; -4*dx -4*dy 1]);

    Bcoarse = imwarp(B, Tcoarse, 'OutputView', imref2d(size(A)));

    %% 4) SURF detect & match
    ptsA = detectSURFFeatures(gA, 'MetricThreshold', o.MetricThreshold, ...
                                      'NumOctaves'     , o.NumOctaves);
    ptsB = detectSURFFeatures(im2single(Bcoarse), 'MetricThreshold', o.MetricThreshold, ...
                                                    'NumOctaves'     , o.NumOctaves);

    [fA, vA] = extractFeatures(gA, ptsA);
    [fB, vB] = extractFeatures(im2single(Bcoarse), ptsB);

    pairs    = matchFeatures(fA, fB, ...
                             'MaxRatio'      , o.MaxRatio, ...
                             'MatchThreshold', o.MatchThreshold, ...
                             'Unique'        , true);
    info.numMatches = size(pairs,1);

    %% 5) Fine alignment via projective RANSAC
    [tformProj, inliers] = estimateGeometricTransform2D( ...
        vB(pairs(:,2)), vA(pairs(:,1)), 'projective', ...
        'MaxDistance', o.MaxDistance, ...
        'MaxNumTrials', o.MaxNumTrials, ...
        'Confidence', o.Confidence);

    info.numInliers  = numel(inliers);
    info.inlierRatio = info.numInliers / max(1, info.numMatches);

    %% 6) Compose & warp
    H = tformProj.T * Tcoarse.T;
    H = H / H(3,3);
    Ttotal = projective2d(H);
    Breg   = imwarp(B, Ttotal, 'OutputView', imref2d(size(A)));

    %% 7) Pack debug
    debug.vecA     = vA;
    debug.vecB     = vB;
    debug.pairs    = pairs;
    debug.inliers  = inliers;

    if o.DoPlotMatches
        figure;
        showMatchedFeatures(A, Bcoarse, vA(pairs(:,1)), vB(pairs(:,2)));
        title('All SURF Matches (pre‐RANSAC)');
    end
end

%% Helper: phase correlation
function [dx,dy] = phaseCorrShift(I1, I2)
    % Crop to same size
    [h1,w1] = size(I1); [h2,w2] = size(I2);
    h = min(h1,h2); w = min(w1,w2);
    I1 = I1(1:h,1:w); I2 = I2(1:h,1:w);

    F1 = fft2(I1); F2 = fft2(I2);
    R  = (F1 .* conj(F2)) ./ max(abs(F1.*conj(F2)), eps);
    c  = abs(ifft2(R));
    [~,idx] = max(c(:));
    [dy,dx] = ind2sub(size(c), idx);

    if dy > h/2, dy = dy - h; end
    if dx > w/2, dx = dx - w; end
end
