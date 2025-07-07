function reg = registerImagesSURF(movingRGB, fixedRGB, cfg)
% … your existing function help text …


% ---------- 0  Input parsing & default‐merging -----------------------
% ---------- 0) Input parsing & default‐merging -----------------------
if nargin < 3 || isempty(cfg)
    cfg = struct();
end

% 1) Declare **all** default values, including fallback fields
defaults = struct( ...
    'MetricThreshold', 100, ... % the lower the more matches
    'NumOctaves',      4, ...
    'NumScaleLevels',  6, ...
    'MatchThreshold',  50, ... % the lower the more matches
    'MaxRatio',        0.6, ...
    'TransformType',   'affine', ...
    'MinInliers',      7, ...
    'MaxNumTrials',    15000, ...      % RANSAC: maximum iterations
    'Confidence',      95,   ...      % RANSAC: desired confidence (percent)
    'ImageSequence',   {{ }}, ...   % <-- double‐brace here!
    'StartIdx',        1, ...
    'EndIdx',          1, ...
    'StepMinInliers',  3, ...      % quality gate for each fallback hop
    'StepMaxCond',     1e7, ...      % new parameter
    'RetryMax',       2, ...
    'MaxDistance',   8 ...          % how many times to re-run RANSAC before fallback
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

% ---------- Direction handling: allow StartIdx > EndIdx -------------
origMovingRGB = movingRGB;   % keep originals
origFixedRGB  = fixedRGB;
reverseDir = false;
if params.StartIdx > params.EndIdx
    reverseDir = true;
    % swap images for forward processing
    movingRGB = origFixedRGB;
    fixedRGB  = origMovingRGB;
    % swap indices in params
    tmp              = params.StartIdx;
    params.StartIdx  = params.EndIdx;
    params.EndIdx    = tmp;
end

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

% Replace single RANSAC call with retry loop
bestInliers = 0;
for attempt = 1:params.RetryMax
    [tformTmp, inlierTmp] = estimateGeometricTransform2D( ...
            matchedM, matchedF, params.TransformType, ...
            'MaxNumTrials', params.MaxNumTrials, ...
            'Confidence',   params.Confidence);
    nIn = nnz(inlierTmp);
    if nIn > bestInliers
        bestInliers = nIn;  tformDir = tformTmp;  inlierIdx = inlierTmp;  %#ok<NASGU>
    end
    if bestInliers >= params.MinInliers
        break;   % good enough
    end
end

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

        % Build a step-only config
        stepCfg = params;                      % copy *all* current settings
        stepCfg = rmfield(stepCfg,{'ImageSequence','StartIdx','EndIdx'});
        stepCfg.MinInliers = params.StepMinInliers;

        tmpReg = registerImagesSURF(A, B, stepCfg);

        % Compose regardless of hop quality (but warn once)
        hopInliers = nnz(tmpReg.inlierIdx);
        condT      = cond(tmpReg.tform.T);
        if hopInliers < params.StepMinInliers || condT > params.StepMaxCond
            warning('Weak hop %d→%d: %d inliers, cond=%g – composing anyway.', ...
                    kk, kk+1, hopInliers, condT);
        end

        Ttot = projective2d(tmpReg.tform.T * Ttot.T);
    end

    finalTform = Ttot;
    % clear out the direct-match diagnostics
    matchedF = [];  matchedM = [];  inlierIdx = [];
else
    finalTform = tformDir;
end


% ---------- 4  Warp movingRGB into fixed frame -------------------------
if reverseDir
    % need up-to-date refs for original order
    movingRefOrig = imref2d(size(origMovingRGB));
    fixedRefOrig  = imref2d(size(origFixedRGB));
    finalTform = invert(finalTform);   % direction back to original
    warped = imwarp(origMovingRGB, movingRefOrig, finalTform, ...
                   'OutputView', fixedRefOrig, 'SmoothEdges', true);
else
    warped = imwarp(movingRGB, movingRef, finalTform, ...
                   'OutputView', fixedRef, 'SmoothEdges', true);
end

% ---------- 5  Bundle outputs ------------------------------------------
reg.registered     = warped;
reg.tform          = finalTform;
reg.matches.fixed  = matchedF;
reg.matches.moving = matchedM;
reg.inlierIdx      = inlierIdx;
if reverseDir
    reg.spatialRef = fixedRefOrig;
else
    reg.spatialRef = fixedRef;
end
end
