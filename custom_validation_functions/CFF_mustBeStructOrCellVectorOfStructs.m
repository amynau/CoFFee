function CFF_mustBeStructOrCellVectorOfStructs(a)
%CFF_MUSTBESTRUCTORCELLVECTOROFSTRUCTS  Validation function
%
%   See also CFF_MUSTBECELLVECTOROFSTRUCTS, CFF_MUSTBESTRUCT

%   Copyright 2024-2024 Alexandre Schimel
%   Licensed under MIT. Details on https://github.com/alexschimel/CoFFee/

condition = isstruct(a) || (iscell(a) && isvector(a) && all(cellfun(@isstruct, a)));
if ~condition
    eidType = 'CoFFee:notValid';
    msgType = 'Input must be a structure or a cell vector of structures.';
    throwAsCaller(MException(eidType, msgType))
end
end