% Author: Ofir Weisse, mail: oweisse (at) umich.edu, www.ofirweisse.com
%
% MIT License
%
% Copyright (c) 2016 oweisse
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
%%
MATLAB_SUBSCRIPT_STARTS_FROM_1 = 1;
CHIP_SELECT                    = 8 + MATLAB_SUBSCRIPT_STARTS_FROM_1;
READ                           = 9 + MATLAB_SUBSCRIPT_STARTS_FROM_1;
WRITE                          = 10 + MATLAB_SUBSCRIPT_STARTS_FROM_1;
HIGH_LOW_BYTE                  = 11 + MATLAB_SUBSCRIPT_STARTS_FROM_1;
CONTROL_PINS                   = [CHIP_SELECT, READ, WRITE, HIGH_LOW_BYTE ];


% remoteTempFile - File path to write to, from the perspective of the logic app.
% If the logic app is running on a remote machine, this is the network path.
% In my case, z: was mapped to a network location.
remoteTempFile       = 'z:/saleae/logicValues.bin';

% localTempFile - Can be the same as remoteTempFile, if running on a single machine.
% Otherwise, this is the file path from the perspective of this Matlab code
localTempFile        = '/Users/username/Documents/saleae/logicValues.bin';

%%
logicHost    = '10.211.55.5'; %IP of machine running the logic application
logicAnlyzer = SaleaeLogicAnlyzerManager( logicHost );

%%
sampleRate             = 12.5e6;
recordLengthInSeconds  = 0.5;
recordLengthInSamples  = recordLengthInSeconds * sampleRate;

% Sometimes the logic analyzer returns with less than the requested samples.
% I wrote some code that re-tries until at leastconsecutive minimumRequiredSamples
% are collected
minimumRequiredSamples = 0.5 * sampleRate;

logicAnlyzer.SetActiveDigitalChannels( 0:11 );
logicAnlyzer.SetDigitalSampleRate    ( sampleRate );
logicAnlyzer.SetCaptureLengthSamples ( recordLengthInSamples );

% This is usefull inside a loop, as the connection might be lost:
if ~logicAnlyzer.TestConnection()
    disp( 'lost connection to logic analyzer, redoing iteration' );
    pause(1);
    delete(logicAnlyzer);
    logicAnlyzer = SaleaeLogicAnlyzerManager(logicHost);
end

%% Get single aquisition and stop
try
  digitalPins = ...
    logicAnlyzer.GetAtLeastNDigitalSamples( remoteTempFile,                     ...
                                            localTempFile,                      ...
                                            minimumRequiredSamples );
catch
    disp( 'caught exception, continuing' );
end

% The logic app returns binary values packed in uint16_t. ExtractBitsFromDigitalPins
% extracts these values to a more convinient way, so it can be easily accessed
digitalVals = ExtractBitsFromDigitalPins( digitalPins, CONTROL_PINS );

chipSelectPinLogicalValues  = digitalVals( :, CHIP_SELECT );
readPinLogicalValues        = digitalVals( :, READ );
writePinLogicalValues       = digitalVals( :, WRITE );
highLowBytePinLogicalValues = digitalVals( :, HIGH_LOW_BYTE );
