function [resample] = resampledesign(cfg, design)

% RESAMPLEDESIGN returns a resampling matrix, in which each row can be
% used to resample either the original design matrix or the original data.
% The random resampling is done given user-specified constraints on the
% experimental design, e.g. to swap within paired observations but not
% between pairs.
%
% Use as
%   [resample] = randomizedesign(cfg, design)
% where the configuration can contain
%   cfg.resampling       = 'permutation' or 'bootstrap'
%   cfg.numrandomization = number (e.g. 300), can be 'all' in case of two conditions
%   cfg.ivar             = number or list with indices, independent variable(s)
%   cfg.uvar             = number or list with indices, unit variable(s)
%   cfg.wvar             = number or list with indices, within-cell variable(s)
%   cfg.cvar             = number or list with indices, control variable(s)
%
% See also STATISTICS_MONTECARLO

% Copyright (C) 2005-2007, Robert Oostenveld
%
% This file is part of FieldTrip, see http://www.ru.nl/neuroimaging/fieldtrip
% for the documentation and details.
%
%    FieldTrip is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    FieldTrip is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with FieldTrip. If not, see <http://www.gnu.org/licenses/>.
%
% $Id: resampledesign.m 3406 2011-04-29 13:03:44Z jansch $

if ~isfield(cfg, 'ivar'), cfg.ivar = []; end
if ~isfield(cfg, 'uvar'), cfg.uvar = []; end
if ~isfield(cfg, 'wvar'), cfg.wvar = []; end  % within-cell variable, to keep repetitions together
if ~isfield(cfg, 'cvar'), cfg.cvar = []; end

% if size(design,1)>size(design,2)
%   % this function wants the replications in the column direction
%   % the matrix seems to be transposed
%   design = transpose(design);
% end

Nvar  = size(design,1);   % number of factors or regressors
Nrepl = size(design,2);   % number of replications

if ~isempty(intersect(cfg.ivar, cfg.uvar)), warning('there is an intersection between cfg.ivar and cfg.uvar'); end
if ~isempty(intersect(cfg.ivar, cfg.wvar)), warning('there is an intersection between cfg.ivar and cfg.wvar'); end
if ~isempty(intersect(cfg.ivar, cfg.cvar)), warning('there is an intersection between cfg.ivar and cfg.cvar'); end
if ~isempty(intersect(cfg.uvar, cfg.wvar)), warning('there is an intersection between cfg.uvar and cfg.wvar'); end
if ~isempty(intersect(cfg.uvar, cfg.cvar)), warning('there is an intersection between cfg.uvar and cfg.cvar'); end
if ~isempty(intersect(cfg.wvar, cfg.cvar)), warning('there is an intersection between cfg.wvar and cfg.cvar'); end

fprintf('total number of measurements     = %d\n', Nrepl);
fprintf('total number of variables        = %d\n', Nvar);
fprintf('number of independent variables  = %d\n', length(cfg.ivar));
fprintf('number of unit variables         = %d\n', length(cfg.uvar));
fprintf('number of within-cell variables = %d\n', length(cfg.wvar));
fprintf('number of control variables      = %d\n', length(cfg.cvar));
fprintf('using a %s resampling approach\n', cfg.resampling);

