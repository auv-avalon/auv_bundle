require "models/blueprints/auv"
require "models/blueprints/pose_auv"
require "models/blueprints/wall"
require "models/blueprints/buoy_wall"
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
        profile "OrientationEstimation" do
            tag 'imu', ::Base::OrientationSrv
            
            
#            define "old_orientation_estimator", PoseAuv::DagonOrientationEstimatorCmp.use(
#                'imu' => imu_tag
#            )

            define 'ikf_orientation_estimator', PoseAuv::IKFOrientationEstimatorCmp

            define 'initial_orientation_estimator', PoseAuv::InitialOrientationEstimatorCmp
        end
        
        profile "PoseEstimation" do
            tag 'depth', ::Base::ZProviderSrv
            tag 'motion_model', ::Base::VelocitySrv
            tag 'orientation', ::Base::OrientationWithZSrv
            tag 'dvl', ::Base::DVLSrv
            tag 'thruster_feedback',  ::Base::JointsStatusSrv
            
            define 'pose_estimator_blind', PoseAuv::PoseEstimatorCmp.use(
                'depth' => depth_tag,
                'ori' => orientation_tag,
                'model' => motion_model_tag,
            )
            
            
            define 'hough_detector', Localization::HoughDetector.use(
                Base::OrientationSrv => orientation_tag,
                'dvl' => dvl_tag
            )

            define 'localization', Localization::ParticleDetector.use(
                dvl_tag,
                Base::OrientationWithZSrv => orientation_tag,
                'hough' => hough_detector_def,
                'hb' => thruster_feedback_tag#,
#                'ori' => orientation_with_z_tag#,
                #'velocity' => nil
            )

            define 'pose_estimator', PoseAuv::PoseEstimatorCmp.use(
                'depth' => depth_tag,
                'ori' => orientation_tag,
                'model' => motion_model_tag,
                'dvl' => dvl_tag,
                'localization' => localization_def
            )
            

        end

        profile "AUV" do
            tag 'orientation_with_z', ::Base::OrientationWithZSrv
            tag 'pose', ::Base::PoseSrv
            tag 'pose_blind', ::Base::PoseSrv
            tag 'altimeter', ::Base::GroundDistanceSrv
            tag 'thruster',  ::Base::JointsControlledSystemSrv 
            tag 'down_looking_camera',  ::Base::ImageProviderSrv
            tag 'forward_looking_camera',  ::Base::ImageProviderSrv
            tag 'motion_model', ::Base::VelocitySrv



            
            ############### DEPRICATED ##########################
            # Define old ControlLoops
            define 'base_loop', Base::ControlLoop.use(
                Base::OrientationWithZSrv => orientation_with_z_tag,
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
                'orientation_with_z' => orientation_with_z_tag,
                'controller' => AuvRelPosController::Task.with_conf('default','relative_heading')
            )
            ############### /DEPRICATED #########################
            
#            define 'world_controller', AuvCont::WorldPositionCmp
            define 'world_and_xy_velo_controller', AuvCont::WorldXYVelocityCmp.use(
                    'joint' => thruster_tag
            )


            define 'relative_loop', Base::ControlLoop.use(
                    'orientation_with_z' => orientation_with_z_tag,
                    'controlled_system' => base_loop_def, 
                    'controller' => AuvRelPosController::Task.with_conf('default','relative_heading')
            )

            define 'absolute_loop', Base::ControlLoop.use(
                    'orientation_with_z' => orientation_with_z_tag,
                    'controlled_system' => base_loop_def, 
                    'controller' => AuvRelPosController::Task.with_conf('default','absolute_heading')
            )

            define 'buoy', Buoy::FollowerCmp.use(
                'controlled_system' => absolute_loop_def
            )

            define('drive_simple', ::Base::ControlLoop).use(
                AuvControl::JoystickCommandCmp.use(
                    "orientation_with_z" => orientation_with_z_tag,
                    "dist" => altimeter_tag
                ), 
                'controlled_system' => base_loop_def    
            )

            
            ############### Localization stuff  ######################



            define 'position_control_loop', ::Base::ControlLoop.use(
                'controller' =>  AvalonControl::PositionControlTask, 
                'controlled_system' => base_loop_def,
                'pose' => pose_tag
            )





            ################# Basic Movements #########################
            define 'target_move', ::AuvControl::SimplePosMove.use(
                'controlled_system' => position_control_loop_def,
                'pose' => pose_tag
            )

            define 'simple_move', ::AuvControl::SimpleMove.use(
                base_loop_def,
                'reading' => orientation_with_z_tag
            )


            define 'wall_detector', Wall::Detector.use(
                "orientation_with_z" => orientation_with_z_tag,
                "dead_reckoning" => motion_model_tag
            ).with_conf('wall_right')


            define 'wall_detector_new', Wall::DetectorNew.use(
                "orientation_with_z" => orientation_with_z_tag,
                "dead_reckoning" => motion_model_tag
            ).with_conf('wall_right')


            define 'wall_right', Wall::Follower.use(
                wall_detector_def,
                'controlled_system' => relative_heading_loop_def
            )

            define 'sonar_structure_detector', Structure::SonarStructureServoingComp.use(
                'pose_blind' => pose_blind_tag,
            ).use_frames(
                'body' => 'body',
                'odometry' => 'map_halle',
                'sonar' => 'sonar'
            )

            define 'sonar_structure_servoing', AuvCont::WorldXYPositionCmp.use(
                'pose' => pose_blind_tag,
                'controller' => sonar_structure_detector_def,
                'joint' => thruster_tag
            )



            ################ HighLevelController ######################
            define 'trajectory_move', ::AuvControl::TrajectoryMove.use(
#                AvalonControl::TrajectoryFollower.with_conf('default','hall_cool'),
                position_control_loop_def, 
                pose_tag,
                orientation_with_z_tag, 
            )
            
            define 'buoy_detector', Buoy::DetectorCmp.use(
                'camera' => forward_looking_camera_tag, 
                'orientation_with_z' => orientation_with_z_tag
            )


            ###     New Stuff now integrated #######################
            define 'simple_move_new', AuvCont::MoveCmp.use(
                'pose' => pose_blind_tag,
                #'controller' => AuvControl::ConstantCommand,
                #'controller' => ConstantWorldXYVelocityCommand,
                'joint' => thruster_tag
            )

            define 'target_move_new', AuvCont::PositionMoveCmp.use(
                'pose' => pose_tag,
                'command' => AuvControl::ConstantCommand, 
                'joint' => thruster_tag
            )
            
            define 'drive_simple_new', AuvCont::WorldXYVelocityCmp.use(
                'pose' => pose_blind_tag, #pose_estimator_def,
                'joint' => thruster_tag,
                'controller' => AuvControl::JoystickCommandCmp.use(
                        'orientation_with_z' => orientation_with_z_tag,
                        'dist' => altimeter_tag
                )
            )
           
            define 'structure_detector', Structure::Detector.use(
                'camera' => forward_looking_camera_tag,
                'ori' => orientation_with_z_tag
            )
            
            define 'structure_detector_down',Structure::Detector.use(
                'camera' => down_looking_camera_tag,
                'ori' => orientation_with_z_tag
            )
            
            define 'structure_align_detector',Structure::Alignment.use(
                'camera' => down_looking_camera_tag,
            )

            define 'structure_inspection', AuvCont::StructureCmp.use(
                'pose' => pose_tag,
                'joint' => thruster_tag,
                'controller' => structure_detector_def,
                'main' => structure_detector_def
            )

            define 'structure_alignment', AuvCont::StructureCmp.use(
                'pose' => pose_tag,
                'joint' => thruster_tag,
                'main' => structure_align_detector_def,
                'controller' => structure_align_detector_def
            )


            define 'structure_reconstruction', Structure::StructureReconstructionComp.use(
                'front_camera' => forward_looking_camera_tag,
                'bottom_camera' => down_looking_camera_tag
            ).use_frames(
                'body' => 'body',
                'world' => 'map_halle',
                'front_camera' => 'front_camera',
                'bottom_camera' => 'bottom_camera'
            )

