function [freq] = ft_freqanalysis(cfg, data)

% FT_FREQANALYSIS performs frequency and time-frequency analysis
% on time series data over multiple trials
%
% Use as
%   [freq] = ft_freqanalysis(cfg, data)
%
% The input data should be organised in a structure as obtained from
% the FT_PREPROCESSING function. The configuration depends on the type
% of computation that you want to perform.
%
% The configuration should contain:
%   cfg.method     = different methods of calculating the spectra
%                   'mtmfft', analyses an entire spectrum for the entire data
%                       length, implements multitaper frequency transformation
%                   'mtmconvol', implements multitaper time-frequency transformation
%                       based on multiplication in the frequency domain
%                   'mtmwelch', performs frequency analysis using Welch's averaged
%                       modified periodogram method of spectral estimation
%                   'wavelet', implements wavelet time frequency transformation
%                       (using Morlet wavelets) based on multiplication in the frequency domain
%                   'tfr', implements wavelet time frequency transformation
%                       (using Morlet wavelets) based on convolution in the time domain
%                   OR, if you want to use the old implementation (not from the specest module)
%                   'mtmfft_old' 
%                   'mtmconvol_old'
%                   'wltconvol_old'
%   cfg.output     = 'pow'       return the power-spectra
%                    'powandcsd' return the power and the cross-spectra
%                    'fourier'   return the complex Fourier-spectra
%   cfg.channel    = Nx1 cell-array with selection of channels (default = 'all'),
%                    see FT_CHANNELSELECTION for details
%   cfg.channelcmb = Mx2 cell-array with selection of channel pairs (default = {'all' 'all'}),
%                    see FT_CHANNELCOMBINATION for details
%   cfg.trials     = 'all' or a selection given as a 1xN vector (default = 'all')
%   cfg.keeptrials = 'yes' or 'no', return individual trials or average (default = 'no')
%   cfg.keeptapers = 'yes' or 'no', return individual tapers or average (default = 'no')
%   cfg.pad        = number or 'maxperlen', length in seconds to which the data can be padded out (default = 'maxperlen')
%                    The padding will determine your spectral resolution. If you want to
%                    compare spectra from data pieces of different lengths, you should use
%                    the same cfg.pad for both, in order to spectrally interpolate them to
%                    the same spectral resolution.  Note that this will run very slow if you
%                    specify cfg.pad as maxperlen AND the number of samples turns out to have
%                    a large prime factor sum. This is because the FFTs will then be computed
%                    very inefficiently.
%   cfg.polyremoval = number (default = 1), specifying the order of the polynome which is fitted and subtracted from
%                       time domain data prior to the spectral analysis. A value of 1 corresponds to a linear trend.
%                       If just mean subtraction is requested, use a value of 0. If no removal is requested, specify -1.
%                       see FT_PREPROC_POLYREMOVAL for details
%                 
%
%  METHOD SPECIFIC OPTIONS AND DESCRIPTIONS
%
%  MTMFFT
%   MTMFFT performs frequency analysis on any time series
%   trial data using the 'multitaper method' (MTM) based on discrete
%   prolate spheroidal sequences (Slepian sequences) as tapers. Alternatively,
%   you can use conventional tapers (e.g. Hanning).
%   cfg.foilim     = [begin end], frequency band of interest
%       OR
%   cfg.foi        = vector 1 x numfoi, frequencies of interest
%   cfg.tapsmofrq  = number, the amount of spectral smoothing through
%                    multi-tapering. Note that 4 Hz smoothing means
%                    plus-minus 4 Hz, i.e. a 8 Hz smoothing box.
%   cfg.taper      = 'dpss', 'hanning' or many others, see WINDOW (default = 'dpss')
%                     For cfg.output='powandcsd', you should specify the channel combinations
%                     between which to compute the cross-spectra as cfg.channelcmb. Otherwise
%                     you should specify only the channels in cfg.channel.
%
%  MTMCONVOL
%   MTMCONVOL performs time-frequency analysis on any time series trial data
%   using the 'multitaper method' (MTM) based on Slepian sequences as tapers. Alternatively,
%   you can use conventional tapers (e.g. Hanning).
%   cfg.tapsmofrq  = vector 1 x numfoi, the amount of spectral smoothing through
%                    multi-tapering. Note that 4 Hz smoothing means
%                    plus-minus 4 Hz, i.e. a 8 Hz smoothing box.
%   cfg.foilim     = [begin end], frequency band of interest
%       OR
%   cfg.foi        = vector 1 x numfoi, frequencies of interest
%   cfg.taper      = 'dpss', 'hanning' or many others, see WINDOW (default = 'dpss')
%                     For cfg.output='powandcsd', you should specify the channel combinations
%                     between which to compute the cross-spectra as cfg.channelcmb. Otherwise
%                     you should specify only the channels in cfg.channel.
%   cfg.t_ftimwin  = vector 1 x numfoi, length of time window (in seconds)
%   cfg.toi        = vector 1 x numtoi, the times on which the analysis windows
%                    should be centered (in seconds)
%
%  WAVELET
%   WAVELET performs time-frequency analysis on any time series trial data
%   using the 'wavelet method' based on Morlet wavelets.
%   cfg.foi        = vector 1 x numfoi, frequencies of interest
%       OR
%   cfg.foilim     = [begin end], frequency band of interest
%   cfg.toi        = vector 1 x numtoi, the times on which the analysis windows
%                    should be centered (in seconds)
%   cfg.width      = 'width' of the wavelet, determines the temporal and spectral
%                    resolution of the analysis (default = 7)
%                    constant, for a 'classical constant-Q' wavelet analysis
%                    vector, defining a variable width for each frequency
%   cfg.gwidth     = determines the length of the used wavelets in standard deviations
%                    of the implicit Gaussian kernel and should be choosen
%                    >= 3; (default = 3)
%      The standard deviation in the frequency domain (sf) at frequency f0 is
%      defined as: sf = f0/width
%      The standard deviation in the temporal domain (st) at frequency f0 is
%      defined as: st = width/f0 = 1/sf
%
%
%  TFR
%   TFR computes time-frequency representations of single-trial
%   data using a convolution in the time-domain with Morlet's wavelets.
%   cfg.foi           = vector 1 x numfoi, frequencies of interest
%   cfg.waveletwidth  = 'width' of wavelets expressed in cycles (default = 7)
%   cfg.downsample    = ratio for downsampling, which occurs after convolution (default = 1)
%
%
%  MTMWELCH
%   MTMWELCH performs frequency analysis on any time series
%    trial data using the 'multitaper method' (MTM) based on discrete
%    prolate spheroidal sequences (Slepian sequences) as tapers. Alternatively,
%    you can use conventional tapers (e.g. Hanning).
%    Besides multitapering, this function uses Welch's averaged, modified
%    periodogram method. The data is divided into a number of sections with
%    overlap, each section is windowed with the specified taper(s) and the
%    powerspectra are computed and averaged over the sections in each trial.
%    cfg.taper      = 'dpss', 'hanning' or many others, see WINDOW (default = 'dpss')
%    cfg.foilim     = [begin end], frequency band of interest
%    cfg.tapsmofrq  = number, the amount of spectral smoothing through
%                     multi-tapering. Note that 4 Hz smoothing means
%                     plus-minus 4 Hz, i.e. a 8 Hz smoothing box.
%
% To facilitate data-handling and distributed computing with the peer-to-peer
% module, this function has the following options:
%   cfg.inputfile   =  ...
%   cfg.outputfile  =  ...
% If you specify one of these (or both) the input data will be read from a *.mat
% file on disk and/or the output data will be written to a *.mat file. These mat
% files should contain only a single variable, corresponding with the
% input/output structure.
%
% See also FT_FREQANALYSIS_OLD, FT_FREQANALYSIS_MTMWELCH, FT_FREQANALYSIS_TFR

