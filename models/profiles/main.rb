require "models/blueprints/auv"
require "models/blueprints/pose_auv"
require "models/blueprints/wall"
require "models/blueprints/buoy"
require "models/blueprints/pipeline"
require "models/blueprints/structure"
require "models/blueprints/localization"
require "models/blueprints/auv_cont"
require "models/blueprints/auv_control"

using_task_library 'controldev'
using_task_library 'raw_control_command_converter'
using_task_library 'avalon_control'
#using_task_library 'offshore_pipeline_detector'
using_task_library 'auv_rel_pos_controller'
#using_task_library 'buoy'

module DFKI 
    module Profiles
        profile "AUV" do

            
#            tag 'base_loop', ::Base::ControlLoop
#            tag 'drive_simpe', ::Base::ControlLoop
            tag 'final_orientation_with_z', ::Base::OrientationWithZSrv
            tag 'pose', ::Base::PoseSrv
            tag 'altimeter', ::Base::GroundDistanceSrv
            tag 'thruster',  ::Base::JointsControlledSystemSrv 
            tag 'thruster_feedback',  ::Base::JointsStatusSrv 
            tag 'down_looking_camera',  ::Base::ImageProviderSrv
            tag 'forward_looking_camera',  ::Base::ImageProviderSrv
            tag 'motion_model', ::Base::VelocitySrv
            tag 'dvl', ::Base::DVLSrv
            
            
            ############### DEPRICATED ##########################
            # Define old ControlLoops
            define 'base_loop', Base::ControlLoop.use(
                Base::OrientationWithZSrv => final_orientation_with_z_tag,
                'dist' => altimeter_tag,
                'controller' => AvalonControl::MotionControlTask,
                'controlled_system' => thruster_tag
            )
            define 'relative_control_loop', ::Base::ControlLoop.use(
                'controller' => AuvRelPosController::Task, 
                'controlled_system' => base_loop_def
            )

            define 'relative_heading_loop', ::Base::ControlLoop.use(
                'controlled_system' => base_loop_def,
                'orientation_with_z' => final_orientation_with_z_tag,
                'controller' => AuvRelPosController::Task.with_conf('default','relative_heading')
            )
            ############### /DEPRICATED #########################
            
