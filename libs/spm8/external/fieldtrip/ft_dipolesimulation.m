function [simulated] = ft_dipolesimulation(cfg)

% FT_DIPOLESIMULATION computes the field or potential of a simulated dipole
% and returns a datastructure identical to the FT_PREPROCESSING function.
%
% Use as
%   data = ft_dipolesimulation(cfg)
%
% You should specify the volume conductor model with
%   cfg.hdmfile       = string, file containing the volume conduction model
% or alternatively
%   cfg.vol           = structure with volume conduction model
% If the sensor information is not contained in the data itself you should 
% also specify the sensor information using
%   cfg.gradfile      = string, file containing the gradiometer definition
%   cfg.elecfile      = string, file containing the electrode definition
% or alternatively
%   cfg.grad          = structure with gradiometer definition
%   cfg.elec          = structure with electrode definition
%
% optionally
%   cfg.channel    = Nx1 cell-array with selection of channels (default = 'all'),
%                    see FT_CHANNELSELECTION for details
%
% The dipoles position and orientation have to be specified with
%   cfg.dip.pos     = [Rx Ry Rz] (size Nx3)
%   cfg.dip.mom     = [Qx Qy Qz] (size 3xN)
%
% The timecourse of the dipole activity is given as a single vector or as a
% cell-array with one vectors per trial
%   cfg.dip.signal
% or by specifying a sine-wave signal
%   cfg.dip.frequency    in Hz
%   cfg.dip.phase        in radians
%   cfg.dip.amplitude    per dipole
%   cfg.ntrials          number of trials
%   cfg.triallength      time in seconds
%   cfg.fsample          sampling frequency in Hz
%
% Random white noise can be added to the data in each trial, either by 
% specifying an absolute or a relative noise level
%   cfg.relnoise    = add noise with level relative to simulated signal
%   cfg.absnoise    = add noise with absolute level

% Undocumented local options
% cfg.feedback
% cfg.previous
% cfg.version
%
% This function depends on FT_PREPARE_VOL_SENS which has the following options:
% cfg.channel, documented
% cfg.elec, documented
% cfg.elecfile, documented
% cfg.grad, documented
% cfg.gradfile, documented
% cfg.hdmfile, documented
% cfg.order
% cfg.vol, documented

% Copyright (C) 2004, Robert Oostenveld
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
% $Id: ft_dipolesimulation.m 3728 2011-06-22 12:21:57Z johzum $

ft_defaults

% record start time and total processing time
ftFuncTimer = tic();
ftFuncClock = clock();

% set the defaults
if ~isfield(cfg, 'dip'),        cfg.dip = [];             end
if ~isfield(cfg.dip, 'pos'),    cfg.dip.pos = [-5 0 15];  end
if ~isfield(cfg.dip, 'mom'),    cfg.dip.mom = [1 0 0]';   end
if ~isfield(cfg, 'fsample'),    cfg.fsample = 250;        end
if ~isfield(cfg, 'relnoise'),   cfg.relnoise = 0;         end
if ~isfield(cfg, 'absnoise'),   cfg.absnoise = 0;         end
if ~isfield(cfg, 'feedback'),   cfg.feedback = 'text';    end
if ~isfield(cfg, 'channel'),    cfg.channel = 'all';      end

cfg.dip = fixdipole(cfg.dip);
Ndipoles = size(cfg.dip.pos,1);

% prepare the volume conductor and the sensor array
[vol, sens, cfg] = prepare_headmodel(cfg, []);

if ~isfield(cfg, 'ntrials') 
  if isfield(cfg.dip, 'signal')
    cfg.ntrials = length(cfg.dip.signal);
  else
    cfg.ntrials = 20;
  end
end
Ntrials  = cfg.ntrials;

if isfield(cfg.dip, 'frequency')
  % this should be a column vector
  cfg.dip.frequency = cfg.dip.frequency(:);
end

if isfield(cfg.dip, 'phase')
  % this should be a column vector
  cfg.dip.phase = cfg.dip.phase(:);
end

