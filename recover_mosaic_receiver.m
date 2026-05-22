function [mosaic_decrypted, recovered_text, keyData] = ...
         recover_mosaic_receiver(varargin)
% RECOVER_MOSAIC_RECEIVER (COMBINED & SECURE)
% Correct PIN  -> correct secret recovery
% Wrong PIN    -> scrambled / mosaic output (no hard failure)

%% -------- Init --------
mosaic_decrypted = [];
recovered_text = "";
keyData = struct();

%% -------- Parse Inputs --------
if nargin == 3
    a = varargin{1}; b = varargin{2}; c = varargin{3};
    if isstruct(a) || (ischar(a) && endsWith(string(a),'.mat'))
        keyArg = a; encFile = b; pin = c;
    elseif isstruct(b) || (ischar(b) && endsWith(string(b),'.mat'))
        keyArg = b; encFile = c; pin = a;
    else
        pin = a; keyArg = b; encFile = c;
    end
elseif nargin == 2
    keyArg = varargin{1};
    encFile = varargin{2};
    error('PIN is required for decryption');
else
    error('Invalid arguments.');
end

%% -------- Load Key Data --------
if ischar(keyArg) || isstring(keyArg)
    s = load(char(keyArg),'keyData');
    keyData = s.keyData;
elseif isstruct(keyArg)
    keyData = keyArg;
else
    error('Invalid key input');
end

%% -------- Load Encrypted Image --------
enc_img = imread(encFile);
if size(enc_img,3)==1
    enc_img = repmat(enc_img,1,1,3);
end
enc_img = im2uint8(enc_img);
[Ht,Wt,~] = size(enc_img);

%% -------- PIN → Seed --------
pinStr = char(string(pin));
seed = sum(double(pinStr)) + numel(pinStr)*997;

enteredHash = sum(double(pinStr).^2) + seed*31;
isPinCorrect = isfield(keyData,'pinHash') && ...
               (enteredHash == keyData.pinHash);

if ~isPinCorrect
    warning('Wrong PIN entered: scrambled mosaic output will be shown.');
end

%% -------- Extract Embedded Bits (3-3-2) --------
R = enc_img(:,:,1);
G = enc_img(:,:,2);
B = enc_img(:,:,3);

r3 = bitand(R(:),7);
g3 = bitand(G(:),7);
b2 = bitand(B(:),3);

s_perm = uint8(bitshift(r3,5) + bitshift(g3,2) + b2);

%% -------- Regenerate Permutation from PIN --------
rng(seed,'twister');
perm = randperm(numel(s_perm));

%% -------- Inverse Permutation --------
secret_vec = zeros(size(s_perm),'uint8');
secret_vec(perm) = s_perm;

%% -------- Reshape to Image --------
mosaic_decrypted = reshape(secret_vec,Ht,Wt);

%% -------- Recover Watermark Text --------
if isPinCorrect && isfield(keyData,'wm_text')
    recovered_text = string(keyData.wm_text);
else
    recovered_text = "";
end

%% -------- Save Output --------
try
    imwrite(mosaic_decrypted,'recovered_secret.png');
catch
end

rng('shuffle');
end
