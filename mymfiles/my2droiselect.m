function [roimask, nonroimask] = my2droiselect(labelimg, img)
% given image and its identified objects labeled in labelimg, allows user to click inside any region, which is then returned
% may pass only labelimg, in that case grayscale img is not displayed
% also returns nonroimask - areas DEFINITELY not in the ROI

[nrows, ncols, ncolors] = size(img);
zoomfact = 700/max(nrows, ncols);
q = single(img); %/max(img(:))*255;
roimask = zeros(nrows, ncols);
nonroimask = zeros(nrows, ncols);
if nnz(labelimg)==0, 
    return;
end
% create label img if not there
if max(labelimg(:)) < 2,
    bw = labelimg;
    %labelimg = bwlabel(bw);
end

slice_done = false;
pos = []; butt = [];
% size(img), size(labelimg),
% qq = label2rgb(labelimg); size(qq),
% max(qq(:)),
if nargin < 2
    q = label2rgb(labelimg);
else
    if ncolors == 1, 
        q = cat(3, img, img, img); 
    elseif ncolors==2,
        q = cat(3, img, zeros(nrows, ncols)); 
    elseif ncolors>3
        q = img(:,:,1:3);
    end
    qq = 0.9*single(cat(3,q(:,:,1), q(:,:,1), q(:,:,1))) + 0.2*single(label2rgb(labelimg));
end
%figure;
clf;
while ~slice_done
    subplot(1,2,2); imagesc(uint8(q)); title('pseudocolor of liver dynamic response'); h = gcf;  %truesize(round([nrows, ncols]*zoomfact)); 
    subplot(1,2,1); imagesc(uint8(qq)); title('detected clusters overlaid on liver MRI'); h = gcf; %truesize(round([nrows, ncols]*zoomfact)); 
    %title('click within desired ROI  - use as many points as needed, right click when done. Esc or Enter for next slice');
    [cc, rr, button] = ginput;
    if isempty(cc)
            slice_done = true;
    else
        [bw, xi, yi] = roipoly(uint8(qq), cc, rr);
        if length(xi)==1
            %get object eclosing point
            point = [xi(1), yi(1)];
            pos = [pos; point];
            butt = [butt; button];
        elseif length(xi)==2
            point = [xi(1), yi(1); xi(2), yi(2)];
            pos = [pos; point];
            butt = [butt; button];
        else
            % get polygon
            if button(1) == 1
                roimask(bw) = 1;
            elseif button(1) == 3
                nonroimask(bw) = 1;
            end
        end
    figure(h);
    end
    if ~isempty(pos)
        for i = 1:max(labelimg(:))
            bw = single(labelimg==i);
            tmp = bwselect(bw, pos(butt==1,1), pos(butt==1,2));
            roimask(tmp) = 1;
            tmp = bwselect(bw, pos(butt==3,1), pos(butt==3,2));
            nonroimask(tmp) = 1;
        end
    end
    roimask(nonroimask==1) = 0;
    if nnz(roimask)>0, 
    %     figure; imagesc(roimask); colormap(gray); title('user selected roi')
        subplot(1,2,2); imagesc(roimask); colormap(gray); title('user selected roi'); %truesize(round([nrows, ncols]*zoomfact)); 
        pause(1);
    end
end   
    
