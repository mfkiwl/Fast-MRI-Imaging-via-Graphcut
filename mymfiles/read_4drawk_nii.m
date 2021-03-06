function img = read_4drawk_nii(filename, FEoversampled, permute_nifti)

% returns raw k-space nifti data, after removing FE oversampling and permuting if
% necessary
% permute_nifti = [3 2 1 4];  % needed to permute dims - [] to disable
% FEoversampled = 'kz';  % set if FE is oversampled by 2x - mostly the case for nifti files obtained from CIND
                       % choices: [], 'none', 'kx', 'ky', 'kz' (all after permutation, if any)
hdr = load_nii_hdr(filename);
na =  hdr.dime.dim(2);
nb =  hdr.dime.dim(3);
nc =  hdr.dime.dim(4);
nd = hdr.dime.dim(5);
sz = [na, nb, nc, nd];

if nargin<3
    permute_nifti = [];
end
if nargin < 2 || strcmp(FEoversampled, 'none')
    FEoversampled = [];
end

if ~isempty(permute_nifti)
    sz = sz(permute_nifti);
end
switch (FEoversampled)
   case 'kx'
    sz(1) = sz(1)/2;
   case 'ky'
    sz(2) = sz(2)/2;
   case 'kz'
    sz(3) = sz(3)/2;
end
img = zeros(sz, 'single');

q = 0;
for coil = 1:nd
    nii = load_nii(filename,coil);
    tmp = single(nii.img);
    clear nii;
    if ~isempty(permute_nifti)
        tmp = permute(tmp, permute_nifti);
    end
    switch (FEoversampled)
       case 'kx'
          tmp = ifft(tmp, [], 1);
          tmp = fftshift(tmp, 1);
%           tmp = tmp(1:end/2, :, :);
          tmp = tmp(round(end/2)-round(end/4):round(end/2)+round(end/4)-1, :, :);
          q = q + squeeze(sum(sum(abs(tmp), 2), 1));
       case 'ky'
          tmp = ifft(tmp, [], 2);
          tmp = fftshift(tmp, 2);
%           tmp = tmp(:, 1:end/2, :);
          tmp = tmp(:, round(end/2)-round(end/4):round(end/2)+round(end/4)-1, :);
          q = q + squeeze(sum(sum(abs(tmp), 2), 1));
       case 'kz'
          tmp = ifft(tmp, [], 3);
          tmp = fftshift(tmp, 3);
%           tmp = tmp(:, :, 1:end/2);
          tmp = tmp(:, :, round(end/2)-round(end/4):round(end/2)+round(end/4)-1);
          q = q + squeeze(sum(sum(abs(tmp), 2), 1));
        otherwise
          tmp = ifft(tmp, [], 1);  
          tmp = fftshift(tmp, 1);
          q = q + squeeze(sum(sum(abs(tmp), 2), 1));
    end
    img(:,:,:,coil) = tmp; 
end

% figure; plot(abs(q)); title('signal norm along slices');

for coil = 1:sz(4)
    for sl=1:sz(3)
        img(:,:,sl,coil) = doxchop(doychop(img(:,:,sl,coil)));
    end
end