#            define 'line_scanner', Pipeline::LineScanner.use(
#               LineScanner::Task.with_conf('default'),
#               'camera' => down_looking_camera_tag,
#               'motion_model' => pose_tag,
#               #'motion_model' => motion_model_tag
#            )

            define 'pipeline_detector', Pipeline::Detector.use(
                'camera' => down_looking_camera_tag,
#                'laser_scanner' => line_scanner_def,
                'orientation_with_z' => orientation_with_z_tag
            )

            define 'pipeline_detector_new', Pipeline::Detector_new.use(
                'camera' => down_looking_camera_tag,
 #               'laser_scanner' => line_scanner_def,
                'orientation_with_z' => orientation_with_z_tag
            )
            
            define 'pipeline', Pipeline::Follower.use(
                pipeline_detector_def,
                'controlled_system' =>  relative_loop_def
            )

            define 'pipeline_new', AuvCont::WorldXYPositionCmp.use(
                'pose' => pose_tag,
                'controller' => pipeline_detector_new_def,
                'joint' => thruster_tag
            )

            define 'wall_right_new', AuvCont::WorldXYPositionCmp.use(
                'pose' => pose_tag,
                'controller' => wall_detector_new_def.with_conf('wall_right'),
                'joint' => thruster_tag
            )

            define 'wall_left_new', AuvCont::WorldXYPositionCmp.use(
                'pose' => pose_tag,
                'controller' => wall_detector_new_def.with_conf('wall_left'),
                'joint' => thruster_tag
            )

            define 'wall_front_left_new', AuvCont::WorldXYPositionCmp.use(
                'pose' => pose_tag,
                'controller' => wall_detector_new_def.with_conf('wall_front_left'),
                'joint' => thruster_tag
            )

            define 'wall_front_right_new', AuvCont::WorldXYPositionCmp.use(
                'pose' => pose_tag,
                'controller' => wall_detector_new_def.with_conf('wall_front_right'),
                'joint' => thruster_tag
            )

            define 'trajectory', AuvCont::Trajectory.use(
                AvalonControl::TrajectoryFollower.with_conf('default','hall_cool'),
                'joint' => thruster_tag,
                'pose' => pose_tag
            )
            
            a = define 'blind_circle', AuvCont::Trajectory.use(
                AvalonControl::TrajectoryFollower.with_conf('default','circle'),
                'joint' => thruster_tag,
                'pose' => pose_blind_tag#.with_arguments(:reset => true)
            )


            define 'wall_buoy_detector', Buoy::DetectorNewCmp.use(
                'front_camera' => forward_looking_camera_tag,
            )

            define 'wall_buoy_controller', Buoy::ControllerNewCmp.use(
                'detector' => wall_buoy_detector_def,
                'pose' => pose_tag,
                'wall' => wall_detector_new_def.with_conf('wall_front_left'),
            )

            define 'wall_buoy_survey', AuvCont::WorldXYZPositionCmp.use(
                'pose' => pose_tag,
                'controller' => wall_buoy_controller_def,
                'joint' => thruster_tag
            )

            define 'wall_right_hold_pos', AuvCont::WorldXYPositionCmp.use(
                'pose' => pose_tag,
                'controller' => wall_detector_new_def.with_conf('hold_wall_right'),
                'joint' => thruster_tag
            )

        end
    end
end


