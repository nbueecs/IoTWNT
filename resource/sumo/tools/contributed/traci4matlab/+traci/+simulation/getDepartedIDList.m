function departedIDList = getDepartedIDList()
%getDepartedIDList Get the IDs of departed vehicles.
%   departedIDList = getDepartedIDList() Returns a cell array of strings 
%   containing the ids of vehicles which departed (were inserted into the 
%   road network) in this time step. 

%   Copyright 2015 Universidad Nacional de Colombia,
%   Politecnico Jaime Isaza Cadavid.
%   Authors: Andres Acosta, Jairo Espinosa, Jorge Espinosa.
%   $Id: getDepartedIDList.m 20 2015-03-02 16:52:32Z afacostag $

import traci.constants
departedIDList = traci.simulation.getUniversal(constants.VAR_DEPARTED_VEHICLES_IDS);