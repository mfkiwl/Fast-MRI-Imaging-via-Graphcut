function [varargout] = funname(varargin)

% LMOUTR computes the la/mu parameters of a point projected to a triangle
%
% Use as
%   [la, mu, dist] = lmoutr(v1, v2, v3, r)
% where v1, v2 and v3 are three vertices of the triangle, and r is 
% the point that is projected onto the plane spanned by the vertices

% Copyright (C) 2002-2009, Robert Oostenveld
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
% $Id: lmoutr.m 3486 2011-05-10 09:29:30Z roboos $

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This is the Matlab implementation.
% The mex file is many times faster and therefore preferred.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [la, mu, dist] = lmoutr(v1, v2, v3, r);
% 
% % compute la/mu parameters
% vec0 = r  - v1;
% vec1 = v2 - v1;
% vec2 = v3 - v2;
% vec3 = v3 - v1;
% 
% tmp   = [vec1' vec3'] \ (vec0');
% la    = tmp(1);
% mu    = tmp(2);
% 
% % determine the projection onto the plane of the triangle
% proj  = v1 + la*vec1 + mu*vec3;
% 
% % determine the distance from the original point to its projection
% dist = norm(r-proj);

% compile the missing mex file on the fly
% remember the original working directory
pwdir = pwd;

% determine the name and full path of this function
funname = mfilename('fullpath');
mexsrc  = [funname '.c'];
[mexdir, mexname] = fileparts(funname);

try
  % try to compile the mex file on the fly
  warning('trying to compile MEX file from %s', mexsrc);
  cd(mexdir);
  
  if ispc
    mex -I. -c geometry.c
    mex -I. -c lmoutr.c ; mex lmoutr.c lmoutr.obj geometry.obj
  else
    mex -I. -c geometry.c
    mex -I. -c lmoutr.c ; mex -o lmoutr lmoutr.o geometry.o
  end
  
  cd(pwdir);
  success = true;

catch
  % compilation failed
  disp(lasterr);
  error('could not locate MEX file for %s', mexname);
  cd(pwdir);
  success = false;
end

if success
  % execute the mex file that was juist created
  funname   = mfilename;
  funhandle = str2func(funname);
  [varargout{1:nargout}] = funhandle(varargin{:});
end
