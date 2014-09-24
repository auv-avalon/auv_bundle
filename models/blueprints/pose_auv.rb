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


    class IKFOrientationEstimatorCmp < Syskit::Composition
        #add_main OrientationEstimator::IKF.prefer_deployed_tasks(/ikf_orientation_estimator/), :as => 'estimator'
        add_main OrientationEstimator::BaseEstimator.prefer_deployed_tasks("orientation_estimator"), :as => 'estimator'
        add WallOrientationCorrection::OrientationInMap, :as => 'ori_in_map'
        add XsensImu::Task, :as => 'imu'
        add FogKvh::Dsp3000Task, :as => 'fog'

        if ::CONFIG_HACK == 'default'
            ori_in_map_child.with_conf("default", 'sauce')
            #estimator_child.with_conf("default", "avalon", "imu_xsens", "fog_kvh_DSP_3000", "sauce14")
            estimator_child.with_conf("default", "avalon", "sauce", "sauce14")
        elsif ::CONFIG_HACK == 'simulation'
            ori_in_map_child.with_conf("default", 'sauce')
            #estimator_child.with_conf("default", "simulation", "imu_xsens", "fog_kvh_DSP_3000", "sauce14")
            estimator_child.with_conf("default", "sauce", "sauce14")
        elsif ::CONFIG_HACK == 'dagon'
            ori_in_map_child.with_conf("default", 'sauce')
            #estimator_child.with_conf("default", "dagon", "imu_xsens", "fog_kvh_DSP_3000", "sauce14")
            estimator_child.with_conf("default", "dagon", "sauce", "sauce14")
        end

        #imu_child.calibrated_sensors_port.connect_to estimator_child.imu_samples_port
        imu_child.connect_to estimator_child.imu_orientation_port
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
    
    class InitialOrientationEstimatorCmp < Syskit::Composition
        event :MISSING_TRANSFORMATION
        event :ESTIMATE_WALL_ORIENTATION
        event :VALID_WALL_FIX

        add_main WallOrientationCorrection::Task, :as => 'wall_estimation'
        add OrientationEstimator::BaseEstimator.prefer_deployed_tasks("initial_orientation_estimator"), :as => 'estimator'
        add XsensImu::Task, :as => 'imu'
        add FogKvh::Dsp3000Task, :as => 'fog'
        add Base::SonarScanProviderSrv, :as => 'sonar'
        add SonarFeatureEstimator::Task, :as => 'sonar_estimator'

        estimator_child.with_conf("default", "local_initial_estimator", "Bremen")
        wall_estimation_child.with_conf("default", "wall_right")
#        sonar_child.with_conf("default", "wall_right") ##TODO Urgend

        sonar_child.connect_to sonar_estimator_child
        imu_child.connect_to estimator_child.imu_orientation_port
        fog_child.connect_to estimator_child.fog_samples_port
        estimator_child.connect_to wall_estimation_child.orientation_samples_port
        sonar_estimator_child.connect_to wall_estimation_child

        add IKFOrientationEstimatorCmp, :as => "slave"

        on :start do |ev|
            @reader = wall_estimation_child.angle_in_world_port.reader
        end

        on :VALID_WALL_FIX do |e|
            @reader
            sample = @reader.readNewest
            slave_child.estimator_child.reset_heading sample.rad 
            emit :success
            e
        end
    end

    class PoseEstimatorCmp < Syskit::Composition
        argument :reset, :default => false

        add_main PoseEstimation::UWPoseEstimator, :as => 'pose_estimator'
        add Base::OrientationSrv, :as => 'ori'
        add Base::VelocitySrv, :as => 'model'
        add Base::ZProviderSrv, :as => 'depth'
        add_optional Base::PoseSrv, :as => 'localization'
        add_optional Base::DVLSrv, as: 'dvl'
        #ori_child.prefer_deployed_tasks("ikf_orientation_estimator")

        if ::CONFIG_HACK == 'default'
            pose_estimator_child.with_conf("default", "avalon", "sauce")
        elsif ::CONFIG_HACK == 'simulation'
            pose_estimator_child.with_conf("default", 'avalon', 'sauce')
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
        on :start do |e|
            if self.reset
                pose_estimator_child.orocos_task.resetState
            end
        end

        event :MISSING_TRANSFORMATION
    end

#    class DagonOrientationEstimatorCmp < Syskit::Composition
#        add OrientationEstimator::BaseEstimator.prefer_deployed_tasks("orientation_estimator"), :as => 'estimator'
#        add UwParticleLocalization::OrientationCorrection, :as => 'correction'
#
#        add Base::OrientationSrv, :as => 'imu'
#        add FogKvh::Dsp3000Task, :as => 'fog'
#
#        #imu_child.connect_to correction_child.absolute_orientation_port
#        estimator_child.connect_to correction_child.orientation_input_port
#
#        imu_child.connect_to  estimator_child.imu_orientation_port
#        fog_child.connect_to  estimator_child.fog_samples_port
#
#        #export estimator_child.attitude_b_g_port, :as => 'orientation_samples'
#        export correction_child.orientation_output_port, :as => 'orientation_samples'
#        #export correction_child.orientation_offset_corrected_port, :as => 'orientation_samples'
#        provides Base::OrientationSrv, :as => "orientation"
#    end

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
