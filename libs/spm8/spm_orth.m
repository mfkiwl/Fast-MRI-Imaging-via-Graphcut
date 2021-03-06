function X = spm_orth(X,OPT)
% recursive Gram-Schmidt orthogonalisation of basis functions
% FORMAT X = spm_orth(X,OPT)
%
% X   - matrix
% OPT - 'norm' for Euclidean normalisation
%     - 'pad'  for zero padding of null space [default]
%
% serial orthogonalisation starting with the first column
%
% refs:
% Golub, Gene H. & Van Loan, Charles F. (1996), Matrix Computations (3rd
% ed.), Johns Hopkins, ISBN 978-0-8018-5414-9.
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging
 
% Karl Friston
% $Id: spm_orth.m 4314 2011-04-26 12:55:49Z ged $
 
% default
%--------------------------------------------------------------------------
try
    OPT;
catch
    OPT = 'pad';
end
 
% recursive Gram-Schmidt orthogonalisation
%--------------------------------------------------------------------------
sw = warning('off','all');
[n m] = size(X);
X     = X(:, any(X));
rankX = rank(X);
try
    x     = X(:,1);
    j     = 1;
    for i = 2:size(X, 2)
        D = X(:,i);
        D = D - x*pinv(x)*D;
        if norm(D,1) > exp(-32)
            x          = [x D];
            j(end + 1) = i;
        end
        if numel(j) == rankX, break, end
    end
catch
    x     = zeros(n,0);
    j     = [];
end
warning(sw);
 
% and normalisation, if requested
%--------------------------------------------------------------------------
switch OPT
    case{'pad'}
        X      = zeros(n,m);
        X(:,j) = x;
    otherwise
        X      = spm_en(x);
end