% no signal was given, compute a cosine-wave signal as timcourse for the dipole
if ~isfield(cfg.dip, 'signal')
  % set some additional defaults if neccessary
  if ~isfield(cfg.dip, 'frequency')
    cfg.dip.frequency = ones(Ndipoles,1)*10;
  end
  if ~isfield(cfg.dip, 'phase')
    cfg.dip.phase = zeros(Ndipoles,1);
  end
  if ~isfield(cfg.dip, 'amplitude')
    cfg.dip.amplitude = ones(Ndipoles,1);
  end
  if ~isfield(cfg, 'triallength')
    cfg.triallength = 1;
  end
  % compute a cosine-wave signal wit the desired frequency, phase and amplitude for each dipole
  nsamples = round(cfg.triallength*cfg.fsample);
  time     = (0:(nsamples-1))/cfg.fsample;
  for i=1:Ndipoles
    cfg.dip.signal(i,:) = cos(cfg.dip.frequency(i)*time*2*pi + cfg.dip.phase(i)) * cfg.dip.amplitude(i);
  end
end

% construct the timecourse of the dipole activity for each individual trial
if ~iscell(cfg.dip.signal)
  dipsignal = {};
  time      = {};
  nsamples  = length(cfg.dip.signal);
  for trial=1:Ntrials
    % each trial has the same dipole signal 
    dipsignal{trial} = cfg.dip.signal;
    time{trial} = (0:(nsamples-1))/cfg.fsample;
  end
else
  dipsignal = {};
  time      = {};
  for trial=1:Ntrials
    % each trial has a different dipole signal 
    dipsignal{trial} = cfg.dip.signal{trial};
    time{trial} = (0:(length(dipsignal{trial})-1))/cfg.fsample;
  end
end

dippos    = cfg.dip.pos;
dipmom    = cfg.dip.mom;

if ~iscell(dipmom)
  dipmom = {dipmom};
end

if ~iscell(dippos)
  dippos = {dippos};
end

if length(dippos)==1
  dippos = repmat(dippos, 1, Ntrials);
elseif length(dippos)~=Ntrials
  error('incorrect number of trials specified in the dipole position');
end

if length(dipmom)==1
  dipmom = repmat(dipmom, 1, Ntrials);
elseif length(dipmom)~=Ntrials
  error('incorrect number of trials specified in the dipole moment');
end

simulated.trial  = {};
simulated.time   = {};
ft_progress('init', cfg.feedback, 'computing simulated data');
for trial=1:Ntrials
  ft_progress(trial/Ntrials, 'computing simulated data for trial %d\n', trial);
  lf = ft_compute_leadfield(dippos{trial}, sens, vol);
  nsamples = size(dipsignal{trial},2);
  nchannels = size(lf,1);
  simulated.trial{trial} = zeros(nchannels,nsamples);
  for i = 1:3,
    simulated.trial{trial}  = simulated.trial{trial} + lf(:,i:3:end) * ...
       (repmat(dipmom{trial}(i:3:end),1,nsamples) .* dipsignal{trial});
  end
  simulated.time{trial}   = time{trial};
end
ft_progress('close');

if ft_senstype(sens, 'meg')
  simulated.grad = sens;
elseif ft_senstype(sens, 'meg')
  simulated.elec = sens;
end

% determine RMS value of simulated data
ss = 0;
sc = 0;
for trial=1:Ntrials
  ss = ss + sum(simulated.trial{trial}(:).^2);
  sc = sc + length(simulated.trial{trial}(:));
end
rms = sqrt(ss/sc);
fprintf('RMS value of simulated data is %g\n', rms);

% add noise to the simulated data
for trial=1:Ntrials
  relnoise = randn(size(simulated.trial{trial})) * cfg.relnoise * rms;
  absnoise = randn(size(simulated.trial{trial})) * cfg.absnoise;
  simulated.trial{trial} = simulated.trial{trial} + relnoise + absnoise;
end

simulated.fsample = cfg.fsample;
simulated.label   = sens.label;

% add version details to the configuration
cfg.version.name = mfilename('fullpath');
cfg.version.id   = '$Id: ft_dipolesimulation.m 3728 2011-06-22 12:21:57Z johzum $';

% add information about the Matlab version used to the configuration
cfg.callinfo.matlab = version();
  
% add information about the function call to the configuration
cfg.callinfo.proctime = toc(ftFuncTimer);
cfg.callinfo.calltime = ftFuncClock;
cfg.callinfo.user = getusername();

% remember the configuration details of the input data
try, cfg.previous = data.cfg; end

% remember the exact configuration details in the output 
simulated.cfg = cfg;

