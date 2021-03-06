%function read_Frank_data(flname)

clear all;
% flname = 'C:\data\CIND_Frank_data\StandardByteOrderPerPyNifti-1noiPATFullFT.nii';
% flname = 'C:\data\CIND_Frank_data\FlippedByteOrderPerPyNifti-1noiPATFullFT.nii';
% flname = 'C:\data\CIND_Frank_data\RR001-1noiPATFullFTChannel3.nii';
flname = 'C:\data\CIND_Frank_data\RR001-1noiPATFullFT.nii';
% flname = 'C:\data\CIND_Frank_data\newt1.nii';
% flname = 'C:\data\CIND_Frank_data\complexT1.nii';

% flname = 'C:\data\CIND_Frank_data\T1_cplx.nii';
% flname = 'C:\data\CIND_Frank_data\T1complex.nii';
% flname = 'C:\data\CIND_Frank_data\T1pynifti.nii';

nii = load_nii(flname, 1);
% nii = load_nii(flname);
nii.hdr.dime,
q = single(nii.img); clear nii;
% q = single(doXchop(q));
% q = single(doYchop(q));

% q = permute(q, [2, 3, 1]);
[nrows, ncols, nslices] = size(q),
max(max(max(abs(q)))),
min(min(min(abs(q)))),

figure; 
subplot(2,2,1); colormap(gray); imagesc(abs(squeeze(q(40,:,:)))); 
subplot(2,2,2); colormap(gray); imagesc(abs(squeeze(q(80,:,:)))); 
subplot(2,2,3); colormap(gray); imagesc(abs(squeeze(q(120,:,:)))); 
subplot(2,2,4); colormap(gray); imagesc(abs(squeeze(q(160,:,:)))); 

        
figure; 
subplot(2,2,1); colormap(gray); imagesc(abs(squeeze(q(:,40, :)))); 
subplot(2,2,2); colormap(gray); imagesc(abs(squeeze(q(:,80,:)))); 
subplot(2,2,3); colormap(gray); imagesc(abs(squeeze(q(:,120,:)))); 
subplot(2,2,4); colormap(gray); imagesc(abs(squeeze(q(:,160,:)))); 

figure; 
subplot(2,2,1); colormap(gray); imagesc(abs(squeeze(q(:,:,40)))); 
subplot(2,2,2); colormap(gray); imagesc(abs(squeeze(q(:,:,80)))); 
subplot(2,2,3); colormap(gray); imagesc(abs(squeeze(q(:,:, 120)))); 
subplot(2,2,4); colormap(gray); imagesc(abs(squeeze(q(:,:,160)))); 

qq = q;
for j = 1:ncols
    for k = 1:nslices
        qq(:,j,k) = single(myifft(q(:,j,k)));
    end
end

for i = 1:nrows
    tmpslice = squeeze(qq(i,:,:));
    qq(i,:,:) = single(myifft2(tmpslice));
end

max(max(max(abs(qq)))),
min(min(min(abs(qq)))),

figure; 
subplot(2,2,1); colormap(gray); imagesc(abs(squeeze(qq(40,:,:)))); 
subplot(2,2,2); colormap(gray); imagesc(abs(squeeze(qq(80,:,:)))); 
subplot(2,2,3); colormap(gray); imagesc(abs(squeeze(qq(120,:,:)))); 
subplot(2,2,4); colormap(gray); imagesc(abs(squeeze(qq(160,:,:)))); 

        
figure; 
subplot(2,2,1); colormap(gray); imagesc(abs(squeeze(qq(:,40, :)))); 
subplot(2,2,2); colormap(gray); imagesc(abs(squeeze(qq(:,80,:)))); 
subplot(2,2,3); colormap(gray); imagesc(abs(squeeze(qq(:,120,:)))); 
subplot(2,2,4); colormap(gray); imagesc(abs(squeeze(qq(:,160,:)))); 

figure; 
subplot(2,2,1); colormap(gray); imagesc(abs(squeeze(qq(:,:,40)))); 
subplot(2,2,2); colormap(gray); imagesc(abs(squeeze(qq(:,:,80)))); 
subplot(2,2,3); colormap(gray); imagesc(abs(squeeze(qq(:,:, 120)))); 
subplot(2,2,4); colormap(gray); imagesc(abs(squeeze(qq(:,:,160)))); 
