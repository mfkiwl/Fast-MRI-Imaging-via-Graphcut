function [s, cfg] = statfun_depsamplesT(cfg, dat, design)

% STATFUN_depsamplesT calculates the dependent samples T-statistic 
% on the biological data in dat (the dependent variable), using the information on 
% the independent variable (iv) in design.
%
% Use this function by calling one of the high-level statistics functions as:
%   [stat] = ft_timelockstatistics(cfg, timelock1, timelock2, ...)
%   [stat] = ft_freqstatistics(cfg, freq1, freq2, ...)
%   [stat] = ft_sourcestatistics(cfg, source1, source2, ...)
% with the following configuration option:
%   cfg.statistic = 'depsamplesT'
% see FT_TIMELOCKSTATISTICS, FT_FREQSTATISTICS or FT_SOURCESTATISTICS for details.
%
% For low-level use, the external interface of this function has to be
%   [s,cfg] = statfun_depsamplesT(cfg, dat, design);
% where
%   dat    contains the biological data, Nsamples x Nreplications
%   design contains the independent variable (iv) and the unit-of-observation (UO) 
%          factor,  Nfac x Nreplications
%
% Configuration options:
%   cfg.computestat    = 'yes' or 'no', calculate the statistic (default='yes')
%   cfg.computecritval = 'yes' or 'no', calculate the critical values of the test statistics (default='no')
%   cfg.computeprob    = 'yes' or 'no', calculate the p-values (default='no')
% The following options are relevant if cfg.computecritval='yes' and/or
% cfg.computeprob='yes'.
%   cfg.alpha = critical alpha-level of the statistical test (default=0.05)
%   cfg.tail = -1, 0, or 1, left, two-sided, or right (default=1)
%              cfg.tail in combination with cfg.computecritval='yes'
%              determines whether the critical value is computed at
%              quantile cfg.alpha (with cfg.tail=-1), at quantiles
%              cfg.alpha/2 and (1-cfg.alpha/2) (with cfg.tail=0), or at
%              quantile (1-cfg.alpha) (with cfg.tail=1).
%
% Design specification:
%   cfg.ivar        = row number of the design that contains the labels of the conditions that must be 
%                        compared (default=1). The labels are the numbers 1 and 2.
%   cfg.uvar        = row number of design that contains the labels of the UOs (subjects or trials)
%                        (default=2). The labels are assumed to be integers ranging from 1 to 
%                        the number of UOs.
%

% Copyright (C) 2006, Eric Maris
%
% Subversion does not use the Log keyword, use 'svn log <filename>' or 'svn -v log | less' to get detailled information

% set defaults
if ~isfield(cfg, 'computestat'),    cfg.computestat    = 'yes'; end 
if ~isfield(cfg, 'computecritval'), cfg.computecritval = 'no';  end
if ~isfield(cfg, 'computeprob'),    cfg.computeprob    = 'no';  end
if ~isfield(cfg, 'alpha'),          cfg.alpha          = 0.05;  end
if ~isfield(cfg, 'tail'),           cfg.tail           = 1;     end

% perform some checks on the configuration
if strcmp(cfg.computeprob,'yes') && strcmp(cfg.computestat,'no')
    error('P-values can only be calculated if the test statistics are calculated.');
end;
if ~isfield(cfg,'uvar') || isempty(cfg.uvar)
    error('uvar must be specified for dependent samples statistics');
end

% perform some checks on the design
sel1 = find(design(cfg.ivar,:)==1);
sel2 = find(design(cfg.ivar,:)==2);
n1  = length(sel1);
n2  = length(sel2);
if (n1+n2)<size(design,2) || (n1~=n2)
  error('Invalid specification of the design array.');
end
nunits = length(design(cfg.uvar, sel1));
df = nunits - 1;
if nunits<2
    error('The data must contain at least two units (usually subjects).')
end
if (nunits*2)~=(n1+n2)
  error('Invalid specification of the design array.');
end
nsmpls = size(dat,1);

if strcmp(cfg.computestat,'yes')
  % compute the statistic
  % store the positions of the 1-labels and the 2-labels in a nunits-by-2 array
  poslabelsperunit = zeros(nunits,2);
  poslabel1        = find(design(cfg.ivar,:)==1);
  poslabel2        = find(design(cfg.ivar,:)==2);
  [dum,i]          = sort(design(cfg.uvar,poslabel1), 'ascend');
  poslabelsperunit(:,1) = poslabel1(i);
  [dum,i]          = sort(design(cfg.uvar,poslabel2), 'ascend');
  poslabelsperunit(:,2) = poslabel2(i);
    
  % calculate the differences between the conditions
  diffmat = zeros(nsmpls,nunits);
  diffmat = dat(:,poslabelsperunit(:,1)) - dat(:,poslabelsperunit(:,2));
    
  % calculate the dependent samples t-statistics
  if any(isnan(diffmat(:)))
    avgdiff = nanmean(diffmat,2);
    vardiff = nanvar(diffmat,0,2);
    nunits  = sum(~isnan(diffmat),2);
    s.stat  = (sqrt(nunits).*avgdiff)./sqrt(vardiff);
  else
    avgdiff = mean(diffmat,2);
    vardiff = var(diffmat,0,2);
    s.stat  = sqrt(nunits)*avgdiff./sqrt(vardiff);
  end
end

if strcmp(cfg.computecritval,'yes')
  % also compute the critical values
  s.df      = df;
  if cfg.tail==-1
    s.critval = tinv(cfg.alpha,df);
  elseif  cfg.tail==0
    s.critval = [tinv(cfg.alpha/2,df),tinv(1-cfg.alpha/2,df)];
  elseif cfg.tail==1
    s.critval = tinv(1-cfg.alpha,df);
  end
end

if strcmp(cfg.computeprob,'yes')
  % also compute the p-values
  s.df      = df;
  if cfg.tail==-1
    s.prob = tcdf(s.stat,s.df);
  elseif  cfg.tail==0
    s.prob = 2*tcdf(-abs(s.stat),s.df);
  elseif cfg.tail==1
    s.prob = 1-tcdf(s.stat,s.df);
  end
end

