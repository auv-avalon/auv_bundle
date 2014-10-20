using_task_library "auv_rel_pos_controller"
using_task_library "buoy"
require "models/blueprints/sensors"
require "models/blueprints/localization"

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
        #add_main Buoy::Survey, :as => 'servoing'
        #TODO Reintegrate modem
        #add Srv::ModemConnection, :as => 'modem'
        #connect detector => modem
        #connect modem => servoing

        camera_child.frame_port.connect_to  detector_child
        #orientation_with_z_child.connect_to  servoing_child
        #detector_child.light_port.connect_to servoing_child.light_port
        #detector_child.buoy_port.connect_to servoing_child.input_buoy_port
       
        #export servoing_child.relative_position_port, :as => 'relative_position_command'
        export detector_child.buoy_port, :as => 'orange_buoy'
        #provides Base::AUVRelativeMotionControllerSrv, :as => 'controller'

        #on :buoy_detected do |e|
        #    State.log_hack = "Buoy_found"
        #end
    end

    class DetectorCmp2 < ::Syskit::Composition
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
        add Buoy::Detector2.use_conf("bottom_white"), :as => 'detector'
        #add_main Buoy::Survey, :as => 'servoing'
        #TODO Reintegrate modem
        #add Srv::ModemConnection, :as => 'modem'
        #connect detector => modem
        #connect modem => servoing

        camera_child.frame_port.connect_to  detector_child
        #orientation_with_z_child.connect_to  servoing_child
        #detector_child.light_port.connect_to servoing_child.light_port
        #detector_child.buoy_port.connect_to servoing_child.input_buoy_port
       
        #export servoing_child.relative_position_port, :as => 'relative_position_command'
        export detector_child.buoy_port, :as => 'white_buoy'
        #provides Base::AUVRelativeMotionControllerSrv, :as => 'controller'
    end

    class DoubleBuoyCmp < ::Syskit::Composition
        add_main ::Base::MapSrv, :as => 'main'
        add ::Buoy::DetectorCmp, :as => 'orange'
        add ::Buoy::DetectorCmp2, :as => 'white'

        connect white_child.white_buoy_port => main_child.buoy_samples_white_port
        connect orange_child.orange_buoy_port => main_child.buoy_samples_orange_port

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