% Undocumented local options:
% cfg.correctt_ftimwin (set to yes to try to determine new t_ftimwins based
% on correct cfg.foi)

% Copyright (C) 2003-2006, F.C. Donders Centre, Pascal Fries
% Copyright (C) 2004-2006, F.C. Donders Centre, Markus Siegel
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
% $Id: ft_freqanalysis.m 3867 2011-07-19 07:08:50Z jansch $

ft_defaults

% record start time and total processing time
ftFuncTimer = tic();
ftFuncClock = clock();

% defaults for optional input/ouputfile and feedback
cfg.inputfile  = ft_getopt(cfg, 'inputfile',  []);
cfg.outputfile = ft_getopt(cfg, 'outputfile', []);
cfg.feedback   = ft_getopt(cfg, 'feedback',   'text');
cfg.inputlock  = ft_getopt(cfg, 'inputlock',  []);  % this can be used as mutex when doing peercellfun or another distributed computation
cfg.outputlock = ft_getopt(cfg, 'outputlock', []);  % this can be used as mutex when doing peercellfun or another distributed computation

% load optional given inputfile as data
hasdata      = (nargin>1);
hasinputfile = ~isempty(cfg.inputfile);

if hasdata && hasinputfile
  error('cfg.inputfile should not be used in conjunction with giving input data to this function');
elseif hasdata
  % nothing needs to be done
elseif hasinputfile
  mutexlock(cfg.inputlock);
  data = loadvar(cfg.inputfile, 'data');
  mutexunlock(cfg.inputlock);
end

% check if the input data is valid for this function
data = ft_checkdata(data, 'datatype', {'raw', 'comp', 'mvar'}, 'feedback', cfg.feedback, 'hassampleinfo', 'yes');

% select trials of interest
cfg.trials = ft_getopt(cfg, 'trials', 'all');
if ~strcmp(cfg.trials, 'all')
  fprintf('selecting %d trials\n', length(cfg.trials));
  data = ft_selectdata(data, 'rpt', cfg.trials);
end

