function keyData = create_mosaic_sender(params)
% CREATE_MOSAIC_SENDER (COMBINED & SECURE)
% Multi-channel LSB embedding (3-3-2)
% PIN-based permutation + PIN verification
% Wrong PIN => decryption fails

arguments
    params struct
end

%% -------- Default Parameters --------
if ~isfield(params,'pin'), params.pin = '0000'; end
if ~isfield(params,'wm_text'), params.wm_text = ""; end

%% -------- Read Images --------
secret = imread(params.secretFile);
target = imread(params.targetFile);

% Ensure target is RGB
if size(target,3) == 1
    target = repmat(target,1,1,3);
end
target = im2uint8(target);

% Convert secret to grayscale
if size(secret,3) == 3
    secret = rgb2gray(secret);
end
secret = im2uint8(secret);

% Resize secret to match target
[Ht, Wt, ~] = size(target);
secret = imresize(secret, [Ht Wt], 'bicubic');
secret_vec = secret(:);

%% -------- PIN → Random Seed --------
pinStr = char(string(params.pin));
seed = sum(double(pinStr)) + numel(pinStr)*997;
rng(seed,'twister');

%% -------- PIN-Based Permutation --------
perm = randperm(numel(secret_vec));
secret_perm = secret_vec(perm);

%% -------- Split Secret Bits (3-3-2) --------
s  = uint8(secret_perm);
r3 = bitand(bitshift(s,-5), 7);   % 3 MSB
g3 = bitand(bitshift(s,-2), 7);   % next 3 bits
b2 = bitand(s, 3);                % 2 LSB

%% -------- Clear LSBs of Target --------
R = bitand(target(:,:,1), 248);   % 11111000
G = bitand(target(:,:,2), 248);
B = bitand(target(:,:,3), 252);   % 11111100

%% -------- Embed Secret --------
R(:) = R(:) + r3;
G(:) = G(:) + g3;
B(:) = B(:) + b2;

enc_img = cat(3, R, G, B);

%% -------- Optional Visible Watermark --------
if ~isempty(strtrim(params.wm_text))
    try
        overlay = zeros(Ht, Wt, 3, 'uint8');
        overlay = insertText(overlay, [5 Ht-40], params.wm_text, ...
            'FontSize', 18, 'BoxOpacity', 0, 'TextColor', 'white');
        enc_img = uint8(double(enc_img)*0.94 + double(overlay)*0.06);
    catch
        % watermark skipped if toolbox unavailable
    end
end

%% -------- Save Encrypted Image --------
imwrite(enc_img, 'mosaic_encrypted_multilayer.png');

%% -------- PIN Verification Hash --------
pinHash = sum(double(pinStr).^2) + seed*31;

%% -------- Save Key Data (NO permutation stored) --------
keyData = struct();
keyData.pinSeed  = seed;
keyData.pinHash  = pinHash;
keyData.imgSize  = [Ht Wt];
keyData.method   = 'LSB-3-3-2';
keyData.wm_text  = string(params.wm_text);
keyData.created  = datetime('now');

save('mosaic_key_multilayer.mat','keyData');

%% -------- Reset RNG --------
rng('shuffle');
end
