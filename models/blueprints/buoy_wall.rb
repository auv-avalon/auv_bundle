require 'models/blueprints/auv'
require 'models/blueprints/localization'
require 'models/orogen/wall'

using_task_library 'auv_rel_pos_controller'
using_task_library 'wall_servoing'
using_task_library 'sonar_feature_estimator'
using_task_library 'buoy'

module Buoy
  class DetectorNewCmp < Syskit::Composition
      add_main Buoy::Detector, as: 'main'
      add Base::ImageProviderSrv, as: 'front_camera'

      connect front_camera_child => main_child

      export main_child.buoy_port
  end

  class ControllerNewCmp < Syskit::Composition
      add_main Buoy::ServoingOnWall, as: 'main'
      add Wall::WallOrientationSrv, as: 'wall'
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
