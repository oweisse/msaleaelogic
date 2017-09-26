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

classdef SaleaeLogicAnlyzerManager < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here

    properties
        scopeHost;
        scopePort;
        interface;
        log;
        logicHost;
        logicPort;
    end

    properties (Constant)
        MODULE          = 'SaleaeLogicAnlyzerManager'
        LOGS_DIR        = 'logs'
        HOST            = 'localhost'
        PORT            = 10429
    end

    methods
        function obj = SaleaeLogicAnlyzerManager( host )
            if nargin < 1
                logicHost_ = obj.HOST;
            else
                logicHost_ = host;
            end

            logicPort_ = obj.PORT;
            obj.StartLogger();
            obj.InitLogicConnection( logicHost_,  logicPort_ );

            obj.log.info( obj.MODULE, sprintf( 'SaleaeLogicAnlyzerManager created! Host: %s:%d', obj.scopeHost, obj.scopePort ) );
        end

      function [] = StartLogger( obj )
            if exist( obj.LOGS_DIR, 'dir' ) == 0
                mkdir( obj.LOGS_DIR );
            end

            timestamp           = datestr(now, 'yyyy-mm-dd_HH-MM-SS.FFF');
            logFileName         = sprintf( 'logs/SaleaeLogicAnlyzerManager-%s.log', timestamp );
            obj.log             = log4m.getLogger(logFileName);
            obj.log.setLogLevel           ( log4m.ALL );
            obj.log.setCommandWindowLevel ( log4m.ALL );
        end

        function [] = InitLogicConnection( obj, logicHost,  logicPort )
            obj.logicHost                  = logicHost;
            obj.logicPort                  = logicPort;
            obj.interface                  = tcpclient( logicHost, logicPort );
        end

        function [] = SetActiveDigitalChannels( obj, channels )
            channelsString    = '';
            for singleChannel = channels
               channelsString = [ channelsString, num2str( singleChannel ), ',' ];
            end
            cmd = sprintf( 'SET_ACTIVE_CHANNELS, digital_channels, %s', channelsString );
            obj.SendCommand( cmd );
        end

        function [] = SetDigitalSampleRate( obj, sampleRate )
            cmd = sprintf( 'SET_SAMPLE_RATE, %s, 0', num2str( sampleRate ) );
            obj.SendCommand( cmd );
        end

        function [] = SetCaptureLengthSamples( obj, numSamplesToTake )
            cmd = sprintf( 'SET_NUM_SAMPLES, %s', num2str( numSamplesToTake ) );
            obj.SendCommand( cmd );
        end

        function [ captureCompletedSuccessfully ] = StartCaputreAndWait( obj, timeout, checkCaptureDoneDelta )
            % Init default parameters:
            if nargin < 2
               timeout = 10;
            end

            if nargin < 3
               checkCaptureDoneDelta = 0.1;
            end

            % Do capture:
            cmd                          = sprintf( 'CAPTURE' );
            captureCompletedSuccessfully = false;

            obj.SendCommand( cmd );
            tic;
            while toc < timeout
               if obj.IsCaptureCompleted() == true
                   captureCompletedSuccessfully = true;
                   break
               else
                  pause( checkCaptureDoneDelta );
               end
            end
        end

        function [result] = IsCaptureCompleted( obj )
            TRUE_STRING = 'TRUE';

            cmd      = sprintf( 'IS_PROCESSING_COMPLETE' );
            response = obj.SendCommand( cmd );
            result   = strncmpi( response, TRUE_STRING, length( TRUE_STRING ) );
        end

        function [response] = ExportCaptureToBinaryFile( obj, filePath )
            WAIT_FOR_RESPONSE_TIMEOUT = 10;

            cmd      = sprintf('EXPORT_DATA2, %s, ALL_CHANNELS, ALL_TIME, BINARY, EACH_SAMPLE, NO_SHIFT, 16', filePath);
            response = obj.SendCommand( cmd, WAIT_FOR_RESPONSE_TIMEOUT);
        end

        function [ digitalPins ] = GetDigitalSamples( obj, remoteTempFile, localTempFile )
            %remoteTempFile - file path in saleae removte host
            %localTempFile - should be path to remoteTempFile, but from the
            %                perspective of this matlab code

            captureSuccessfull = obj.StartCaputreAndWait();
            if ~captureSuccessfull
               warning( 'StartCaputreAndWait returned failure' );
            end

            obj.ExportCaptureToBinaryFile( remoteTempFile );

            fid = fopen( localTempFile );
            digitalPins = fread(fid, Inf, '*uint16');
            fclose( fid );
        end

        function [ digitalPins ] = GetAtLeastNDigitalSamples(   obj,            ...
                                                                remoteTempFile, ...
                                                                localTempFile,  ...
                                                                minimumRequiredSamples )
            while true
                digitalPins    = obj.GetDigitalSamples( remoteTempFile, localTempFile );
                samplesAquired = length( digitalPins );

                if samplesAquired > minimumRequiredSamples
                    break;
                end

                disp( 'Not enough samples aquired - re aquiring..' );
            end
        end

        function [ result ] = SendCommand( obj, cmd, timeoutForResponse )
            PAUSE_INTERVAL = 0.1;
            result         = [];

            if nargin < 3
                timeoutForResponse = 0.2;
            end

            obj.log.trace( obj.MODULE, sprintf( '>> %s', cmd ) )
            write( obj.interface, uint8([ cmd, 0 ]) );

            tic;
            pause(PAUSE_INTERVAL);
            while toc < timeoutForResponse && obj.interface.BytesAvailable == 0
                  pause( PAUSE_INTERVAL );
                  fprintf( '.' );
            end

            if obj.interface.BytesAvailable > 0
                resultRaw = read( obj.interface, obj.interface.BytesAvailable );
                result    = char( resultRaw );
                obj.log.trace( obj.MODULE, sprintf('<< %s', result ) );
            end
        end

        function delete( obj )
            delete( obj.interface );
            obj.log.info( obj.MODULE, 'Closed interface' );
        end
    end

end
