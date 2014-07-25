using_task_library "auv_rel_pos_controller"
using_task_library "buoy"
require "models/blueprints/sensors"

module Buoy
    class DetectorCmp < ::Syskit::Composition
        event :buoy_search
        event :buoy_detected
        event :buoy_arrived
        event :buoy_lost
        event :strafing
        event :strafe_finished
        event :strafe_to_angle
        event :angle_arrived
        event :timeout

        add Base::ImageProviderSrv, :as => 'camera'
        add Base::OrientationWithZSrv, :as => "orientation_with_z"
        add Buoy::Detector, :as => 'detector'
        add_main Buoy::Survey, :as => 'servoing'
        #TODO Reintegrate modem
        #add Srv::ModemConnection, :as => 'modem'
        #connect detector => modem
        #connect modem => servoing

        camera_child.frame_port.connect_to  detector_child
        orientation_with_z_child.connect_to  servoing_child
        detector_child.light_port.connect_to servoing_child.light_port
        detector_child.buoy_port.connect_to servoing_child.input_buoy_port
       
        export servoing_child.relative_position_port, :as => 'relative_position_command'
        provides Base::AUVRelativeMotionControllerSrv, :as => 'controller'
    end

    class FollowerCmp < ::Base::ControlLoop
        event :buoy_search
        event :buoy_detected
        event :buoy_arrived
        event :buoy_lost
        event :strafing
        event :strafe_finished
        event :strafe_to_angle
        event :angle_arrived
        event :timeout
        
        add_main DetectorCmp, :as => "controller_local"

        overload 'controller', DetectorCmp
        
        #begin workaround TODO @sylvain
        #add AuvRelPosController::Task, :as => "workaround"
        #controller_child.relative_position_command_port.connect_to workaround_child 
        #end workaround



        #TODO Event forwarding
    end

end
