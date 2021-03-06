require "rock/models/blueprints/control"
require "rock/models/blueprints/pose"
using_task_library 'base'
using_task_library 'buoy'

module Auv 
    Base::ControlLoop.declare 'AUVMotion', '/base/AUVMotionCommand'
    Base::ControlLoop.declare 'AUVRelativeMotion', '/base/AUVPositionCommand'

    data_service_type 'ModemConnectionSrv' do
            input_port 'white_light', 'bool'
            input_port 'position', '/base/samples/RigidBodyState'
            output_port 'motion_command', '/base/AUVMotionCommand'
    end

    data_service_type 'SoundSourceDirectionSrv' do
        output_port 'angle', '/base/Angle'
    end

    data_service_type 'StructuredLightPairSrv' do
        output_port 'images', ro_ptr('/base/samples/frame/FramePair')
    end
end
module Base
    data_service_type 'OrientationToCorrectSrv' do
       input_port 'heading_offset', '/base/Angle'
    end

    data_service_type 'MapSrv' do
        input_port 'buoy_samples_orange', "/avalon/feature/Buoy"
        input_port 'buoy_samples_white', "/avalon/feature/Buoy"
    end
end


