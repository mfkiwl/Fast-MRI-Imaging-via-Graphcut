function [u, Ps, ue] = spm_uc_clusterFDR(q,df,STAT,R,n,Z,XYZ,V2R,ui)
% Cluster False Discovery critical extent threshold
% FORMAT [u, Ps, ue] = spm_uc_clusterFDR(q,df,STAT,R,n,Z,XYZ,ui)
%
% q     - prespecified upper bound on False Discovery Rate
% df    - [df{interest} df{residuals}]
% STAT  - statistical field
%         'Z' - Gaussian field
%         'T' - T - field
%         'X' - Chi squared field
%         'F' - F - field
% R     - RESEL Count {defining search volume}
% n     - conjunction number
% Z     - height {minimum over n values}
%         or mapped statistic image(s)
% XYZ   - locations [x y x]' {in voxels}
%         or vector of indices of elements within mask
%         or mapped mask image
% V2R   - voxel to resel
% ui    - feature-inducing threshold
%
% u     - critical extent threshold
% Ps    - sorted p-values
% ue    - critical extent threshold for FWE
%__________________________________________________________________________
%
% References
%
% J.R. Chumbley and K.J. Friston, "False discovery rate revisited: FDR and 
% topological inference using Gaussian random fields". NeuroImage,
% 44(1):62-70, 2009.
%
% J.R. Chumbley, K.J. Worsley, G. Flandin and K.J. Friston, "Topological
% FDR for NeuroImaging". NeuroImage, 49(4):3057–3064, 2010.
%__________________________________________________________________________
% Copyright (C) 2009-2012 Wellcome Trust Centre for Neuroimaging

% Justin Chumbley & Guillaume Flandin
% $Id: spm_uc_clusterFDR.m 4645 2012-02-03 17:45:44Z guillaume $


% Read statistical value from disk if needed
%--------------------------------------------------------------------------
if isstruct(Z)
    Vs         = Z;
    Vm         = XYZ;
    [Z, XYZmm] = spm_read_vols(Vs(1),true);
    for i=2:numel(Vs)
        Z      = min(Z, spm_read_vols(Vs(i)),true);
    end
    Z          = Z(:)';
    XYZ        = Vs(1).mat \ [XYZmm; ones(1, size(XYZmm, 2))];
    I          = ~isnan(Z) & Z~=0;
    XYZ        = XYZ(1:3,I);
    Z          = Z(I);
    if isstruct(Vm)
        Vm     = logical(spm_read_vols(Vm));
        Vm     = Vm(I);
    end
    XYZ        = XYZ(:,Vm);
    Z          = Z(:,Vm);
end

% Threshold the statistical field 
%--------------------------------------------------------------------------
XYZ      = XYZ(:,Z >= ui);

% Extract size of excursion sets 
%--------------------------------------------------------------------------
N        = spm_clusters(XYZ);
if ~isempty(N)
    N    = histc(N,(0:max(N))+0.5);
end
N        = N(1:end-1);
N        = N .* V2R;

% Compute uncorrected p-values based on N using Random Field Theory
%--------------------------------------------------------------------------
Ps       = zeros(1,numel(N));
Pk       = zeros(1,numel(N));
ws       = warning('off','SPM:outOfRangePoisson');
for i = 1:length(N)
    [Pk(i), Ps(i)] = spm_P_RF(1,N(i),ui,df,STAT,R,n);
end
warning(ws);
[Ps, J]  = sort(Ps, 'ascend');

S        = length(Ps);

% Calculate FDR inequality RHS
%--------------------------------------------------------------------------
cV       = 1;    % Benjamini & Yeuketeli cV for independence/PosRegDep case
Fi       = (1:S)/S*q/cV;

% Find threshold
%--------------------------------------------------------------------------
I        = find(Ps <= Fi, 1, 'last');
if isempty(I)
    u    = Inf;
else
    u    = N(J(I)) / V2R;
end

% As we're there, also determine the FWE critical extent threshold
%--------------------------------------------------------------------------
if nargout == 3
    [Pk, J] = sort(Pk, 'ascend');
    I       = find(Pk <= q, 1, 'last');
    if isempty(I)
        ue  = Inf;
    else
        ue  = N(J(I)) / V2R;
    end
end
