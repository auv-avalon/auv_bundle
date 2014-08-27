using_task_library "xsens_imu"
using_task_library "fog_kvh"
using_task_library "orientation_estimator"
#using_task_library "depth_reader"
using_task_library "uw_particle_localization"
using_task_library 'pose_estimation'
using_task_library 'wall_orientation_correction'


require "rock/models/blueprints/pose"
require "models/blueprints/auv.rb"

module PoseAuv

    class InitialOrientationEstimator < Syskit::Composition
        add_main WallOrientationCorrection::Task, :as => 'wall_estimation'
        add OrientationEstimator::IKF, :as => 'estimator'
        add XsensImu::Task, :as => 'imu'
        add FogKvh::Dsp3000Task, :as => 'fog'
        add Base::SonarScanProviderSrv, :as => 'sonar'
        add SonarFeatureEstimator::Task, :as => 'sonar_estimator'

        if ::CONFIG_HACK == 'avalon'
            estimator_child.with_conf("default", "local_initial_estimator", "imu_xsens", "fog_kvh_DSP_3000", "Bremen")
        elsif ::CONFIG_HACK == 'simulation'
            estimator_child.with_conf("default", "simulation", "imu_xsens", "fog_kvh_DSP_3000", "Bremen")
        elsif ::CONFIG_HACK == 'dagon'
            estimator_child.with_conf("default", "local_initial_estimator", "imu_xsens", "fog_kvh_DSP_3000", "Bremen")
        end

        wall_estimation_child.with_conf("default", "avalon", "wall_right")
        sonar_child.with_conf("default", "hold_wall_right")

        sonar_child.connect_to sonar_estimator_child
        imu_child.calibrated_sensors_port.connect_to estimator_child.imu_samples_port
        fog_child.connect_to estimator_child.fog_samples_port
        estimator_child.connect_to wall_estimation_child.orientation_samples_port
        sonar_estimator_child.connect_to wall_estimation_child

        #export wall_estimation.angle_in_world_port, :as => 'angle_samples'
        #provides Base::OrientationSrv, :as => "angle_in_world"

        event :MISSING_TRANSFORMATION
        event :ESTIMATE_WALL_ORIENTATION
        event :VALID_WALL_FIX
    end

    class IKFOrientationEstimator < Syskit::Composition
        add_main OrientationEstimator::IKF, :as => 'estimator'
        add WallOrientationCorrection::OrientationInMap, :as => 'ori_in_map'
        add XsensImu::Task, :as => 'imu'
        add FogKvh::Dsp3000Task, :as => 'fog'

        if ::CONFIG_HACK == 'avalon'
            estimator_child.with_conf("default", "avalon", "imu_xsens", "fog_kvh_DSP_3000", "Bremen")
        elsif ::CONFIG_HACK == 'simulation'
            estimator_child.with_conf("default", "simulation", "imu_xsens", "fog_kvh_DSP_3000", "Bremen")
        elsif ::CONFIG_HACK == 'dagon'
            estimator_child.with_conf("default", "avalon", "imu_xsens", "fog_kvh_DSP_3000", "Bremen")
        end

        imu_child.calibrated_sensors_port.connect_to estimator_child.imu_samples_port
        fog_child.connect_to estimator_child.fog_samples_port
        estimator_child.connect_to ori_in_map_child.orientation_in_world_port

        export ori_in_map_child.orientation_in_map_port, :as => 'orientation_samples'
        provides Base::OrientationSrv, :as => "orientation"

        event :INITIAL_NORTH_SEEKING
        event :INITIAL_ALIGNMENT
        event :MISSING_TRANSFORMATION
        event :NAN_ERROR
        event :ALIGNMENT_ERROR
        event :CONFIGURATION_ERROR
    end

    class PoseEstimator < Syskit::Composition
        add_main PoseEstimation::UWPoseEstimator, :as => 'pose_estimator'
        add Base::OrientationSrv, :as => 'ori'#.prefer_deployed_task("ikf_orientation_estimator"), :as => 'ori'
        add Base::VelocitySrv, :as => 'model'
        add Base::ZProviderSrv, :as => 'depth'
        add_optional Base::PoseSrv, :as => 'localization'
        add_optional Base::DVLSrv, as: 'dvl'
        ori_child.prefer_deployed_tasks("ikf_orientation_estimator")

        if ::CONFIG_HACK == 'avalon'
            pose_estimator_child.with_conf("default", "avalon", "sauce")
        elsif ::CONFIG_HACK == 'simulation'
            pose_estimator_child.with_conf("default")
        elsif ::CONFIG_HACK == 'dagon'
            pose_estimator_child.with_conf("default", "dagon", "sauce")
        end

        connect ori_child => pose_estimator_child.orientation_samples_port
        connect model_child => pose_estimator_child.model_velocity_samples_port
        connect localization_child.pose_samples_port => pose_estimator_child.xy_position_samples_port
        connect depth_child => pose_estimator_child.depth_samples_port
        connect dvl_child => pose_estimator_child.dvl_velocity_samples_port

        export pose_estimator_child.pose_samples_port
        provides Base::PoseSrv, :as => 'pose'

        event :MISSING_TRANSFORMATION
    end

    class DagonOrientationEstimator < Syskit::Composition
        add OrientationEstimator::BaseEstimator, :as => 'estimator'
        add UwParticleLocalization::OrientationCorrection, :as => 'correction'

        add Base::OrientationSrv, :as => 'imu'
        add FogKvh::Dsp3000Task, :as => 'fog'

        #imu_child.connect_to correction_child.absolute_orientation_port
        estimator_child.connect_to correction_child.orientation_input_port

        imu_child.connect_to  estimator_child.imu_orientation_port
        fog_child.connect_to  estimator_child.fog_samples_port

        #export estimator_child.attitude_b_g_port, :as => 'orientation_samples'
        export correction_child.orientation_output_port, :as => 'orientation_samples'
        #export correction_child.orientation_offset_corrected_port, :as => 'orientation_samples'
        provides Base::OrientationSrv, :as => "orientation"
    end

#    class OrientationWithZ < Syskit::Composition 
#        add DepthReader::DepthAndOrientationFusion, :as => 'fusion'
#        
#        #add Srv::Orientation
#        add DagonOrientationEstimator, :as => 'orientation'
#        add Base::ZProviderSrv, :as => 'z_provider'
#
#        orientation_child.connect_to fusion_child.orientation_samples_port
#        z_provider_child.connect_to  fusion_child.depth_samples_port
#
#        export fusion_child.pose_samples_port
#        provides Base::OrientationWithZSrv, :as => "orientation_with_z"
#        provides Base::VelocitySrv, :as => "speed"
#    end
end