% check if the input cfg is valid for this function
cfg = ft_checkconfig(cfg, 'trackconfig', 'on');
cfg = ft_checkconfig(cfg, 'renamed',     {'label', 'channel'});
cfg = ft_checkconfig(cfg, 'renamed',     {'sgn',   'channel'});
cfg = ft_checkconfig(cfg, 'renamed',     {'labelcmb', 'channelcmb'});
cfg = ft_checkconfig(cfg, 'renamed',     {'sgncmb',   'channelcmb'});
cfg = ft_checkconfig(cfg, 'required',    {'method'});
cfg = ft_checkconfig(cfg, 'renamedval',  {'method', 'fft',    'mtmfft'});
cfg = ft_checkconfig(cfg, 'renamedval',  {'method', 'convol', 'mtmconvol'});

% NEW OR OLD - switch for selecting which function to call and when to do it 
% this will change when the development of specest proceeds
% ALSO: Check for all cfg options that are defaulted in the old functions
cfg = ft_checkconfig(cfg, 'renamedval',  {'method', 'wltconvol', 'wavelet'});

if ~isfield(cfg, 'method'), error('you must specify a method in cfg.method'); end

switch cfg.method
    
  case 'mtmconvol'
    specestflg = 1;
    cfg.taper = ft_getopt(cfg, 'taper', 'dpss');    
    if isequal(cfg.taper, 'dpss') && ~isfield(cfg, 'tapsmofrq')
      error('you must specify a smoothing parameter with taper = dpss');
    end
    % check for foi above Nyquist
    if isfield(cfg,'foi')
      if any(cfg.foi > (data.fsample/2))
        error('frequencies in cfg.foi are above Nyquist')
      end
      if isequal(cfg.taper, 'dpss') && not(isfield(cfg, 'tapsmofrq'))
        error('you must specify a smoothing parameter with taper = dpss');
      end
    end
    
  case 'mtmfft'
    specestflg = 1;
    cfg.taper       = ft_getopt(cfg, 'taper', 'dpss');    
    if isequal(cfg.taper, 'dpss') && not(isfield(cfg, 'tapsmofrq'))
      error('you must specify a smoothing parameter with taper = dpss');
    end
    % check for foi above Nyquist
    if isfield(cfg,'foi')
      if any(cfg.foi > (data.fsample/2))
        error('frequencies in cfg.foi are above Nyquist')
      end
    end
    if isequal(cfg.taper, 'dpss') && not(isfield(cfg, 'tapsmofrq'))
      error('you must specify a smoothing parameter with taper = dpss');
    end
    
  case 'wavelet'
    specestflg = 1;
    cfg.width  = ft_getopt(cfg, 'width',  7);
    cfg.gwidth = ft_getopt(cfg, 'gwidth', 3);
   
  case 'hilbert_devel'
    warning('the hilbert implementation is under heavy development, do not use it for analysis purposes')
    specestflg = 1;
    if ~isfield(cfg, 'filttype'),         cfg.filttype      = 'but';        end
    if ~isfield(cfg, 'filtorder'),        cfg.filtorder     = 4;            end
    if ~isfield(cfg, 'filtdir'),          cfg.filtdir       = 'twopass';    end
    if ~isfield(cfg, 'width'),            cfg.width         = 1;            end
    cfg.method = 'hilbert';
    
  otherwise
    specestflg = 0;
    if ~isempty(strfind(cfg.method,'_old'))
      disp(['using old implementation of ' cfg.method(1:end-4)])
    else
      disp(['''' cfg.method ''' has not been implemented yet in the specest toolbox, the old implementation is being used'])
    end
end

if ~specestflg
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % HERE THE OLD IMPLEMENTATION STARTS
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  [freq] = feval(sprintf('ft_freqanalysis_%s',lower(cfg.method)), cfg, data);
  
   
else
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % HERE THE NEW IMPLEMENTATION STARTS
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % set all the defaults
  cfg.pad       = ft_getopt(cfg, 'pad',       'maxperlen');
  cfg.output    = ft_getopt(cfg, 'output',    'pow');
  cfg.calcdof   = ft_getopt(cfg, 'calcdof',   'no');
  cfg.channel   = ft_getopt(cfg, 'channel',   'all');
  cfg.precision = ft_getopt(cfg, 'precision', 'double');
  cfg.foi       = ft_getopt(cfg, 'foi',       []);
  cfg.foilim    = ft_getopt(cfg, 'foilim',    []);
  cfg.correctt_ftimwin = ft_getopt(cfg, 'correctt_ftimwin', 'no');
  cfg.polyremoval = ft_getopt(cfg, 'polyremoval', 1);  
  
  % keeptrials and keeptapers should be conditional on cfg.output,
  % cfg.output = 'fourier' should always output tapers
  if strcmp(cfg.output, 'fourier')
    cfg.keeptrials = ft_getopt(cfg, 'keeptrials', 'yes');
    cfg.keeptapers = ft_getopt(cfg, 'keeptapers', 'yes');
    if strcmp(cfg.keeptrials, 'no') || strcmp(cfg.keeptapers, 'no'),
      error('cfg.output = ''fourier'' requires cfg.keeptrials = ''yes'' and cfg.keeptapers = ''yes''');
    end   
  else
    cfg.keeptrials = ft_getopt(cfg, 'keeptrials', 'no');
    cfg.keeptapers = ft_getopt(cfg, 'keeptapers', 'no');
  end 
 
  % set flags for keeping trials and/or tapers
  if strcmp(cfg.keeptrials,'no') &&  strcmp(cfg.keeptapers,'no')
    keeprpt = 1;
  elseif strcmp(cfg.keeptrials,'yes') &&  strcmp(cfg.keeptapers,'no')
    keeprpt = 2;
  elseif strcmp(cfg.keeptrials,'no') &&  strcmp(cfg.keeptapers,'yes')
    error('There is currently no support for keeping tapers WITHOUT KEEPING TRIALS.');
  elseif strcmp(cfg.keeptrials,'yes') &&  strcmp(cfg.keeptapers,'yes')
    keeprpt = 4;
  end
  if strcmp(cfg.keeptrials,'yes') && strcmp(cfg.keeptapers,'yes')
    if ~strcmp(cfg.output, 'fourier'),
      error('Keeping trials AND tapers is only possible with fourier as the output.');
    end
  end
  
  % Set flags for output
  if strcmp(cfg.output,'pow')
    powflg = 1;
    csdflg = 0;
    fftflg = 0;
  elseif strcmp(cfg.output,'powandcsd')
    powflg = 1;
    csdflg = 1;
    fftflg = 0;
  elseif strcmp(cfg.output,'fourier')
    powflg = 0;
    csdflg = 0;
    fftflg = 1;
  else
    error('Unrecognized output required');
  end
  
  % prepare channel(cmb)
  if ~isfield(cfg, 'channelcmb') && csdflg
    %set the default for the channelcombination
    cfg.channelcmb = {'all' 'all'};
  elseif isfield(cfg, 'channelcmb') && ~csdflg
    % no cross-spectrum needs to be computed, hence remove the combinations from cfg
    cfg = rmfield(cfg, 'channelcmb');
  end
  
  % ensure that channelselection and selection of channelcombinations is
  % perfomed consistently
  cfg.channel = ft_channelselection(cfg.channel, data.label);
  if isfield(cfg, 'channelcmb')
    cfg.channelcmb = ft_channelcombination(cfg.channelcmb, data.label);
    % check whether there are channels in channelcmb that are not in cfg.channel
    tmpcmbchan = unique(cfg.channelcmb);
    for ichan = 1:length(tmpcmbchan)
      if ~any(strcmp(tmpcmbchan{ichan},cfg.channel))
        error('channels in cfg.channelcmb not present in cfg.channel')
      end
    end
    selchan = unique([cfg.channel(:); cfg.channelcmb(:)]);
  else
    selchan = cfg.channel;
  end
  
  % subselect the required channels
  data = ft_selectdata(data, 'channel', selchan);
  
  % determine the corresponding indices of all channels
  chanind    = match_str(data.label, cfg.channel);
  nchan      = size(chanind,1);
  if csdflg
    % determine the corresponding indices of all channel combinations
    chancmbind = zeros(size(cfg.channelcmb));
    for k=1:size(cfg.channelcmb,1)
      chancmbind(k,1) = strmatch(cfg.channelcmb(k,1), data.label, 'exact');
      chancmbind(k,2) = strmatch(cfg.channelcmb(k,2), data.label, 'exact');
    end
    nchancmb   = size(chancmbind,1);
    chanind    = unique([chanind(:); chancmbind(:)]);
    nchan      = length(chanind);
    cutdatindcmb = zeros(size(chancmbind));
    for ichan = 1:nchan
      cutdatindcmb(find(chancmbind == chanind(ichan))) = ichan;
    end
  end
  
  % determine trial characteristics
  ntrials = numel(data.trial);
  trllength = zeros(1, ntrials);
  for itrial = 1:ntrials
    trllength(itrial) = size(data.trial{itrial}, 2);
  end
  if strcmp(cfg.pad, 'maxperlen')
    padding = max(trllength);
    cfg.pad = padding/data.fsample;
  else
    padding = cfg.pad*data.fsample;
    if padding<max(trllength)
      error('the specified padding is too short');
    end
  end
  
  % correct foi and implement foilim 'backwards compatibility'
  if ~isempty(cfg.foi) && ~isempty(cfg.foilim)
    error('use either cfg.foi or cfg.foilim')
  elseif ~isempty(cfg.foilim)
    % get the full foi in the current foilim and set it too be used as foilim
    fboilim = round(cfg.foilim ./ (data.fsample ./ (cfg.pad*data.fsample))) + 1;
    fboi    = fboilim(1):1:fboilim(2);
    cfg.foi = (fboi-1) ./ cfg.pad;
  else
    % correct foi if foilim was empty and try to correct t_ftimwin (by detecting whether there is a constant factor between foi and t_ftimwin: cyclenum)
    oldfoi = cfg.foi;
    fboi   = round(cfg.foi ./ (data.fsample ./ (cfg.pad*data.fsample))) + 1;
    cfg.foi    = (fboi-1) ./ cfg.pad; % boi - 1 because 0 Hz is included in fourier output
    if strcmp(cfg.correctt_ftimwin,'yes')
      cyclenum = oldfoi .* cfg.t_ftimwin;
      cfg.t_ftimwin = cyclenum ./ cfg.foi;
    end
  end
  
  % tapsmofrq compatibility between functions (make it into a vector if it's not)
  if isfield(cfg,'tapsmofrq')
    if strcmp(cfg.method,'mtmconvol') && length(cfg.tapsmofrq) == 1 && length(cfg.foi) ~= 1
      cfg.tapsmofrq = ones(length(cfg.foi),1) * cfg.tapsmofrq;
    elseif strcmp(cfg.method,'mtmfft') && length(cfg.tapsmofrq) ~= 1
      warning('cfg.tapsmofrq should be a single number when cfg.method = mtmfft, now using only the first element')
      cfg.tapsmofrq = cfg.tapsmofrq(1);
    end
  end
  
  % options that don't change over trials
  if isfield(cfg,'tapsmofrq')
    options = {'pad', cfg.pad, 'freqoi', cfg.foi, 'tapsmofrq', cfg.tapsmofrq, 'polyremoval', cfg.polyremoval};
  else
    options = {'pad', cfg.pad, 'freqoi', cfg.foi, 'polyremoval', cfg.polyremoval};
  end
  
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Main loop over trials, inside fourierspectra are obtained and transformed into the appropriate outputs
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % this is done on trial basis to save memory
  
  ft_progress('init', cfg.feedback, 'processing trials');
  for itrial = 1:ntrials
    %disp(['processing trial ' num2str(itrial) ': ' num2str(size(data.trial{itrial},2)) ' samples']);
    fbopt.i = itrial;
    fbopt.n = ntrials;
    
    dat = data.trial{itrial}; % chansel has already been performed
    time = data.time{itrial};
    
    % Perform specest call and set some specifics
    clear spectrum % in case of very large trials, this lowers peak mem usage a bit
    switch cfg.method
           
      case 'mtmconvol'
        [spectrum_mtmconvol,ntaper,foi,toi] = ft_specest_mtmconvol(dat, time, 'timeoi', cfg.toi, 'timwin', cfg.t_ftimwin, 'taper', ...
          cfg.taper, options{:}, 'dimord', 'chan_time_freqtap', 'feedback', fbopt);
 
        % the following variable is created to keep track of the number of
        % trials per time bin and is needed for proper normalization if
        % keeprpt==1 and the triallength is variable
        if itrial==1, trlcnt = zeros(1, numel(foi), numel(toi)); end  
        
        hastime = true;
        % error for different number of tapers per trial
        if (keeprpt == 4) && any(ntaper(:) ~= ntaper(1))
          error('currently you can only keep trials AND tapers, when using the number of tapers per frequency is equal across frequency')
        end
        % create tapfreqind for later indexing
        freqtapind = [];
        tempntaper = [0; cumsum(ntaper(:))];
        for iindfoi = 1:numel(foi)
          freqtapind{iindfoi} = tempntaper(iindfoi)+1:tempntaper(iindfoi+1);
        end
     
      case 'mtmfft'
        [spectrum,ntaper,foi] = ft_specest_mtmfft(dat, time, 'taper', cfg.taper, options{:}, 'feedback', fbopt);
        hastime = false;
     
      case 'wavelet'  
        [spectrum,foi,toi] = ft_specest_wavelet(dat, time, 'timeoi', cfg.toi, 'width', cfg.width, 'gwidth', cfg.gwidth,options{:});
        
        % the following variable is created to keep track of the number of
        % trials per time bin and is needed for proper normalization if
        % keeprpt==1 and the triallength is variable
        if itrial==1, trlcnt = zeros(1, numel(foi), numel(toi)); end  
        
        hastime = true;
        % create FAKE ntaper (this requires very minimal code change below for compatibility with the other specest functions)
        ntaper = ones(1,numel(foi));
        % modify spectrum for same reason as fake ntaper
        spectrum = reshape(spectrum,[1 nchan numel(foi) numel(toi)]);
             
      case 'hilbert'  
        [spectrum,foi,toi] = ft_specest_hilbert(dat, time, 'timeoi', cfg.toi, 'filttype', cfg.filttype, 'filtorder', cfg.filtorder, 'filtdir', cfg.filtdir, 'width', cfg.width, options{:});
        hastime = true;
        % create FAKE ntaper (this requires very minimal code change below for compatibility with the other specest functions)
        ntaper = ones(1,numel(foi));
        % modify spectrum for same reason as fake ntaper
        spectrum = reshape(spectrum,[1 nchan numel(foi) numel(toi)]);
        
      otherwise
        error('method %s is unknown or not yet implemented with new low level functions', cfg.method);
    end % switch
    
    % Set n's
    maxtap = max(ntaper);
    nfoi   = numel(foi);
    if hastime
      ntoi = numel(toi);
    else
      ntoi = 1; % this makes the same code compatible for hastime = false, as time is always the last dimension, and if singleton will disappear
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Memory allocation
    % by default, everything is has the time dimension, if not, some specifics are performed
    if itrial == 1
      % allocate memory to output variables
      if keeprpt == 1 % cfg.keeptrials,'no' &&  cfg.keeptapers,'no'
        if powflg, powspctrm     = zeros(nchan,nfoi,ntoi,cfg.precision);             end
        if csdflg, crsspctrm     = complex(zeros(nchancmb,nfoi,ntoi,cfg.precision)); end
        if fftflg, fourierspctrm = complex(zeros(nchan,nfoi,ntoi,cfg.precision));    end
        dimord    = 'chan_freq_time';
      elseif keeprpt == 2 % cfg.keeptrials,'yes' &&  cfg.keeptapers,'no'
        if powflg, powspctrm     = nan+zeros(ntrials,nchan,nfoi,ntoi,cfg.precision);                                                                 end
        if csdflg, crsspctrm     = complex(nan+zeros(ntrials,nchancmb,nfoi,ntoi,cfg.precision),nan+zeros(ntrials,nchancmb,nfoi,ntoi,cfg.precision)); end
        if fftflg, fourierspctrm = complex(nan+zeros(ntrials,nchan,nfoi,ntoi,cfg.precision),nan+zeros(ntrials,nchan,nfoi,ntoi,cfg.precision));       end
        dimord    = 'rpt_chan_freq_time';
      elseif keeprpt == 4 % cfg.keeptrials,'yes' &&  cfg.keeptapers,'yes'         % FIXME this works only if all frequencies have the same number of tapers (ancient fixme)
        if powflg, powspctrm     = zeros(ntrials*maxtap,nchan,nfoi,ntoi,cfg.precision);             end
        if csdflg, crsspctrm     = complex(zeros(ntrials*maxtap,nchancmb,nfoi,ntoi,cfg.precision)); end
        if fftflg, fourierspctrm = complex(zeros(ntrials*maxtap,nchan,nfoi,ntoi,cfg.precision));    end
        dimord    = 'rpttap_chan_freq_time';
      end
      if ~hastime
        dimord = dimord(1:end-5); % cut _time
      end
      
      % prepare calcdof
      if strcmp(cfg.calcdof,'yes')
        if hastime
          dof = zeros(nfoi,ntoi);
          %dof = zeros(ntrials,nfoi,ntoi);
        else
          dof = zeros(nfoi,1);
          %dof = zeros(ntrials,nfoi);
        end
      end
      
      % prepare cumtapcnt
      switch cfg.method %% IMPORTANT, SHOULD WE KEEP THIS SPLIT UP PER METHOD OR GO FOR A GENERAL SOLUTION NOW THAT WE HAVE SPECEST
        case 'mtmconvol'
          cumtapcnt = zeros(ntrials,nfoi);
        case 'mtmfft'
          cumtapcnt = zeros(ntrials,1);
      end
      
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%% Create output
    if keeprpt~=4
    
      for ifoi = 1:nfoi
            
        % mtmconvol is a special case and needs special processing
        if strcmp(cfg.method,'mtmconvol')
          spectrum = reshape(permute(spectrum_mtmconvol(:,:,freqtapind{ifoi}),[3 1 2]),[ntaper(ifoi) nchan 1 ntoi]);
          foiind = ones(1,nfoi);
        else
          foiind = 1:nfoi; % by using this vector below for indexing, the below code does not need to be duplicated for mtmconvol
        end
            
        % set ingredients for below
        acttboi  = squeeze(~isnan(spectrum(1,1,foiind(ifoi),:)));
        nacttboi = sum(acttboi);
        if ~hastime
          acttboi  = 1;
          nacttboi = 1;
        elseif sum(acttboi)==0
          %nacttboi = 1;
        end
        acttap = squeeze(~isnan(spectrum(:,1,foiind(ifoi),find(acttboi,1))));
        acttap = logical([ones(ntaper(ifoi),1);zeros(size(spectrum,1)-ntaper(ifoi),1)]);
        if powflg
          powdum = abs(spectrum(acttap,:,foiind(ifoi),acttboi)) .^2;
          % sinetaper scaling is disabled, because it is not consistent with the other
          % tapers. if scaling is required, please specify cfg.taper =
          % 'sine_old'
          
%         if isfield(cfg,'taper') && strcmp(cfg.taper, 'sine')
%             %sinetapscale = zeros(ntaper(ifoi),nfoi);  % assumes fixed number of tapers
%             sinetapscale = zeros(ntaper(ifoi),1);  % assumes fixed number of tapers
%             for isinetap = 1:ntaper(ifoi)  % assumes fixed number of tapers
%               sinetapscale(isinetap,:) = (1 - (((isinetap - 1) ./ ntaper(ifoi)) .^ 2));
%             end
%             sinetapscale = reshape(repmat(sinetapscale,[1 1 nchan ntoi]),[ntaper(ifoi) nchan 1 ntoi]);
%             powdum = powdum .* sinetapscale;
%           end
        end
        if fftflg
          fourierdum = spectrum(acttap,:,foiind(ifoi),acttboi);
        end
        if csdflg
          csddum =      spectrum(acttap,cutdatindcmb(:,1),foiind(ifoi),acttboi) .* ...
                   conj(spectrum(acttap,cutdatindcmb(:,2),foiind(ifoi),acttboi));
        end
         
        % switch between keep's
        switch keeprpt
              
          case 1 % cfg.keeptrials,'no' &&  cfg.keeptapers,'no'
            if exist('trlcnt', 'var'),
              trlcnt(1, ifoi, :) = trlcnt(1, ifoi, :) + shiftdim(double(acttboi(:)'),-1);
            end

            if powflg
              powspctrm(:,ifoi,acttboi) = powspctrm(:,ifoi,acttboi) + (reshape(mean(powdum,1),[nchan 1 nacttboi]) ./ ntrials);
              %powspctrm(:,ifoi,~acttboi) = NaN;
            end
            if fftflg
              fourierspctrm(:,ifoi,acttboi) = fourierspctrm(:,ifoi,acttboi) + (reshape(mean(fourierdum,1),[nchan 1 nacttboi]) ./ ntrials);
              %fourierspctrm(:,ifoi,~acttboi) = NaN;
            end
            if csdflg
              crsspctrm(:,ifoi,acttboi) = crsspctrm(:,ifoi,acttboi) + (reshape(mean(csddum,1),[nchancmb 1 nacttboi]) ./ ntrials);
              %crsspctrm(:,ifoi,~acttboi) = NaN;
            end
                  
          case 2 % cfg.keeptrials,'yes' &&  cfg.keeptapers,'no'
            if powflg
              powspctrm(itrial,:,ifoi,acttboi) = reshape(mean(powdum,1),[nchan 1 nacttboi]);
              powspctrm(itrial,:,ifoi,~acttboi) = NaN;
            end
            if fftflg
              fourierspctrm(itrial,:,ifoi,acttboi) = reshape(mean(fourierdum,1), [nchan 1 nacttboi]);
              fourierspctrm(itrial,:,ifoi,~acttboi) = NaN;
            end
            if csdflg
              crsspctrm(itrial,:,ifoi,acttboi) = reshape(mean(csddum,1), [nchancmb 1 nacttboi]);
              crsspctrm(itrial,:,ifoi,~acttboi) = NaN;
            end
                            
        end % switch keeprpt
        
        % do calcdof  dof = zeros(numper,numfoi,numtoi);
        if strcmp(cfg.calcdof,'yes')
          if hastime
            acttimboiind = ~isnan(squeeze(spectrum(1,1,foiind(ifoi),:)));
            dof(ifoi,acttimboiind) = ntaper(ifoi) + dof(ifoi,acttimboiind);
          else % hastime = false
            dof(ifoi) = ntaper(ifoi) + dof(ifoi);
          end
        end
      end %ifoi
        
    else
      if strcmp(cfg.method,'mtmconvol')
        spectrum = permute(reshape(spectrum_mtmconvol,[nchan ntoi ntaper(1) nfoi]),[3 1 4 2]);
      end
        
      rptind = reshape(1:ntrials .* maxtap,[maxtap ntrials]);
      currrptind = rptind(:,itrial);
      if powflg
        powspctrm(currrptind,:,:) = abs(spectrum).^2;
      end
      if fftflg
        fourierspctrm(currrptind,:,:,:) = spectrum;
      end
      if csdflg
        crsspctrm(currrptind,:,:,:) =          spectrum(cutdatindcmb(:,1),:,:) .* ...
                                          conj(spectrum(cutdatindcmb(:,2),:,:));
      end
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % set cumptapcnt
    switch cfg.method %% IMPORTANT, SHOULD WE KEEP THIS SPLIT UP PER METHOD OR GO FOR A GENERAL SOLUTION NOW THAT WE HAVE SPECEST
      case {'mtmconvol' 'wavelet'}
        cumtapcnt(itrial,:) = ntaper;
      case 'mtmfft'
        cumtapcnt(itrial,1) = ntaper(1); % fixed number of tapers? for the moment, yes, as specest_mtmfft computes only one set of tapers
    end
    
  end % for ntrials
  ft_progress('close');
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% END: Main loop over trials
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
  % re-normalise the TFRs if keeprpt==1
  if (strcmp(cfg.method, 'mtmconvol') || strcmp(cfg.method, 'wavelet')) && keeprpt==1 
    nanmask = trlcnt==0;
    if powflg
      powspctrm = powspctrm.*ntrials;
      powspctrm = powspctrm./trlcnt(ones(size(powspctrm,1),1),:,:);
      powspctrm(nanmask(ones(size(powspctrm,1),1),:,:)) = nan;
    end
    if fftflg
      fourierspctrm = fourierspctrm.*ntrials;
      fourierspctrm = fourierspctrm./trlcnt(ones(size(fourierspctrm,1),1),:,:);
      fourierspctrm(nanmask(ones(size(fourierspctrm,1),1),:,:)) = nan;
    end
    if csdflg
      crsspctrm = crsspctrm.*ntrials;
      crsspctrm = crsspctrm./trlcnt(ones(size(crsspctrm,1),1),:,:);
      crsspctrm(nanmask(ones(size(crsspctrm,1),1),:,:)) = nan;
    end
  end
  
  % set output variables
  freq = [];
  freq.label = data.label;
  freq.dimord = dimord;
  freq.freq   = foi;
  hasdc       = find(foi==0);
  hasnyq      = find(foi==data.fsample./2);
  hasdc_nyq   = [hasdc hasnyq];
  if exist('toi','var')
    freq.time = toi;
  end
  if powflg
    % correct the 0 Hz or Nyqist bin if present, scaling with a factor of 2 is only appropriate for ~0 Hz
    if ~isempty(hasdc_nyq)
      if keeprpt>1
        powspctrm(:,:,hasdc_nyq,:) = powspctrm(:,:,hasdc_nyq,:)./2;
      else
        powspctrm(:,hasdc_nyq,:) = powspctrm(:,hasdc_nyq,:)./2;
      end
    end
    freq.powspctrm = powspctrm;
  end
  if fftflg
    % correct the 0 Hz or Nyqist bin if present, scaling with a factor of 2 is only appropriate for ~0 Hz
    if ~isempty(hasdc_nyq)
      if keeprpt>1
        fourierspctrm(:,:,hasdc_nyq,:) = fourierspctrm(:,:,hasdc_nyq,:)./sqrt(2);
      else
        fourierspctrm(:,hasdc_nyq,:) = fourierspctrm(:,hasdc_nyq,:)./sqrt(2);
      end
    end
    freq.fourierspctrm = fourierspctrm;
  end
  if csdflg
    % correct the 0 Hz or Nyqist bin if present, scaling with a factor of 2 is only appropriate for ~0 Hz
    if ~isempty(hasdc_nyq)
      if keeprpt>1
        crsspctrm(:,:,hasdc_nyq,:) = crsspctrm(:,:,hasdc_nyq,:)./2;
      else
        crsspctrm(:,hasdc_nyq,:) = crsspctrm(:,hasdc_nyq,:)./2;
      end
    end
    freq.labelcmb  = cfg.channelcmb;
    freq.crsspctrm = crsspctrm;
  end
  if strcmp(cfg.calcdof,'yes');
    freq.dof = 2 .* dof;
  end;
  if strcmp(cfg.method,'mtmfft') && (keeprpt == 2 || keeprpt == 4)
    freq.cumsumcnt = trllength';
  end
  if exist('cumtapcnt','var')
    freq.cumtapcnt = cumtapcnt;
  end
  
  % backwards compatability of foilim
  if ~isempty(cfg.foilim)
    cfg = rmfield(cfg,'foi');
  else
    cfg = rmfield(cfg,'foilim');
  end
  
  % accessing this field here is needed for the configuration tracking
  % by accessing it once, it will not be removed from the output cfg
  cfg.outputfile;
  cfg.outputlock;
 
  % get the output cfg
  cfg = ft_checkconfig(cfg, 'trackconfig', 'off', 'checksize', 'yes');
  
  if isfield(data, 'grad'),
    freq.grad = data.grad; 
  end   % remember the gradiometer array
  if isfield(data, 'elec'),
    freq.elec = data.elec;
  end   % remember the electrode array
  
  % add information about the version of this function to the configuration
  cfg.version.name = mfilename('fullpath');
  cfg.version.id = '$Id: ft_freqanalysis.m 3867 2011-07-19 07:08:50Z jansch $';
  
  % add information about the Matlab version used to the configuration
  cfg.callinfo.matlab = version();
  
  % add information about the function call to the configuration
  cfg.callinfo.proctime = toc(ftFuncTimer);
  cfg.callinfo.calltime = ftFuncClock;
  cfg.callinfo.user = getusername();
  
  % remember the configuration details of the input data
  try cfg.previous = data.cfg; end
  
  % remember the exact configuration details in the output
  freq.cfg = cfg;
  
end % IF OLD OR NEW IMPLEMENTATION

% copy the trial specific information into the output
if isfield(cfg, 'keeptrials') && strcmp(cfg.keeptrials, 'yes') && isfield(data, 'trialinfo'),
  freq.trialinfo = data.trialinfo;
end

% the output data should be saved to a MATLAB file
if ~isempty(cfg.outputfile)
  mutexlock(cfg.outputlock);
  savevar(cfg.outputfile, 'freq', freq); % use the variable name "data" in the output file
  mutexunlock(cfg.outputlock);
end
