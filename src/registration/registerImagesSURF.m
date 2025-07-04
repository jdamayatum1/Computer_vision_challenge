function reg = registerImagesSURF(movingRGB, fixedRGB, cfg)
% … your existing function help text …


% ---------- 0  Input parsing & default‐merging -----------------------
% ---------- 0) Input parsing & default‐merging -----------------------
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

% 1) Declare **all** default values, including fallback fields
defaults = struct( ...
    'MetricThreshold', 500, ...
    'NumOctaves',      4, ...
    'NumScaleLevels',  6, ...
    'MatchThreshold',  50, ...
    'MaxRatio',        0.6, ...
    'TransformType',   'projective', ...
    'MinInliers',      30, ...
    'ImageSequence',   {{ }}, ...   % <-- double‐brace here!
    'StartIdx',        1, ...
    'EndIdx',          1 ...
);

% 2) Merge user cfg into params, overriding defaults only where set
params = defaults;
userFields = fieldnames(cfg);
for k = 1:numel(userFields)
    f = userFields{k};
    params.(f) = cfg.(f);
end

% Now use **params** everywhere below instead of cfg.
% e.g. params.MetricThreshold, params.MinInliers, etc.

% ---------- 1  Pre‐processing (as before) -----------------------------
movingGray = im2gray(movingRGB);
fixedGray  = im2gray(fixedRGB);

movingRef = imref2d(size(movingGray));
fixedRef  = imref2d(size(fixedGray));

% ---------- 2  Direct SURF registration -------------------------------
ptsF = detectSURFFeatures(fixedGray, ...
        'MetricThreshold', params.MetricThreshold, ...
        'NumOctaves',      params.NumOctaves, ...
        'NumScaleLevels',  params.NumScaleLevels);
ptsM = detectSURFFeatures(movingGray, ...
        'MetricThreshold', params.MetricThreshold, ...
        'NumOctaves',      params.NumOctaves, ...
        'NumScaleLevels',  params.NumScaleLevels);

[featF, validF] = extractFeatures(fixedGray,  ptsF, 'Upright', false);
[featM, validM] = extractFeatures(movingGray, ptsM, 'Upright', false);

idxPairs = matchFeatures(featF, featM, ...
        'MatchThreshold', params.MatchThreshold, ...
        'MaxRatio',       params.MaxRatio, ...
        'Unique',         true);

matchedF = validF(idxPairs(:,1));
matchedM = validM(idxPairs(:,2));

[tformDir, inlierIdx] = estimateGeometricTransform2D( ...
        matchedM, matchedF, params.TransformType);

% ---------- 3) Fallback chaining if too few inliers ------------------
if nnz(inlierIdx) < params.MinInliers
    fprintf('Using fallback option: only %d inliers (need ≥%d)\n', ...
    nnz(inlierIdx), params.MinInliers);
    % Ensure we have a proper cell array to index into
    if ~iscell(params.ImageSequence)
        error('ImageSequence must be a cell array of RGB frames for chaining.');
    end
    if params.StartIdx < 1 || params.EndIdx > numel(params.ImageSequence)
        error('StartIdx/EndIdx out of range for ImageSequence.');
    end

    % Compose the small pairwise transforms
    Ttot = projective2d(eye(3));
    for kk = params.StartIdx : (params.EndIdx-1)
        A = params.ImageSequence{kk};
        B = params.ImageSequence{kk+1};

        % Build a step‐only config that disables chaining by zeroing MinInliers
        stepCfg = rmfield(params, {'ImageSequence','StartIdx','EndIdx'});
        stepCfg.MinInliers = 0;    % <-- DISABLE fallback in recursive call

        tmpReg = registerImagesSURF(A, B, stepCfg);
        Ttot   = projective2d(tmpReg.tform.T * Ttot.T);
    end

    finalTform = Ttot;
    % clear out the direct-match diagnostics
    matchedF = [];  matchedM = [];  inlierIdx = [];
else
    finalTform = tformDir;
end


% ---------- 4  Warp movingRGB into fixed frame -------------------------
warped = imwarp(movingRGB, movingRef, finalTform, ...
               'OutputView', fixedRef, 'SmoothEdges', true);

% ---------- 5  Bundle outputs ------------------------------------------
reg.registered     = warped;
reg.tform          = finalTform;
reg.matches.fixed  = matchedF;
reg.matches.moving = matchedM;
reg.inlierIdx      = inlierIdx;
reg.spatialRef     = fixedRef;
end
