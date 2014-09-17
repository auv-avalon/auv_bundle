require 'models/blueprints/auv'
require 'models/blueprints/localization'
#require 'models/orogen/wall'

using_task_library 'auv_rel_pos_controller'
using_task_library 'wall_servoing'
using_task_library 'sonar_feature_estimator'
using_task_library 'buoy'

module Buoy
  class DetectorNewCmp < Syskit::Composition
      event :buoy_found


        if ::CONFIG_HACK == 'default'
            buoy_conf = ['default']
        elsif ::CONFIG_HACK == 'simulation'
            buoy_conf = ['simulation']
        elsif ::CONFIG_HACK == 'dagon'
            buoy_conf = ['default']
        end
        


      add_main Buoy::Detector.with_conf(*buoy_conf), as: 'main'
      add Base::ImageProviderSrv, as: 'front_camera'

      connect front_camera_child => main_child
      export main_child.buoy_port

      on :buoy_found do |e| 
        ::Robot.info "FOUND BUOY!!!!!!!!!!!!!!!!!!!!!!!"
        e
      end
  end

  class ControllerNewCmp < Syskit::Composition
      add_main Buoy::ServoingOnWall, as: 'main'
      add WallServoing::WallOrientationSrv, as: 'wall'
      add Base::OrientationSrv, as: 'pose'
      add Buoy::DetectorNewCmp, as: 'detector'

      connect detector_child => main_child
      connect pose_child => main_child
      connect wall_child => main_child

      export main_child.aligned_position_cmd_port, as: 'aligned_position_command'
      export main_child.world_cmd_port, as: 'world_command'
      provides Base::WorldXYZPositionControllerSrv, as: 'controller'

      event :passive_buoy_searching
      event :buoy_servoing
  end
end