if ~isempty(cfg.cvar)
  % do the resampling for each sub-block
  % the different levels of the control variable indicate the sub-blocks in which the resampling can be done
  blocklevel = unique(design(cfg.cvar,:)', 'rows')';
  for i=1:size(blocklevel,2)
    blocksel{i} = find(all(design(cfg.cvar,:)==repmat(blocklevel(:,i), 1, Nrepl), 1));
    blocklen(i) = length(blocksel{i});
  end
  for i=1:size(blocklevel,2)
    fprintf('------------------------------------------------------------\n');
    if length(cfg.cvar)>1
      fprintf('resampling the subset where the control variable level is [%s]\n', num2str(blocklevel(:,i)));
    else
      fprintf('resampling the subset where the control variable level is %s\n', num2str(blocklevel(:,i)));
    end
    tmpcfg = cfg;
    tmpcfg.cvar = [];
    blockres{i} = blocksel{i}(resampledesign(tmpcfg, design(:, blocksel{i})));
  end
  % concatenate the blocks and return the result
  resample = cat(2, blockres{:});
  return
end

if isnumeric(cfg.numrandomization) && cfg.numrandomization==0
  % no randomizations are requested, return an empty shuffling matrix
  resample = zeros(0,Nrepl);
  return;
end

if ~isempty(cfg.wvar)
  % keep the elements within a cell together, e.g. multiple tapers in a trial
  % this is realized by replacing the design matrix temporarily with a smaller version
  blkmeas = unique(design(cfg.wvar,:)', 'rows')';
  for i=1:size(blkmeas,2)
    blksel{i} = find(all(design(cfg.wvar,:)==repmat(blkmeas(:,i), 1, Nrepl), 1));
    blklen(i) = length(blksel{i});
  end
  for i=1:size(blkmeas,2)
    if any(diff(design(:, blksel{i}), 1, 2)~=0)
      error('the design matrix variables should be constant within a block');
    end
  end
  orig_design = design;
  orig_Nrepl  = Nrepl;
  % replace the design matrix by a blocked version
  design = zeros(size(design,1), size(blkmeas,2));
  Nrepl  = size(blkmeas,2); 
  for i=1:size(blkmeas,2)
    design(:,i) = orig_design(:, blksel{i}(1));
  end
end

% do some validity checks
if Nvar==1 && ~isempty(cfg.uvar)
  error('A within-units shuffling requires a at least one unit variable and at least one independent variable');
end

if isempty(cfg.uvar) && strcmp(cfg.resampling, 'permutation')
  % reshuffle the colums of the design matrix
  if ischar(cfg.numrandomization) && strcmp(cfg.numrandomization, 'all')
    % systematically shuffle the columns in the design matrix
    Nperm = prod(1:Nrepl);
    fprintf('creating all possible permutations (%d)\n', Nperm);
    resample = perms(1:Nrepl);
  elseif ~ischar(cfg.numrandomization)
    % randomly shuffle the columns in the design matrix the specified number of times
    resample = zeros(cfg.numrandomization, Nrepl);
    for i=1:cfg.numrandomization
      resample(i,:) = randperm(Nrepl);
    end
  end

elseif isempty(cfg.uvar) && strcmp(cfg.resampling, 'bootstrap')
  % randomly draw with replacement, keeping the number of elements the same in each class
  % only the test under the null-hypothesis (h0) is explicitely implemented here
  % but the h1 test can be achieved using a control variable
  resample = zeros(cfg.numrandomization, Nrepl);
  for i=1:cfg.numrandomization
    resample(i,:) = randsample(1:Nrepl, Nrepl);
  end

elseif ~isempty(cfg.uvar) && strcmp(cfg.resampling, 'permutation')
  % reshuffle the colums of the design matrix, keep the rows of the design matrix with the unit variable intact
  unitlevel = unique(design(cfg.uvar,:)', 'rows')';
  for i=1:size(unitlevel,2)
    unitsel{i} = find(all(design(cfg.uvar,:)==repmat(unitlevel(:,i), 1, Nrepl), 1));
    unitlen(i) = length(unitsel{i});
  end
  if length(cfg.uvar)==1
    fprintf('repeated measurement in variable %d over %d levels\n', cfg.uvar, length(unitlevel));
    fprintf('number of repeated measurements in each level is '); fprintf('%d ', unitlen); fprintf('\n');
  else
    fprintf('repeated measurement in mutiple variables over %d levels\n', length(unitlevel));
    fprintf('number of repeated measurements in each level is '); fprintf('%d ', unitlen); fprintf('\n');
  end
  
  if ischar(cfg.numrandomization) && strcmp(cfg.numrandomization, 'all')
    % create all possible permutations by systematic assignment
    if any(unitlen~=2)
      error('cfg.numrandomization=''all'' is only supported for two repeated measurements');
    end
    Nperm = 2^(length(unitlevel));
    fprintf('creating all possible permutations (%d)\n', 2^(length(unitlevel)));
    resample = zeros(Nperm, Nrepl);
    for i=1:Nperm
      flip  = dec2bin( i-1, length(unitlevel));
      for j=1:length(unitlevel)
        if     strcmp('0', flip(j)),
          resample(i, unitsel{j}(1)) = unitsel{j}(1);
          resample(i, unitsel{j}(2)) = unitsel{j}(2);
        elseif strcmp('1', flip(j)),
          resample(i, unitsel{j}(1)) = unitsel{j}(2);
          resample(i, unitsel{j}(2)) = unitsel{j}(1);
        end
      end
    end
    
  elseif ~ischar(cfg.numrandomization)
    % create the desired number of permutations by random shuffling
    resample = zeros(cfg.numrandomization, Nrepl);
    for i=1:cfg.numrandomization
      for j=1:length(unitlevel)
        resample(i, unitsel{j}) = unitsel{j}(randperm(length(unitsel{j})));
      end
    end
  end
  
elseif length(cfg.uvar)==1 && strcmp(cfg.resampling, 'bootstrap') && isempty(cfg.cvar),
  % randomly draw with replacement, keeping the number of elements the same in each class
  % only the test under the null-hypothesis (h0) is explicitely implemented here
  % but the h1 test can be achieved using a control variable
 
  % FIXME allow for length(cfg.uvar)>1, does it make sense in the first place
  % bootstrap the units of observation 
  units = design(cfg.uvar,:);
  for k = 1:length(unique(units))
    sel = find(units==k);
    indx(:,k) = sel;
    Nrep(k)   = length(sel);
  end
  resample = zeros(cfg.numrandomization, Nrepl);
  
  %sanity check on number of repetitions
  if any(Nrep~=Nrep(1)), error('all units of observation should have an equal number of repetitions'); end

  if max(units(:))<20, 
    warning('fewer than 20 units warrants explicit checking of double occurrences of ''bootstraps''');
    checkunique = 1;
  else
    checkunique = 0;
  end

  if ~checkunique,
    for i=1:cfg.numrandomization
      tmp           = randsample(1:Nrepl/Nrep(1), Nrepl/Nrep(1));
      for k=1:size(indx,1)
        resample(i,indx(k,:)) = indx(k,tmp);
      end
    end
  else
    tmp = zeros(cfg.numrandomization*10, Nrepl/Nrep(1));
    for i=1:cfg.numrandomization*10
      tmp(i,:) = sort(randsample(1:Nrepl/Nrep(1), Nrepl/Nrep(1)));
    end
    
    tmp = unique(tmp, 'rows');
    fprintf('found %d unique rows in bootstrap matrix of %d bootstraps', size(tmp,1), cfg.numrandomization*10);
    
    if size(tmp,1)<cfg.numrandomization
      fprintf('using only %d unique bootstraps\n', size(tmp,1));
      cfg.numrandomization = size(tmp,1);
      index = 1:size(tmp,1);
    else
      index = randperm(size(tmp,1));
      index = index(1:cfg.numrandomization);
    end
    
    tmp = tmp(index,:);
    for i=1:cfg.numrandomization
      for k=1:size(indx,1)
        resample(i,indx(k,:)) = indx(k,tmp(i,:));
      end
    end
  
  end
else
  error('Unsupported configuration for resampling.');
end

if ~isempty(cfg.wvar)
  % switch back to the original design matrix and expand the resample ordering
  % matrix so that it reorders all elements within a cell together
  design = orig_design;
  Nrepl  = orig_Nrepl;
  expand = zeros(size(resample,1), Nrepl);
  for i=1:size(resample,1)
    expand(i,:) = cat(2, blksel{resample(i,:)});
  end
  resample = expand;
end
