require "models/orogen/auv_control.rb"
using_task_library "auv_control"
using_task_library "gps_helper"

module GPSHelper

    class GPSWaypointsCmp < Syskit::Composition
        add_main GpsHelper::WaypointNavigation.use_conf("short_range_nav"), as: 'main'
        add ::Base::PositionSrv, as: 'gps'
        add ::Base::PoseSrv, as: 'pose'
        add ::Base::OrientationToCorrectSrv, as: 'ori'
        

        connect gps_child => main_child.gps_position_samples_port
        connect pose_child => main_child.pose_samples_port
        connect main_child => ori_child

        export main_child.target_waypoint_port, as: 'world_wommand'
        provides Base::WorldXYZRollPitchYawControllerSrv, :as => "controller"

        on :start do |e|
            @heading_reader = main_child.heading_offset_port.reader
            @distance_reader = main_child.distance_delta_port.reader
        end

        poll do
            #if !@heading_reader.nil?
            #    angle = @heading_reader.read
            #    if angle > Base::Angle(5)
            #        pose_child.reset_heading angle
            #    end
            #end
            
        end
    end
end