#            define 'world_controller', AuvCont::WorldPositionCmp
            define 'world_and_xy_velo_controller', AuvCont::WorldAndXYVelocityCmp.use(
                    'joint' => thruster_tag
            )


            define 'relative_loop', Base::ControlLoop.use(
                    'orientation_with_z' => final_orientation_with_z_tag,
                    'controlled_system' => base_loop_def, 
                    'controller' => AuvRelPosController::Task.with_conf('default','relative_heading')
            )

            define 'absolute_loop', Base::ControlLoop.use(
                    'orientation_with_z' => final_orientation_with_z_tag,
                    'controlled_system' => base_loop_def, 
                    'controller' => AuvRelPosController::Task.with_conf('default','absolute_heading')
            )

            define 'buoy', Buoy::FollowerCmp.use(
                'controlled_system' => absolute_loop_def
            )

            define('drive_simple', ::Base::ControlLoop).use(
                AuvControl::JoystickCommandCmp.use(
                    "orientation_with_z" => final_orientation_with_z_tag,
                    "dist" => altimeter_tag
                ), 
                'controlled_system' => base_loop_def    
            )

            
            ############### Localization stuff  ######################

            define 'hough_detector', Localization::HoughDetector.use(
                Base::OrientationSrv => final_orientation_with_z_tag,
                'dvl' => dvl_tag
            )

            define 'localization', Localization::ParticleDetector.use(
                dvl_tag,
                Base::OrientationWithZSrv => final_orientation_with_z_tag, 
                'hough' => hough_detector_def,
                'hb' => thruster_feedback_tag,
                'ori' => final_orientation_with_z_tag
            )
            
            define 'position_control_loop', ::Base::ControlLoop.use(
                'controller' =>  AvalonControl::PositionControlTask, 
                'controlled_system' => base_loop_def,
                'pose' => localization_def
            )

            define 'ikf_orientation_estimator', PoseAuv::IKFOrientationEstimator
            define 'initial_orientation_estimator', PoseAuv::InitialOrientationEstimator

            define 'pose_estimator_blind', PoseAuv::PoseEstimator.use(
                'depth' => final_orientation_with_z_tag,
                'ori' => ikf_orientation_estimator_def,
                'model' => motion_model_tag,
                'localization' => localization_def,
                'dvl' => dvl_tag

            )

            define 'pose_estimator', PoseAuv::PoseEstimator.use(
                'depth' => final_orientation_with_z_tag,
                'ori' => ikf_orientation_estimator_def,
                'model' => motion_model_tag,


            )




            ################# Basic Movements #########################
            define 'target_move', ::AuvControl::SimplePosMove.use(
                'controlled_system' => position_control_loop_def,
                'pose' => localization_def
            )

            define 'simple_move', ::AuvControl::SimpleMove.use(
                base_loop_def,
                'reading' => final_orientation_with_z_tag
            )

            define 'wall_detector', Wall::Detector.use(
                WallServoing::SingleSonarServoing.with_conf('default','wall_right'),
                "orientation_with_z" => final_orientation_with_z_tag,
                "dead_reckoning" => motion_model_tag
            )

            define 'wall_detector_new', Wall::DetectorNew.use(
                "orientation_with_z" => final_orientation_with_z_tag,
                "dead_reckoning" => motion_model_tag
            )

            define 'wall_right', Wall::Follower.use(
                wall_detector_def,
                'controlled_system' => relative_heading_loop_def
            )

            ################ HighLevelController ######################
            define 'trajectory_move', ::AuvControl::TrajectoryMove.use(
                position_control_loop_def, 
                localization_def, 
                final_orientation_with_z_tag, 
            )
            
            define 'buoy_detector', Buoy::DetectorCmp.use(
                'camera' => forward_looking_camera_tag 
            )


            ###     New Stuff not (yet) integrated #######################
            define 'simple_move_new', AuvCont::MoveCmp.use(
                'pose' => pose_estimator_def,
                'command' => AuvControl::ConstantCommand,
                'joint' => thruster_tag
            )
            define 'target_move_new', AuvCont::PositionMoveCmp.use(
                'pose' => localization_def, 
                'command' => AuvControl::ConstantCommand, 
                'joint' => thruster_tag
            )
            
            define 'drive_simple_new', AuvCont::WorldAndXYVelocityCmp.use(
                'pose' => pose_estimator_blind_def, 
                'joint' => thruster_tag,
                'controller' => AuvControl::JoystickCommandCmp.use(
                        'orientation_with_z' => final_orientation_with_z_tag,
                        'dist' => altimeter_tag
                )
            )
            
            define 'structure_inspection', AuvCont::WorldAndXYVelocityCmp.use(
                'pose' => localization_def, 
                'joint' => thruster_tag,
                'controller' => Structure::Detector.use(
                        'camera' => forward_looking_camera_tag,
                        'ori' => final_orientation_with_z_tag
                    )
            )

            define 'structure_detector_down',Structure::Detector.use(
                'camera' => down_looking_camera_tag,
                'ori' => final_orientation_with_z_tag
            )


            define 'line_scanner', Pipeline::LineScanner.use(
               LineScanner::Task.with_conf('default'),
               'camera' => down_looking_camera_tag,
               'motion_model' => localization_def,
               #'motion_model' => motion_model_tag
            )

            define 'pipeline_detector', Pipeline::Detector.use(
                'camera' => down_looking_camera_tag,
                'laser_scanner' => line_scanner_def,
                'orientation_with_z' => final_orientation_with_z_tag
            )

            define 'pipeline_detector_new', Pipeline::Detector_new.use(
                'camera' => down_looking_camera_tag,
                'laser_scanner' => line_scanner_def,
                'orientation_with_z' => final_orientation_with_z_tag
            )
            
            define 'pipeline', Pipeline::Follower.use(
                pipeline_detector_def,
                'controlled_system' =>  relative_loop_def
            )

            define 'pipeline_new', AuvCont::WorldAndXYPositionCmp.use(
                'pose' => localization_def,
                'controller' => pipeline_detector_new_def,
                'joint' => thruster_tag
            )

            define 'wall_new_right', AuvCont::WorldAndXYPositionCmp.use(
		 WallServoing::SingleSonarServoing.with_conf('default','wall_right'),
                'pose' => localization_def,
                'controller' => wall_detector_new_def,
                'joint' => thruster_tag
            )

            define 'trajectory', AuvCont::Trajectory.use(
                AvalonControl::TrajectoryFollower.with_conf('default','hall_square'),
                'joint' => thruster_tag,
                'pose' => localization_def
            )

        end
    end
end


